import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/app_localizations.dart';
import 'package:focushaven/models/focus_milestone.dart';
import 'package:focushaven/widgets/focus_milestones_sheet.dart';

Widget _app(List<FocusMilestone> milestones) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData.dark(),
    home: Scaffold(body: FocusMilestonesSheet(milestones: milestones)),
  );
}

void main() {
  testWidgets('renders accurate progress and milestone status icons', (
    tester,
  ) async {
    const milestones = [
      FocusMilestone(
        title: 'First focus',
        detail: 'Complete one focus session.',
        unlocked: true,
      ),
      FocusMilestone(
        title: 'Steady rhythm',
        detail: 'Complete five focus sessions.',
        unlocked: false,
      ),
      FocusMilestone(
        title: 'Focused hour',
        detail: 'Focus for sixty minutes.',
        unlocked: true,
      ),
    ];

    await tester.pumpWidget(_app(milestones));

    expect(find.text('Focus milestones'), findsOneWidget);
    expect(find.text('2 of 3 unlocked'), findsOneWidget);
    expect(find.text('First focus'), findsOneWidget);
    expect(find.text('Complete five focus sessions.'), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events_outlined), findsNWidgets(2));
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolls through milestones that begin outside the viewport', (
    tester,
  ) async {
    final milestones = List.generate(
      12,
      (index) => FocusMilestone(
        title: 'Milestone ${index + 1}',
        detail: 'Progress detail ${index + 1}',
        unlocked: index < 4,
      ),
    );

    await tester.pumpWidget(_app(milestones));

    expect(find.text('4 of 12 unlocked'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Milestone 12'),
      180,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('Milestone 12'), findsOneWidget);
    expect(find.text('Progress detail 12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
