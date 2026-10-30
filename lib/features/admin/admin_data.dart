import 'package:supabase_flutter/supabase_flutter.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

DateTime? parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

String shortDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

String weekdayName(DateTime date) => _weekdays[date.weekday - 1];

String longDate(DateTime date) =>
    '${_weekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]}';

/// "Today", "Yesterday", "3 days ago" ... for admin lists.
String ageLabel(DateTime? date, DateTime now) {
  if (date == null) return 'Unknown date';

  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final days = today.difference(day).inDays;

  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days < 30) return '$days days ago';

  return shortDate(date);
}

/// One fetch of everything the admin screens need, plus the numbers derived
/// from it. All calculations are plain Dart so they are easy to test.
class AdminSnapshot {
  final List<Map<String, dynamic>> profiles;
  final List<Map<String, dynamic>> stalls;
  final List<Map<String, dynamic>> favorites;
  final Map<String, String> categoryNames;
  final DateTime loadedAt;

  AdminSnapshot({
    required this.profiles,
    required this.stalls,
    required this.favorites,
    required this.categoryNames,
    DateTime? loadedAt,
  }) : loadedAt = loadedAt ?? DateTime.now();

  // ---------- users ----------

  int get customers => profiles.where((p) => p['role'] == 'customer').length;

  int get vendors => profiles.where((p) => p['role'] == 'vendor').length;

  int get admins => profiles.where((p) => p['role'] == 'admin').length;

  int get suspendedAccounts =>
      profiles.where((p) => p['is_active'] != true).length;

  Map<String, dynamic>? profileById(String? id) {
    if (id == null) return null;

    for (final profile in profiles) {
      if (profile['id'] == id) return profile;
    }

    return null;
  }

  int get vendorsWithoutStall {
    final withStall = stalls.map((s) => s['vendor_id']).toSet();

    return profiles
        .where((p) => p['role'] == 'vendor' && !withStall.contains(p['id']))
        .length;
  }

  // ---------- stalls ----------

  String statusOf(Map<String, dynamic> stall) =>
      stall['approval_status'] as String? ?? 'pending';

  int statusCount(String status) =>
      stalls.where((s) => statusOf(s) == status).length;

  int get approved => statusCount('approved');

  int get pending => statusCount('pending');

  int get rejected => statusCount('rejected');

  int get suspended => statusCount('suspended');

  int get openNow => stalls
      .where((s) => statusOf(s) == 'approved' && s['is_open'] == true)
      .length;

  int get closedNow => approved - openNow;

  List<Map<String, dynamic>> stallsWithStatus(String status) {
    final list = stalls.where((s) => statusOf(s) == status).toList();

    list.sort((a, b) {
      final first = parseDate(a['created_at']);
      final second = parseDate(b['created_at']);

      if (first == null || second == null) return 0;

      return first.compareTo(second);
    });

    return list;
  }

  List<Map<String, dynamic>> recentStalls({int limit = 5}) {
    final list = [...stalls];

    list.sort((a, b) {
      final first = parseDate(a['created_at']);
      final second = parseDate(b['created_at']);

      if (first == null && second == null) return 0;
      if (first == null) return 1;
      if (second == null) return -1;

      return second.compareTo(first);
    });

    return list.take(limit).toList();
  }

  String categoryOf(Map<String, dynamic> stall) =>
      categoryNames[stall['category_id']] ?? 'Uncategorised';

  /// Stalls per category, biggest first.
  List<MapEntry<String, int>> get stallsByCategory {
    final counts = <String, int>{};

    for (final stall in stalls) {
      final name = categoryOf(stall);
      counts[name] = (counts[name] ?? 0) + 1;
    }

    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries;
  }

  /// Stalls created on each of the last [days] days, oldest first.
  List<MapEntry<DateTime, int>> stallsCreatedPerDay({
    int days = 7,
    DateTime? now,
  }) {
    final today = now ?? loadedAt;
    final start = DateTime(today.year, today.month, today.day);

    return List.generate(days, (index) {
      final day = start.subtract(Duration(days: days - 1 - index));

      final count = stalls.where((stall) {
        final created = parseDate(stall['created_at']);

        return created != null &&
            created.year == day.year &&
            created.month == day.month &&
            created.day == day.day;
      }).length;

      return MapEntry(day, count);
    });
  }

  // ---------- categories ----------

  /// All categories as (id, name), alphabetical.
  List<MapEntry<String, String>> get categories {
    final list = categoryNames.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));

    return list;
  }

  int stallCountForCategory(String categoryId) =>
      stalls.where((s) => s['category_id'] == categoryId).length;

  // ---------- favorites ----------

  int favoritesForStall(String? stallId) =>
      favorites.where((f) => f['stall_id'] == stallId).length;

  int favoritesForUser(String? userId) =>
      favorites.where((f) => f['user_id'] == userId).length;

  /// Stalls with the most favorites, as (stall name, count).
  List<MapEntry<String, int>> topFavorited({int limit = 5}) {
    final counts = <String, int>{};

    for (final favorite in favorites) {
      final id = favorite['stall_id'] as String?;
      if (id != null) counts[id] = (counts[id] ?? 0) + 1;
    }

    final result = <MapEntry<String, int>>[];

    counts.forEach((id, count) {
      final stall = stalls.where((s) => s['id'] == id).firstOrNull;
      if (stall != null) {
        result.add(MapEntry(stall['name'] as String? ?? 'Stall', count));
      }
    });

    result.sort((a, b) => b.value.compareTo(a.value));

    return result.take(limit).toList();
  }

  /// Plain-text summary used by the "Copy report" button.
  String summaryReport({DateTime? now}) {
    final time = now ?? loadedAt;
    final buffer = StringBuffer()
      ..writeln('VendrGo admin summary - ${shortDate(time)}')
      ..writeln('')
      ..writeln('Users')
      ..writeln('  Customers: $customers')
      ..writeln('  Vendors: $vendors')
      ..writeln('  Admins: $admins')
      ..writeln('  Suspended accounts: $suspendedAccounts')
      ..writeln('')
      ..writeln('Stalls (${stalls.length} total)')
      ..writeln('  Approved: $approved ($openNow open now)')
      ..writeln('  Pending approval: $pending')
      ..writeln('  Rejected: $rejected')
      ..writeln('  Suspended: $suspended');

    final categories = stallsByCategory;

    if (categories.isNotEmpty) {
      buffer
        ..writeln('')
        ..writeln('By category');

      for (final entry in categories) {
        buffer.writeln('  ${entry.key}: ${entry.value}');
      }
    }

    return buffer.toString().trimRight();
  }
}

/// Returns an error message for an invalid category name, or null if it is
/// fine. [existing] are the names already in use; [ignore] is the category
/// being renamed so it can keep its own name.
String? validateCategoryName(
  String? raw,
  Iterable<String> existing, {
  String? ignore,
}) {
  final name = (raw ?? '').trim();

  if (name.length < 2) return 'Enter at least 2 characters.';
  if (name.length > 30) return 'Keep it under 30 characters.';

  final lower = name.toLowerCase();
  final ignored = ignore?.trim().toLowerCase();

  for (final other in existing) {
    final otherLower = other.trim().toLowerCase();

    if (otherLower == lower && otherLower != ignored) {
      return 'A category with this name already exists.';
    }
  }

  return null;
}

/// Loads the admin snapshot and performs admin write actions.
class AdminRepository {
  final SupabaseClient client;

  AdminRepository([SupabaseClient? client])
    : client = client ?? Supabase.instance.client;

  Future<List<Map<String, dynamic>>> _rows(Future<dynamic> request) async {
    final data = await request;
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<AdminSnapshot> load() async {
    final profiles = _rows(client.from('profiles').select());
    final stalls = _rows(client.from('stalls').select());
    final categories = _rows(client.from('categories').select('id, name'));

    // Favorites are a nice-to-have; a permissions error must not break the
    // whole dashboard.
    final favorites = _rows(
      client.from('favorites').select('user_id, stall_id'),
    ).catchError((_) => <Map<String, dynamic>>[]);

    final results = await Future.wait([
      profiles,
      stalls,
      categories,
      favorites,
    ]);

    return AdminSnapshot(
      profiles: results[0],
      stalls: results[1],
      categoryNames: {
        for (final row in results[2])
          if (row['id'] != null && row['name'] != null)
            row['id'] as String: row['name'] as String,
      },
      favorites: results[3],
    );
  }

  /// Suspending a vendor also takes their stall offline.
  Future<void> setAccountActive({
    required String userId,
    required String role,
    required bool active,
  }) async {
    await client
        .from('profiles')
        .update({'is_active': active})
        .eq('id', userId);

    if (!active && role == 'vendor') {
      await client
          .from('stalls')
          .update({'approval_status': 'suspended', 'is_open': false})
          .eq('vendor_id', userId);
    }
  }

  /// Live count from the database (not the cached snapshot), used right
  /// before deleting a category.
  Future<int> stallCountForCategory(String categoryId) async {
    final rows = await _rows(
      client.from('stalls').select('id').eq('category_id', categoryId),
    );

    return rows.length;
  }

  Future<void> addCategory(String name) async {
    await client.from('categories').insert({
      'name': name.trim(),
      'created_by': client.auth.currentUser?.id,
      'is_active': true,
    });
  }

  Future<void> renameCategory(String id, String name) async {
    await client.from('categories').update({'name': name.trim()}).eq('id', id);
  }

  Future<void> deleteCategory(String id) async {
    await client.from('categories').delete().eq('id', id);
  }

  Future<void> deleteStall(String id) async {
    await client.from('stalls').delete().eq('id', id);
  }
}
