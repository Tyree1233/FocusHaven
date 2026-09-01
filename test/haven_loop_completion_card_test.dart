import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/app_localizations.dart';
import 'package:focushaven/services/haven_loop_service.dart';
import 'package:focushaven/widgets/haven_loop_completion_card.dart';

void main() {
  Widget app({
    required HavenLoopResolutionAction complete,
    required HavenLoopResolutionAction keep,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: Scaffold(
        body: HavenLoopCompletionCard(
          taskTitle: 'Prepare the launch brief',
          onMarkComplete: complete,
          onKeepForLater: keep,
        ),
      ),
    );
  }

  testWidgets('offers two explicit outcomes and never auto-resolves', (
    tester,
  ) async {
    var completeCalls = 0;
    var keepCalls = 0;
    await tester.pumpWidget(
      app(
        complete: () async {
          completeCalls += 1;
          return HavenLoopResolution.completed;
        },
        keep: () async {
          keepCalls += 1;
          return HavenLoopResolution.keptForLater;
        },
      ),
    );

    expect(find.text('Prepare the launch brief'), findsOneWidget);
    expect(find.text('Mark task complete'), findsOneWidget);
    expect(find.text('Keep for later'), findsOneWidget);
    expect(completeCalls, 0);
    expect(keepCalls, 0);

    await tester.tap(find.byKey(const ValueKey('haven-loop-keep-for-later')));
    await tester.pump();

    expect(completeCalls, 0);
    expect(keepCalls, 1);
  });

  testWidgets('stale outcomes fail closed with an explanation', (tester) async {
    await tester.pumpWidget(
      app(
        complete: () async => HavenLoopResolution.unavailable,
        keep: () async => HavenLoopResolution.unavailable,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('haven-loop-mark-complete')));
    await tester.pump();

    expect(
      find.text('That task changed, so no queue action was taken.'),
      findsOneWidget,
    );
  });
}
