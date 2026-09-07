import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/models/adaptive_focus_suggestion.dart';
import 'package:focushaven/widgets/adaptive_focus_review_card.dart';

const _preview = AdaptiveFocusSuggestion(
  currentFocusMinutes: 25,
  currentBreakMinutes: 5,
  suggestedFocusMinutes: 15,
  suggestedBreakMinutes: 5,
  direction: AdaptiveFocusDirection.gentler,
  breakDirection: AdaptiveFocusBreakDirection.keepCurrent,
  basis: AdaptiveFocusBasis.recoveryPriority,
  evidenceStrength: AdaptiveFocusEvidenceStrength.supported,
  relevantSignalCount: 2,
  usesRecoveryPattern: true,
  usesLatestReflection: false,
  usesRepeatedRhythm: false,
  usesForecast: false,
);

const _unchangedPreview = AdaptiveFocusSuggestion(
  currentFocusMinutes: 25,
  currentBreakMinutes: 5,
  suggestedFocusMinutes: 25,
  suggestedBreakMinutes: 5,
  direction: AdaptiveFocusDirection.keepCurrent,
  breakDirection: AdaptiveFocusBreakDirection.keepCurrent,
  basis: AdaptiveFocusBasis.currentBaseline,
  evidenceStrength: AdaptiveFocusEvidenceStrength.limited,
  relevantSignalCount: 0,
  usesRecoveryPattern: false,
  usesLatestReflection: false,
  usesRepeatedRhythm: false,
  usesForecast: false,
);

const _copy = AdaptiveFocusReviewCopy(
  eyebrow: 'Fixture eyebrow',
  title: 'Fixture title',
  currentPlan: 'Fixture current plan',
  suggestedPlan: 'Fixture suggested plan',
  reason: 'Fixture reason',
  privacyBoundary: 'Fixture privacy boundary',
  noAutomaticChange: 'Fixture no automatic change boundary',
  summarySemantics: 'Fixture complete accessible summary',
  keepCurrentAction: 'Fixture keep current action',
  acceptAction: 'Fixture accept action',
);

Widget app({
  AdaptiveFocusSuggestion preview = _preview,
  AdaptiveFocusReviewCallback? onKeepCurrent,
  AdaptiveFocusReviewCallback? onAccept,
  double textScale = 1,
  double width = 380,
}) => MaterialApp(
  theme: ThemeData.dark().copyWith(
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFF16FBA),
      surface: Color(0xFF352260),
    ),
  ),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: width,
          child: AdaptiveFocusReviewCard(
            suggestion: preview,
            copy: _copy,
            onKeepCurrent: onKeepCurrent ?? (_) {},
            onAccept: onAccept ?? (_) {},
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('renders only the complete copy supplied by its caller', (
    tester,
  ) async {
    await tester.pumpWidget(app());

    for (final text in <String>[
      _copy.eyebrow,
      _copy.title,
      _copy.currentPlan,
      _copy.suggestedPlan,
      _copy.reason,
      _copy.privacyBoundary,
      _copy.noAutomaticChange,
      _copy.keepCurrentAction,
      _copy.acceptAction,
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('keep current emits the exact suggestion only once', (
    tester,
  ) async {
    final received = <AdaptiveFocusSuggestion>[];
    var acceptCount = 0;
    await tester.pumpWidget(
      app(onKeepCurrent: received.add, onAccept: (_) => acceptCount += 1),
    );

    final keep = find.byKey(
      const ValueKey<String>('adaptive-focus-keep-current'),
    );
    await tester.tap(keep);
    await tester.tap(keep, warnIfMissed: false);
    await tester.pump();

    expect(received, [same(_preview)]);
    expect(acceptCount, 0);
    expect(tester.widget<OutlinedButton>(keep).onPressed, isNull);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey<String>('adaptive-focus-accept')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('accept is serialized while its exact callback is pending', (
    tester,
  ) async {
    final pending = Completer<void>();
    final received = <AdaptiveFocusSuggestion>[];
    await tester.pumpWidget(
      app(
        onAccept: (suggestion) {
          received.add(suggestion);
          return pending.future;
        },
      ),
    );

    final accept = find.byKey(const ValueKey<String>('adaptive-focus-accept'));
    await tester.tap(accept);
    await tester.tap(accept, warnIfMissed: false);
    await tester.pump();

    expect(received, [same(_preview)]);
    expect(tester.widget<FilledButton>(accept).onPressed, isNull);

    pending.complete();
    await tester.pump();
    expect(received, hasLength(1));
  });

  testWidgets('an unchanged preview offers no accept control', (tester) async {
    await tester.pumpWidget(app(preview: _unchangedPreview));

    expect(
      find.byKey(const ValueKey<String>('adaptive-focus-keep-current')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('adaptive-focus-accept')),
      findsNothing,
    );
    expect(find.text(_copy.acceptAction), findsNothing);
  });

  testWidgets('exposes one reviewed summary and two explicit actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(app());

      expect(find.bySemanticsLabel(_copy.summarySemantics), findsOneWidget);
      expect(find.bySemanticsLabel(_copy.keepCurrentAction), findsOneWidget);
      expect(find.bySemanticsLabel(_copy.acceptAction), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('remains usable on a narrow surface with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(textScale: 2, width: 280));

    expect(find.text(_copy.currentPlan), findsOneWidget);
    expect(find.text(_copy.acceptAction), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
