import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dnd_auto_app/theme/app_theme.dart';
import 'package:dnd_auto_app/widgets/rule_list_empty_state.dart';

void main() {
  testWidgets('empty rules list renders empty state and create action', (
    tester,
  ) async {
    var createTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: RuleListEmptyState(
            bottomSafePadding: 0,
            onCreateRule: () {
              createTapped = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('No rules yet'), findsOneWidget);
    expect(
      find.text('Create your first rule to automate Do Not Disturb.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Create rule'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Create rule'));
    await tester.pump();

    expect(createTapped, isTrue);
  });

  testWidgets('empty rules state fits on smaller screens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: RuleListEmptyState(bottomSafePadding: 0, onCreateRule: () {}),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('No rules yet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Create rule'), findsOneWidget);
  });
}
