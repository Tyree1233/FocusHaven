import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focushaven/l10n/app_localizations.dart';
import 'package:focushaven/models/adaptive_focus_suggestion.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/timer_service.dart';
import 'package:focushaven/widgets/adaptive_focus_production_review.dart';

const preview = AdaptiveFocusSuggestion(
  currentFocusMinutes: 25,
  currentBreakMinutes: 5,
  suggestedFocusMinutes: 15,
  suggestedBreakMinutes: 10,
  direction: AdaptiveFocusDirection.gentler,
  breakDirection: AdaptiveFocusBreakDirection.moreRecovery,
  basis: AdaptiveFocusBasis.recoveryPriority,
  evidenceStrength: AdaptiveFocusEvidenceStrength.supported,
  relevantSignalCount: 2,
  usesRecoveryPattern: true,
  usesLatestReflection: false,
  usesRepeatedRhythm: false,
  usesForecast: false,
);

const request = (
  currentFocusMinutes: 25,
  currentBreakMinutes: 5,
  preserveCurrentChoice: false,
);

Widget app(TimerService timer, {double textScale = 1}) => ProviderScope(
  overrides: [
    timerServiceProvider.overrideWith((ref) => timer),
    adaptiveFocusSuggestionProvider(request).overrideWithValue(preview),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: const Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(12),
        child: AdaptiveFocusProductionReview(suggestion: preview),
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<TimerService> createTimer() async {
    final timer = TimerService();
    await timer.initialized;
    return timer;
  }

  test('all runtime locales expose complete generated Adaptive Focus copy', () {
    expect(AppLocalizations.supportedLocales, hasLength(17));
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      final messages = <String>[
        l10n.adaptiveFocusEyebrow,
        l10n.adaptiveFocusGentlerTitle,
        l10n.adaptiveFocusGrowthTitle,
        l10n.adaptiveFocusCurrentPlan(25, 5),
        l10n.adaptiveFocusSuggestedPlan(15, 10),
        l10n.adaptiveFocusRecoveryReason,
        l10n.adaptiveFocusReflectionReason,
        l10n.adaptiveFocusRhythmReason,
        l10n.adaptiveFocusForecastContext,
        l10n.adaptiveFocusPrivacy,
        l10n.adaptiveFocusNoAutomaticChange,
        l10n.adaptiveFocusReviewSummary(
          25,
          5,
          15,
          10,
          l10n.adaptiveFocusRecoveryReason,
        ),
        l10n.adaptiveFocusKeepCurrent,
        l10n.adaptiveFocusUseSuggestion,
        l10n.adaptiveFocusApplied(15, 10),
        l10n.adaptiveFocusKept,
        l10n.adaptiveFocusChanged,
      ];
      expect(messages, hasLength(17), reason: locale.toLanguageTag());
      for (final message in messages) {
        expect(message.trim(), isNotEmpty, reason: locale.toLanguageTag());
        expect(message, isNot(contains(RegExp(r'\{[^}]+\}'))));
      }
    }
  });

  testWidgets('renders reviewed localized copy from the runtime catalog', (
    tester,
  ) async {
    final timer = await createTimer();
    await tester.pumpWidget(app(timer));
    await tester.pump();

    expect(find.text('ADAPTIVE FOCUS'), findsOneWidget);
    expect(find.text('A gentler session may fit'), findsOneWidget);
    expect(find.text('Current: 25 min focus · 5 min break'), findsOneWidget);
    expect(find.text('Suggested: 15 min focus · 10 min break'), findsOneWidget);
    expect(find.text('Keep current settings'), findsOneWidget);
    expect(find.text('Use suggestion'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('accept applies both defaults once and never starts a session', (
    tester,
  ) async {
    final timer = await createTimer();
    await tester.pumpWidget(app(timer));
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey<String>('adaptive-focus-accept')),
    );
    await tester.pump();

    expect(timer.focusDurationSeconds, 15 * 60);
    expect(timer.shortBreakDurationSeconds, 10 * 60);
    expect(timer.secondsRemaining, 15 * 60);
    expect(timer.isRunning, isFalse);
    expect(timer.isComplete, isFalse);
    expect(
      find.text(
        'Future Focus sessions will use 15 minutes with 10-minute short breaks. '
        'No session was started.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('adaptive-focus-review-card')),
      findsNothing,
    );
  });

  testWidgets('keep current consumes the review without changing defaults', (
    tester,
  ) async {
    final timer = await createTimer();
    await tester.pumpWidget(app(timer));
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey<String>('adaptive-focus-keep-current')),
    );
    await tester.pump();

    expect(timer.focusDurationSeconds, 25 * 60);
    expect(timer.shortBreakDurationSeconds, 5 * 60);
    expect(timer.isRunning, isFalse);
    expect(find.text('Current Focus settings were kept.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('adaptive-focus-review-card')),
      findsNothing,
    );
  });

  testWidgets('changed timer state rejects the stale review without mutation', (
    tester,
  ) async {
    final timer = await createTimer();
    await tester.pumpWidget(app(timer));
    await tester.pump();

    timer.setCustomDuration(30, 0);
    await tester.tap(
      find.byKey(const ValueKey<String>('adaptive-focus-accept')),
    );
    await tester.pump();

    expect(timer.focusDurationSeconds, 30 * 60);
    expect(timer.shortBreakDurationSeconds, 5 * 60);
    expect(timer.isRunning, isFalse);
    expect(
      find.text('The timer changed, so this suggestion was not applied.'),
      findsOneWidget,
    );
  });

  testWidgets('remains usable with large text on a narrow surface', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final timer = await createTimer();

    await tester.pumpWidget(app(timer, textScale: 2));
    await tester.pump();

    expect(find.text('Use suggestion'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('adaptive-focus-review-card')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
