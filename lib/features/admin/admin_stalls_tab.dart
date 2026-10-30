import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/media_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/feedback_widgets.dart';
import '../../shared/widgets/network_image_with_fallback.dart';
import '../../shared/widgets/status_badge.dart';
import 'admin_data.dart';
import 'admin_detail_screens.dart';
import 'admin_widgets.dart';

String? _mediaUrl(dynamic path) => MediaService.urlFor(path);

String _hoursOf(Map<String, dynamic> stall) {
  final hours = stall['opening_hours'];

  if (hours is Map) return hours['all'] as String? ?? '';

  return '';
}

/// Bottom sheet with everything an admin wants to know about one stall.
Future<void> showAdminStallSheet(
  BuildContext context, {
  required AdminSnapshot snapshot,
  required Map<String, dynamic> stall,
  required AdminRepository repository,
  required Future<void> Function() onChanged,
}) {
  final status = snapshot.statusOf(stall);
  final vendor = snapshot.profileById(stall['vendor_id']);
  final created = parseDate(stall['created_at']);
  final isOpen = stall['is_open'] == true;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NetworkImageWithFallback(
                url: _mediaUrl(stall['stall_image_path']),
                height: 160,
                width: double.infinity,
                borderRadius: VendrgoRadius.lgAll,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      stall['name'] as String? ?? 'Unnamed stall',
                      style: VendrgoText.title,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge.approval(status: status),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  StatusBadge.openClosed(isOpen: isOpen),
                  const SizedBox(width: 8),
                  Text(
                    '${snapshot.favoritesForStall(stall['id'] as String?)} favorites',
                    style: VendrgoText.caption,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),
              InfoRow(
                icon: Icons.person_outline_rounded,
                label: 'Vendor',
                value:
                    '${vendor?['full_name'] ?? 'Unknown'}'
                    '${vendor?['email'] != null ? '\n${vendor!['email']}' : ''}',
              ),
              InfoRow(
                icon: Icons.restaurant_menu_rounded,
                label: 'Category',
                value: snapshot.categoryOf(stall),
              ),
              InfoRow(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: stall['address'] as String? ?? '',
              ),
              InfoRow(
                icon: Icons.schedule_rounded,
                label: 'Opening hours',
                value: _hoursOf(stall),
              ),
              InfoRow(
                icon: Icons.event_outlined,
                label: 'Registered',
                value: created == null ? '' : shortDate(created),
              ),
              if (status == 'rejected' &&
                  (stall['rejection_reason'] as String?)?.isNotEmpty == true)
                InfoRow(
                  icon: Icons.info_outline_rounded,
                  label: 'Rejection reason',
                  value: stall['rejection_reason'] as String,
                ),
              const SizedBox(height: 12),
              if (status != 'approved')
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();

                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AdminVendorReviewScreen(
                            stall: stall,
                            vendor: vendor ?? <String, dynamic>{},
                          ),
                        ),
                      );

                      await onChanged();
                    },
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Review stall'),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(sheetContext).pop();

                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AdminStallEditScreen(stall: stall),
                    ),
                  );

                  await onChanged();
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit stall'),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: VendrgoColors.error,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () async {
                  final confirmed = await showConfirmationDialog(
                    sheetContext,
                    title: 'Delete stall?',
                    message: 'This cannot be undone.',
                    confirmLabel: 'Delete',
                    destructive: true,
                  );

                  if (!confirmed) return;

                  try {
                    await repository.deleteStall(stall['id'] as String);

                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();

                    if (context.mounted) {
                      showAppSnackBar(context, 'Stall deleted.');
                    }

                    await onChanged();
                  } catch (error) {
                    if (context.mounted) {
                      showAppSnackBar(
                        context,
                        'Could not delete the stall.',
                        isError: true,
                      );
                    }
                  }
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete stall'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class AdminStallsTab extends StatefulWidget {
  final AdminSnapshot snapshot;
  final AdminRepository repository;
  final Future<void> Function() onRefresh;

  const AdminStallsTab({
    super.key,
    required this.snapshot,
    required this.repository,
    required this.onRefresh,
  });

  @override
  State<AdminStallsTab> createState() => _AdminStallsTabState();
}

class _AdminStallsTabState extends State<AdminStallsTab> {
  final searchController = TextEditingController();

  String statusFilter = 'all';
  bool openOnly = false;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    final snapshot = widget.snapshot;
    final query = searchController.text.trim().toLowerCase();

    final list = snapshot.stalls.where((stall) {
      if (statusFilter != 'all' && snapshot.statusOf(stall) != statusFilter) {
        return false;
      }

      if (openOnly && stall['is_open'] != true) return false;

      if (query.isEmpty) return true;

      final vendor = snapshot.profileById(stall['vendor_id']);
      final haystack = [
        stall['name'],
        stall['address'],
        snapshot.categoryOf(stall),
        vendor?['full_name'],
      ].map((value) => (value ?? '').toString().toLowerCase()).join(' ');

      return haystack.contains(query);
    }).toList();

    list.sort((a, b) {
      final first = parseDate(a['created_at']);
      final second = parseDate(b['created_at']);

      if (first == null || second == null) return 0;

      return second.compareTo(first);
    });

    return list;
  }

  Widget _chip(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: statusFilter == value,
        onSelected: (_) => setState(() => statusFilter = value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final stalls = _filtered;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Stalls', style: VendrgoText.title),
              const SizedBox(height: 12),
              TextField(
                controller: searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search name, vendor, address...',
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
                    _chip('all', 'All (${snapshot.stalls.length})'),
                    _chip('approved', 'Approved (${snapshot.approved})'),
                    _chip('pending', 'Pending (${snapshot.pending})'),
                    _chip('rejected', 'Rejected (${snapshot.rejected})'),
                    _chip('suspended', 'Suspended (${snapshot.suspended})'),
                    FilterChip(
                      label: const Text('Open now'),
                      selected: openOnly,
                      onSelected: (value) => setState(() => openOnly = value),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: stalls.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 60),
                      EmptyState(
                        icon: Icons.storefront_outlined,
                        title: 'No stalls match',
                        message: 'Try a different search or filter.',
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: stalls.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final stall = stalls[index];
                      final vendor = snapshot.profileById(stall['vendor_id']);

                      return AdminListCard(
                        title: stall['name'] as String? ?? 'Unnamed stall',
                        subtitle:
                            '${vendor?['full_name'] ?? 'Unknown vendor'}'
                            ' · ${snapshot.categoryOf(stall)}',
                        leading: NetworkImageWithFallback(
                          url: _mediaUrl(stall['stall_image_path']),
                          height: 56,
                          width: 56,
                          borderRadius: VendrgoRadius.mdAll,
                        ),
                        badge: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            StatusBadge.approval(
                              status: snapshot.statusOf(stall),
                            ),
                            StatusBadge.openClosed(
                              isOpen: stall['is_open'] == true,
                            ),
                          ],
                        ),
                        onTap: () => showAdminStallSheet(
                          context,
                          snapshot: snapshot,
                          stall: stall,
                          repository: widget.repository,
                          onChanged: widget.onRefresh,
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
