import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendr_go/core/theme/app_theme.dart';
import 'package:vendr_go/features/admin/admin_data.dart';
import 'package:vendr_go/main.dart' show FriendlyErrorWidget;
import 'package:vendr_go/shared/widgets/text_input_dialog.dart';

/// A page with one button that opens the dialog and records the result.
class _Host extends StatefulWidget {
  final String? Function(String text)? validator;
  final String initialValue;

  const _Host({this.validator, this.initialValue = ''});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String result = 'none';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () async {
              final value = await showTextInputDialog(
                context,
                title: 'New category',
                label: 'Category name',
                actionLabel: 'Add',
                initialValue: widget.initialValue,
                validator: widget.validator,
              );

              setState(() => result = value ?? 'cancelled');
            },
            child: const Text('Open'),
          ),
          Text('result: $result'),
        ],
      ),
    );
  }
}

Future<void> _pump(WidgetTester tester, Widget home) {
  return tester.pumpWidget(
    MaterialApp(theme: VendrgoTheme.light(), home: home),
  );
}

void main() {
  group('showTextInputDialog', () {
    testWidgets('Cancel closes cleanly with no error', (tester) async {
      await _pump(tester, const _Host());

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Category name'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('result: cancelled'), findsOneWidget);
    });

    testWidgets('Cancel works again and again', (tester) async {
      await _pump(tester, const _Host());

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('closing right after typing is safe', (tester) async {
      await _pump(tester, const _Host(initialValue: 'Desserts'));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Rolls');
      await tester.tap(find.text('Cancel'));
      // Do not settle: pump through the closing animation frame by frame.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('invalid input shows an error, valid input returns text', (
      tester,
    ) async {
      await _pump(
        tester,
        _Host(
          validator: (text) =>
              validateCategoryName(text, const ['Street Food']),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'street food');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(
        find.text('A category with this name already exists.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), '  Desserts ');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('result: Desserts'), findsOneWidget);
    });
  });

  testWidgets('friendly error widget replaces the red screen', (tester) async {
    await tester.pumpWidget(const FriendlyErrorWidget());

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Please go back and try again.'), findsOneWidget);
  });
}
