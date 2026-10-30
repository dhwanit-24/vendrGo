import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/feedback_widgets.dart';
import '../../shared/widgets/status_badge.dart';
import 'admin_data.dart';
import 'admin_widgets.dart';

class AdminUsersTab extends StatefulWidget {
  final AdminSnapshot snapshot;
  final AdminRepository repository;
  final Future<void> Function() onRefresh;

  const AdminUsersTab({
    super.key,
    required this.snapshot,
    required this.repository,
    required this.onRefresh,
  });

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final searchController = TextEditingController();

  String roleFilter = 'all';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    final query = searchController.text.trim().toLowerCase();

    final list = widget.snapshot.profiles.where((profile) {
      if (roleFilter != 'all' && profile['role'] != roleFilter) return false;

      if (query.isEmpty) return true;

      final haystack = [
        profile['full_name'],
        profile['email'],
        profile['phone'],
      ].map((value) => (value ?? '').toString().toLowerCase()).join(' ');

      return haystack.contains(query);
    }).toList();

    list.sort(
      (a, b) => (a['full_name'] ?? '').toString().toLowerCase().compareTo(
        (b['full_name'] ?? '').toString().toLowerCase(),
      ),
    );

    return list;
  }

  Widget _chip(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: roleFilter == value,
        onSelected: (_) => setState(() => roleFilter = value),
      ),
    );
  }

  Future<void> _openUser(Map<String, dynamic> profile) async {
    final snapshot = widget.snapshot;
    final role = profile['role'] as String? ?? 'customer';
    final active = profile['is_active'] == true;
    final userId = profile['id'] as String;
    final isSelf = Supabase.instance.client.auth.currentUser?.id == userId;
    final vendorStalls = snapshot.stalls
        .where((s) => s['vendor_id'] == userId)
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Avatar(name: profile['full_name'] as String?, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile['full_name'] as String? ?? 'Unnamed user',
                            style: VendrgoText.title,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _roleBadge(role),
                              if (!active)
                                const StatusBadge(
                                  label: 'Suspended',
                                  tone: BadgeTone.error,
                                  icon: Icons.block_rounded,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(),
                InfoRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: profile['email'] as String? ?? '',
                ),
                InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: profile['phone'] as String? ?? '',
                ),
                if (role == 'vendor')
                  InfoRow(
                    icon: Icons.storefront_outlined,
                    label: 'Stall',
                    value: vendorStalls.isEmpty
                        ? 'No stall registered yet'
                        : vendorStalls
                              .map(
                                (s) =>
                                    '${s['name'] ?? 'Unnamed'} '
                                    '(${snapshot.statusOf(s)})',
                              )
                              .join('\n'),
                  ),
                if (role == 'customer')
                  InfoRow(
                    icon: Icons.favorite_border_rounded,
                    label: 'Saved stalls',
                    value: '${snapshot.favoritesForUser(userId)}',
                  ),
                const SizedBox(height: 12),
                if (role == 'admin' || isSelf)
                  Text(
                    isSelf
                        ? 'This is your own account.'
                        : 'Admin accounts cannot be suspended here.',
                    style: VendrgoText.caption,
                  )
                else if (active)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: VendrgoColors.error,
                    ),
                    onPressed: () async {
                      final confirmed = await showConfirmationDialog(
                        sheetContext,
                        title: 'Suspend account?',
                        message: role == 'vendor'
                            ? 'The vendor will be unable to log in and their '
                                  'stall will be hidden from customers.'
                            : 'This user will be unable to log in.',
                        confirmLabel: 'Suspend',
                        destructive: true,
                      );

                      if (!confirmed || !sheetContext.mounted) return;

                      await _changeActive(sheetContext, profile, false);
                    },
                    icon: const Icon(Icons.block_rounded),
                    label: const Text('Suspend account'),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () => _changeActive(sheetContext, profile, true),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Reactivate account'),
                  ),
                if (!active && role == 'vendor')
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Their stall stays suspended until you re-approve it '
                      'from the Stalls tab.',
                      style: VendrgoText.caption,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _changeActive(
    BuildContext sheetContext,
    Map<String, dynamic> profile,
    bool active,
  ) async {
    try {
      await widget.repository.setAccountActive(
        userId: profile['id'] as String,
        role: profile['role'] as String? ?? 'customer',
        active: active,
      );

      if (sheetContext.mounted) Navigator.of(sheetContext).pop();

      if (mounted) {
        showAppSnackBar(
          context,
          active ? 'Account reactivated.' : 'Account suspended.',
        );
      }

      await widget.onRefresh();
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Could not update the account.',
          isError: true,
        );
      }
    }
  }

  static StatusBadge _roleBadge(String role) {
    switch (role) {
      case 'vendor':
        return const StatusBadge(
          label: 'Vendor',
          tone: BadgeTone.warning,
          icon: Icons.storefront_rounded,
        );
      case 'admin':
        return const StatusBadge(
          label: 'Admin',
          tone: BadgeTone.error,
          icon: Icons.shield_outlined,
        );
      default:
        return const StatusBadge(
          label: 'Customer',
          tone: BadgeTone.success,
          icon: Icons.person_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final users = _filtered;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Users', style: VendrgoText.title),
              const SizedBox(height: 12),
              TextField(
                controller: searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search name, email, phone...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip('all', 'All (${snapshot.profiles.length})'),
                    _chip('customer', 'Customers (${snapshot.customers})'),
                    _chip('vendor', 'Vendors (${snapshot.vendors})'),
                    _chip('admin', 'Admins (${snapshot.admins})'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: users.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 60),
                      EmptyState(
                        icon: Icons.people_outline_rounded,
                        title: 'No users match',
                        message: 'Try a different search or filter.',
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: users.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final profile = users[index];
                      final active = profile['is_active'] == true;

                      return AdminListCard(
                        title:
                            profile['full_name'] as String? ?? 'Unnamed user',
                        subtitle: profile['email'] as String? ?? '',
                        leading: _Avatar(name: profile['full_name'] as String?),
                        badge: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _roleBadge(
                              profile['role'] as String? ?? 'customer',
                            ),
                            if (!active)
                              const StatusBadge(
                                label: 'Suspended',
                                tone: BadgeTone.error,
                              ),
                          ],
                        ),
                        onTap: () => _openUser(profile),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? name;
  final double size;

  const _Avatar({required this.name, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final initial = (name == null || name!.trim().isEmpty)
        ? '?'
        : name!.trim()[0].toUpperCase();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: VendrgoColors.peach,
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
          color: VendrgoColors.primaryDark,
        ),
      ),
    );
  }
}
