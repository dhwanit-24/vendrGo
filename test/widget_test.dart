import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendr_go/core/theme/app_theme.dart';
import 'package:vendr_go/features/onboarding/onboarding_screen.dart';
import 'package:vendr_go/main.dart';
import 'package:vendr_go/shared/widgets/app_ui.dart';
import 'package:vendr_go/shared/widgets/feedback_widgets.dart';
import 'package:vendr_go/shared/widgets/stall_card.dart';
import 'package:vendr_go/shared/widgets/status_badge.dart';

void main() {
  testWidgets('theme and shared widgets render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: VendrgoTheme.light(),
        home: const Scaffold(
          body: Column(
            children: [
              VendrgoLogo(),
              SectionCard(child: Text('hello')),
              _FieldHost(),
            ],
          ),
        ),
      ),
    );

    expect(find.text('hello'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
  });

  sharedWidgetTests();

  testWidgets('shared widgets survive 1.3x text scale', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: VendrgoTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                StallCard(
                  name: 'Momo Corner With A Fairly Long Name',
                  isOpen: false,
                  categoryName: 'Street Food',
                  distanceLabel: '300 m',
                  hours: '9:00 AM - 5:00 PM',
                  isFavorite: true,
                ),
                EmptyState(
                  title: 'No stalls found',
                  message: 'Try removing a filter.',
                  actionLabel: 'Clear filters',
                  onAction: null,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('splash, error and onboarding screens render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: VendrgoTheme.light(), home: const SplashScreen()),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('open near you'), findsOneWidget);

    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: VendrgoTheme.light(),
        home: StartupErrorScreen(error: 'boom', onRetry: () => retried = true),
      ),
    );
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        theme: VendrgoTheme.light(),
        home: OnboardingScreen(onDone: () {}),
      ),
    );
    expect(find.text('Next'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Know what is open right now'), findsOneWidget);
  });
}

void sharedWidgetTests() {
  testWidgets('new shared widgets render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: VendrgoTheme.light(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                StallCard(
                  name: 'Momo Corner',
                  isOpen: true,
                  categoryName: 'Street Food',
                  distanceLabel: '300 m',
                  isFavorite: false,
                ),
                StatusBadge(label: 'Pending', tone: BadgeTone.warning),
                EmptyState(title: 'Nothing here'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Momo Corner'), findsOneWidget);
    expect(find.text('Street Food · 300 m'), findsOneWidget);
    expect(find.text('Nothing here'), findsOneWidget);
  });
}

class _FieldHost extends StatefulWidget {
  const _FieldHost();

  @override
  State<_FieldHost> createState() => _FieldHostState();
}

class _FieldHostState extends State<_FieldHost> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: 'Email',
      hint: 'you@example.com',
      icon: Icons.email_outlined,
    );
  }
}
