import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../services/auth_services.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/feedback_widgets.dart';
import '../../shared/widgets/status_badge.dart';
import 'admin_approvals_tab.dart';
import 'admin_categories_screen.dart';
import 'admin_data.dart';
import 'admin_stalls_tab.dart';
import 'admin_widgets.dart';

class AdminDashboardTab extends StatelessWidget {
  final AdminSnapshot snapshot;
  final AdminRepository repository;
  final Future<void> Function() onRefresh;
  final ValueChanged<int> onGoToTab;

  const AdminDashboardTab({
    super.key,
    required this.snapshot,
    required this.repository,
    required this.onRefresh,
    required this.onGoToTab,
  });

  static const _approvalsTab = 1;
  static const _usersTab = 2;
  static const _stallsTab = 3;

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Log out?',
      message: 'You will need to sign in again.',
      confirmLabel: 'Log out',
      destructive: true,
    );

    if (confirmed) {
      await AuthService.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = snapshot.stallsCreatedPerDay(now: now);
    final categories = snapshot.stallsByCategory.take(6).toList();
    final favorites = snapshot.topFavorited();
    final pendingStalls = snapshot.stallsWithStatus('pending');
    final openShare = snapshot.approved == 0
        ? '0% of approved'
        : '${(snapshot.openNow * 100 / snapshot.approved).round()}% of approved';

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Admin dashboard', style: VendrgoText.title),
                    Text(longDate(now), style: VendrgoText.caption),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Log out',
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (snapshot.pending > 0) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: VendrgoColors.warningSoft,
                borderRadius: VendrgoRadius.lgAll,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.pending_actions_rounded,
                    color: VendrgoColors.warning,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${snapshot.pending} '
                      '${snapshot.pending == 1 ? 'stall is' : 'stalls are'} '
                      'waiting for approval',
                      style: VendrgoText.label,
                    ),
                  ),
                  TextButton(
                    onPressed: () => onGoToTab(_approvalsTab),
                    child: const Text('Review'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          const SectionHeader(title: 'Overview'),
          const SizedBox(height: 8),
          KpiGrid(
            children: [
              KpiCard(
                label: 'Customers',
                value: '${snapshot.customers}',
                icon: Icons.people_alt_outlined,
                tint: VendrgoColors.lavender,
                onTap: () => onGoToTab(_usersTab),
              ),
              KpiCard(
                label: 'Vendors',
                value: '${snapshot.vendors}',
                icon: Icons.storefront_outlined,
                tint: VendrgoColors.peach,
                footnote: snapshot.vendorsWithoutStall == 0
                    ? null
                    : '${snapshot.vendorsWithoutStall} without a stall',
                onTap: () => onGoToTab(_usersTab),
              ),
              KpiCard(
                label: 'Approved stalls',
                value: '${snapshot.approved}',
                icon: Icons.verified_outlined,
                tint: VendrgoColors.mint,
                footnote: 'of ${snapshot.stalls.length} registered',
                onTap: () => onGoToTab(_stallsTab),
              ),
              KpiCard(
                label: 'Open right now',
                value: '${snapshot.openNow}',
                icon: Icons.storefront_rounded,
                tint: VendrgoColors.mint,
                footnote: openShare,
                onTap: () => onGoToTab(_stallsTab),
              ),
              KpiCard(
                label: 'Pending approval',
                value: '${snapshot.pending}',
                icon: Icons.pending_actions_rounded,
                tint: VendrgoColors.warningSoft,
                onTap: () => onGoToTab(_approvalsTab),
              ),
              KpiCard(
                label: 'Suspended accounts',
                value: '${snapshot.suspendedAccounts}',
                icon: Icons.block_rounded,
                tint: VendrgoColors.errorSoft,
                onTap: () => onGoToTab(_usersTab),
              ),
            ],
          ),
          const SizedBox(height: 24),

          AdminListCard(
            title: 'Food categories',
            subtitle:
                '${snapshot.categories.length} categories · add, rename or '
                'remove',
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: VendrgoColors.peach,
                borderRadius: VendrgoRadius.mdAll,
              ),
              child: const Icon(
                Icons.category_outlined,
                color: VendrgoColors.primaryDark,
              ),
            ),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AdminCategoriesScreen(
                    initialSnapshot: snapshot,
                    repository: repository,
                  ),
                ),
              );

              await onRefresh();
            },
          ),
          const SizedBox(height: 24),

          const SectionHeader(title: 'Insights'),
          const SizedBox(height: 8),
          ChartCard(
            title: 'Stalls by status',
            subtitle: 'Every registered stall',
            child: DonutChart(
              centerLabel: 'stalls',
              segments: [
                ChartItem('Approved', snapshot.approved, VendrgoColors.success),
                ChartItem('Pending', snapshot.pending, VendrgoColors.warning),
                ChartItem('Rejected', snapshot.rejected, VendrgoColors.error),
                ChartItem(
                  'Suspended',
                  snapshot.suspended,
                  VendrgoColors.textSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ChartCard(
            title: 'New stalls, last 7 days',
            subtitle: 'Registrations per day',
            child: ColumnChart(
              values: [for (final day in days) day.value],
              labels: [for (final day in days) weekdayName(day.key)],
            ),
          ),
          const SizedBox(height: 12),
          ChartCard(
            title: 'Open vs closed now',
            subtitle: 'Approved stalls only',
            child: HBarChart(
              items: [
                ChartItem('Open', snapshot.openNow, VendrgoColors.success),
                ChartItem(
                  'Closed',
                  snapshot.closedNow,
                  VendrgoColors.textTertiary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ChartCard(
            title: 'Stalls by category',
            subtitle: categories.isEmpty ? null : 'Top ${categories.length}',
            child: categories.isEmpty
                ? const Text('No stalls yet.', style: VendrgoText.bodySecondary)
                : HBarChart(
                    items: [
                      for (final entry in categories)
                        ChartItem(
                          entry.key,
                          entry.value,
                          VendrgoColors.primary,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          ChartCard(
            title: 'Most favorited stalls',
            subtitle: 'Saved by customers',
            child: favorites.isEmpty
                ? const Text(
                    'No favorites yet.',
                    style: VendrgoText.bodySecondary,
                  )
                : HBarChart(
                    items: [
                      for (final entry in favorites)
                        ChartItem(entry.key, entry.value, VendrgoColors.offer),
                    ],
                  ),
          ),
          const SizedBox(height: 24),

          if (pendingStalls.isNotEmpty) ...[
            SectionHeader(
              title: 'Needs attention',
              actionLabel: 'See all',
              onAction: () => onGoToTab(_approvalsTab),
            ),
            const SizedBox(height: 8),
            for (final stall in pendingStalls.take(3)) ...[
              AdminListCard(
                title: stall['name'] as String? ?? 'Unnamed stall',
                subtitle:
                    '${snapshot.profileById(stall['vendor_id'])?['full_name'] ?? 'Vendor'}'
                    ' · submitted ${ageLabel(parseDate(stall['created_at']), now)}',
                badge: StatusBadge.approval(status: 'pending'),
                onTap: () => openAdminReview(
                  context,
                  snapshot: snapshot,
                  stall: stall,
                  onChanged: onRefresh,
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
          ],

          SectionHeader(
            title: 'Recently registered',
            actionLabel: 'All stalls',
            onAction: () => onGoToTab(_stallsTab),
          ),
          const SizedBox(height: 8),
          if (snapshot.stalls.isEmpty)
            const Text('No stalls yet.', style: VendrgoText.bodySecondary)
          else
            for (final stall in snapshot.recentStalls()) ...[
              AdminListCard(
                title: stall['name'] as String? ?? 'Unnamed stall',
                subtitle:
                    '${snapshot.categoryOf(stall)} · '
                    '${ageLabel(parseDate(stall['created_at']), now)}',
                badge: StatusBadge.approval(status: snapshot.statusOf(stall)),
                onTap: () => showAdminStallSheet(
                  context,
                  snapshot: snapshot,
                  stall: stall,
                  repository: repository,
                  onChanged: onRefresh,
                ),
              ),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: snapshot.summaryReport()),
              );

              if (context.mounted) {
                showAppSnackBar(context, 'Summary report copied to clipboard.');
              }
            },
            icon: const Icon(Icons.copy_all_rounded),
            label: const Text('Copy summary report'),
          ),
        ],
      ),
    );
  }
}
