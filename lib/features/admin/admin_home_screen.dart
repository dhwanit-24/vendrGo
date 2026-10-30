import 'package:flutter/material.dart';

import '../../shared/widgets/feedback_widgets.dart';
import 'admin_approvals_tab.dart';
import 'admin_dashboard_tab.dart';
import 'admin_data.dart';
import 'admin_stalls_tab.dart';
import 'admin_users_tab.dart';

/// Admin home: four tabs sharing one snapshot of the data.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final repository = AdminRepository();

  AdminSnapshot? snapshot;
  Object? error;
  int selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await repository.load();

      if (!mounted) return;

      setState(() {
        snapshot = result;
        error = null;
      });
    } catch (loadError) {
      if (!mounted) return;

      // Keep showing the old data if a refresh fails.
      setState(() {
        error = loadError;
      });

      if (snapshot != null) {
        showAppSnackBar(context, 'Could not refresh data.', isError: true);
      }
    }
  }

  Widget _body(AdminSnapshot data) {
    return IndexedStack(
      index: selectedTab,
      children: [
        AdminDashboardTab(
          snapshot: data,
          repository: repository,
          onRefresh: _load,
          onGoToTab: (index) => setState(() => selectedTab = index),
        ),
        AdminApprovalsTab(snapshot: data, onRefresh: _load),
        AdminUsersTab(snapshot: data, repository: repository, onRefresh: _load),
        AdminStallsTab(
          snapshot: data,
          repository: repository,
          onRefresh: _load,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = snapshot;

    return Scaffold(
      body: SafeArea(
        child: data != null
            ? _body(data)
            : error != null
            ? EmptyState(
                icon: Icons.wifi_off_rounded,
                title: 'Could not load admin data',
                message:
                    'Check your connection and that this account has the '
                    'admin role.',
                actionLabel: 'Retry',
                onAction: () {
                  setState(() => error = null);
                  _load();
                },
              )
            : const Center(child: CircularProgressIndicator()),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) => setState(() => selectedTab = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: (data?.pending ?? 0) > 0,
              label: Text('${data?.pending ?? 0}'),
              child: const Icon(Icons.fact_check_outlined),
            ),
            selectedIcon: const Icon(Icons.fact_check_rounded),
            label: 'Approvals',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Users',
          ),
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'Stalls',
          ),
        ],
      ),
    );
  }
}
