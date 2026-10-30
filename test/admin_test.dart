import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendr_go/core/theme/app_theme.dart';
import 'package:vendr_go/features/admin/admin_data.dart';
import 'package:vendr_go/features/admin/admin_widgets.dart';

AdminSnapshot _snapshot() {
  final now = DateTime(2026, 10, 28, 12);

  return AdminSnapshot(
    loadedAt: now,
    categoryNames: {'c1': 'Street Food', 'c2': 'Beverages'},
    profiles: [
      {'id': 'u1', 'role': 'customer', 'full_name': 'Asha', 'is_active': true},
      {'id': 'u2', 'role': 'customer', 'full_name': 'Ben', 'is_active': false},
      {'id': 'v1', 'role': 'vendor', 'full_name': 'Vik', 'is_active': true},
      {'id': 'v2', 'role': 'vendor', 'full_name': 'Vera', 'is_active': true},
      {'id': 'a1', 'role': 'admin', 'full_name': 'Root', 'is_active': true},
    ],
    stalls: [
      {
        'id': 's1',
        'vendor_id': 'v1',
        'name': 'Momo Corner',
        'category_id': 'c1',
        'approval_status': 'approved',
        'is_open': true,
        'created_at': '2026-10-28T08:00:00',
      },
      {
        'id': 's2',
        'vendor_id': 'v1',
        'name': 'Chai Stop',
        'category_id': 'c2',
        'approval_status': 'approved',
        'is_open': false,
        'created_at': '2026-10-26T08:00:00',
      },
      {
        'id': 's3',
        'vendor_id': 'v1',
        'name': 'New Stall',
        'category_id': 'c1',
        'approval_status': 'pending',
        'is_open': false,
        'created_at': '2026-10-20T08:00:00',
      },
    ],
    favorites: [
      {'user_id': 'u1', 'stall_id': 's1'},
      {'user_id': 'u2', 'stall_id': 's1'},
      {'user_id': 'u1', 'stall_id': 's2'},
    ],
  );
}

void main() {
  group('AdminSnapshot', () {
    test('counts users and stalls', () {
      final snapshot = _snapshot();

      expect(snapshot.customers, 2);
      expect(snapshot.vendors, 2);
      expect(snapshot.admins, 1);
      expect(snapshot.suspendedAccounts, 1);
      expect(snapshot.approved, 2);
      expect(snapshot.pending, 1);
      expect(snapshot.openNow, 1);
      expect(snapshot.closedNow, 1);
      expect(snapshot.vendorsWithoutStall, 1);
    });

    test('groups stalls by category, biggest first', () {
      final categories = _snapshot().stallsByCategory;

      expect(categories.first.key, 'Street Food');
      expect(categories.first.value, 2);
      expect(categories.last.key, 'Beverages');
    });

    test('buckets stalls into the last 7 days', () {
      final days = _snapshot().stallsCreatedPerDay(
        now: DateTime(2026, 10, 28, 12),
      );

      expect(days.length, 7);
      expect(days.last.value, 1); // 28 Oct
      expect(days[4].value, 1); // 26 Oct
      expect(days.fold<int>(0, (sum, day) => sum + day.value), 2);
    });

    test('ranks favorited stalls', () {
      final top = _snapshot().topFavorited();

      expect(top.first.key, 'Momo Corner');
      expect(top.first.value, 2);
    });

    test('summary report lists the headline numbers', () {
      final report = _snapshot().summaryReport();

      expect(report, contains('Customers: 2'));
      expect(report, contains('Pending approval: 1'));
      expect(report, contains('Street Food: 2'));
    });

    test('ageLabel is friendly', () {
      final now = DateTime(2026, 10, 28, 12);

      expect(ageLabel(DateTime(2026, 10, 28, 1), now), 'Today');
      expect(ageLabel(DateTime(2026, 10, 27), now), 'Yesterday');
      expect(ageLabel(DateTime(2026, 10, 25), now), '3 days ago');
      expect(ageLabel(null, now), 'Unknown date');
    });
  });

  group('categories', () {
    test('lists categories alphabetically with stall counts', () {
      final snapshot = _snapshot();

      expect(snapshot.categories.map((c) => c.value), [
        'Beverages',
        'Street Food',
      ]);
      expect(snapshot.stallCountForCategory('c1'), 2);
      expect(snapshot.stallCountForCategory('c2'), 1);
      expect(snapshot.stallCountForCategory('unused'), 0);
    });

    test('validates names', () {
      const existing = ['Street Food', 'Beverages'];

      expect(validateCategoryName('Desserts', existing), isNull);
      expect(validateCategoryName(' ', existing), isNotNull);
      expect(validateCategoryName('A', existing), isNotNull);
      expect(validateCategoryName('x' * 31, existing), isNotNull);
      expect(validateCategoryName('street food', existing), isNotNull);
      expect(validateCategoryName('  BEVERAGES ', existing), isNotNull);
    });

    test('renaming may keep the same name or change its case', () {
      const existing = ['Street Food', 'Beverages'];

      expect(
        validateCategoryName('street food', existing, ignore: 'Street Food'),
        isNull,
      );
      expect(
        validateCategoryName('Beverages', existing, ignore: 'Street Food'),
        isNotNull,
      );
    });
  });

  group('admin widgets', () {
    Future<void> pumpNarrow(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: VendrgoTheme.light(),
          builder: (context, widget) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: widget!,
          ),
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );
    }

    testWidgets('KPI cards do not overflow on a narrow screen', (tester) async {
      await pumpNarrow(
        tester,
        Padding(
          padding: const EdgeInsets.all(16),
          child: KpiGrid(
            children: const [
              KpiCard(
                label: 'Customers',
                value: '128',
                icon: Icons.people_alt_outlined,
                tint: VendrgoColors.lavender,
              ),
              KpiCard(
                label: 'Vendors',
                value: '34',
                icon: Icons.storefront_outlined,
                tint: VendrgoColors.peach,
                footnote: '3 without a stall',
              ),
              KpiCard(
                label: 'Pending approval',
                value: '7',
                icon: Icons.pending_actions_rounded,
                tint: VendrgoColors.warningSoft,
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Customers'), findsOneWidget);
      expect(find.text('3 without a stall'), findsOneWidget);
    });

    testWidgets('charts render with data and when empty', (tester) async {
      await pumpNarrow(
        tester,
        const Column(
          children: [
            DonutChart(
              centerLabel: 'stalls',
              segments: [
                ChartItem('Approved', 5, VendrgoColors.success),
                ChartItem('Pending', 2, VendrgoColors.warning),
              ],
            ),
            DonutChart(centerLabel: 'stalls', segments: []),
            ColumnChart(
              values: [0, 1, 3, 0, 2, 5, 1],
              labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
            ),
            HBarChart(
              items: [
                ChartItem('Street Food', 4, VendrgoColors.primary),
                ChartItem('Beverages', 0, VendrgoColors.primary),
              ],
            ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Street Food'), findsOneWidget);
    });
  });
}
