import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../services/media_service.dart';
import '../../shared/widgets/feedback_widgets.dart';
import '../../shared/widgets/network_image_with_fallback.dart';
import '../../shared/widgets/status_badge.dart';
import 'admin_data.dart';
import 'admin_detail_screens.dart';
import 'admin_widgets.dart';

/// Opens the review screen for a stall and refreshes the data afterwards.
Future<void> openAdminReview(
  BuildContext context, {
  required AdminSnapshot snapshot,
  required Map<String, dynamic> stall,
  required Future<void> Function() onChanged,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => AdminVendorReviewScreen(
        stall: stall,
        vendor: snapshot.profileById(stall['vendor_id']) ?? <String, dynamic>{},
      ),
    ),
  );

  await onChanged();
}

String? _imageUrl(Map<String, dynamic> stall) =>
    MediaService.urlFor(stall['stall_image_path']);

/// Review queue: stalls that still need an admin decision.
class AdminApprovalsTab extends StatefulWidget {
  final AdminSnapshot snapshot;
  final Future<void> Function() onRefresh;

  const AdminApprovalsTab({
    super.key,
    required this.snapshot,
    required this.onRefresh,
  });

  @override
  State<AdminApprovalsTab> createState() => _AdminApprovalsTabState();
}

class _AdminApprovalsTabState extends State<AdminApprovalsTab> {
  String status = 'pending';

  Widget _chip(String value, String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text('$label ($count)'),
        selected: status == value,
        onSelected: (_) => setState(() => status = value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final stalls = snapshot.stallsWithStatus(status);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Approvals', style: VendrgoText.title),
              const SizedBox(height: 4),
              const Text(
                'Review vendor stalls before customers can see them.',
                style: VendrgoText.bodySecondary,
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip('pending', 'Pending', snapshot.pending),
                    _chip('rejected', 'Rejected', snapshot.rejected),
                    _chip('suspended', 'Suspended', snapshot.suspended),
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
                    children: [
                      const SizedBox(height: 60),
                      EmptyState(
                        icon: Icons.task_alt_rounded,
                        title: status == 'pending'
                            ? 'All caught up'
                            : 'Nothing here',
                        message: status == 'pending'
                            ? 'No vendors are waiting for approval.'
                            : 'No $status stalls.',
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
                      final submitted = ageLabel(
                        parseDate(stall['created_at']),
                        DateTime.now(),
                      );

                      return AdminListCard(
                        title: stall['name'] as String? ?? 'Unnamed stall',
                        subtitle:
                            '${vendor?['full_name'] ?? 'Vendor'}\n'
                            '${vendor?['email'] ?? ''}\n'
                            'Submitted $submitted',
                        leading: NetworkImageWithFallback(
                          url: _imageUrl(stall),
                          height: 56,
                          width: 56,
                          borderRadius: VendrgoRadius.mdAll,
                        ),
                        badge: StatusBadge.approval(status: status),
                        onTap: () => openAdminReview(
                          context,
                          snapshot: snapshot,
                          stall: stall,
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
