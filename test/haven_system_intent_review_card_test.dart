import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focushaven/models/haven_action.dart';
import 'package:focushaven/models/haven_system_intent.dart';
import 'package:focushaven/services/focus_queue_service.dart';
import 'package:focushaven/services/haven_action_engine.dart';
import 'package:focushaven/services/haven_system_intent_review_service.dart';
import 'package:focushaven/services/timer_service.dart';
import 'package:focushaven/widgets/haven_system_intent_review_card.dart';

const _copy = HavenSystemIntentReviewCopy(
  eyebrow: 'Fixture assistant request',
  title: 'Fixture review title',
  sourceBoundary: 'Fixture bounded source',
  privacyBoundary: 'Fixture private local review',
  freshnessBoundary: 'Fixture short-lived review',
  confirmationBoundary: 'Fixture explicit confirmation boundary',
  riskLabel: 'Fixture reversible control',
  summarySemantics: 'Fixture complete accessible review summary',
  dismissAction: 'Fixture dismiss action',
  confirmAction: 'Fixture confirm exact action',
);

Widget _app({
  required HavenSystemIntentReview review,
  HavenSystemIntentReviewCallback? onDismiss,
  HavenSystemIntentReviewCallback? onConfirm,
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
          child: HavenSystemIntentReviewCard(
            review: review,
            copy: _copy,
            onDismiss: onDismiss ?? (_) {},
            onConfirm: onConfirm ?? (_) {},
          ),
        ),
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<
    ({HavenSystemIntentReviewService bridge, HavenSystemIntentReview review})
  >
  createReview({String invocationId = 'presentation-1'}) async {
    final timer = TimerService();
    final queue = FocusQueueService();
    await Future.wait([timer.initialized, queue.initialized]);
    addTearDown(timer.dispose);
    addTearDown(queue.dispose);
    final now = DateTime.utc(2026, 9, 9, 18);
    var nextId = 0;
    final bridge = HavenSystemIntentReviewService(
      engine: HavenActionEngine(
        executor: HavenActionExecutor(
          timer: timer,
          focusQueue: queue,
          openSurface: (_) async => true,
        ),
        clock: () => now,
      ),
      clock: () => now,
      idGenerator: () => 'presentation-review-${++nextId}',
    );
    final preparation = bridge.prepareReview(
      HavenSystemIntentDraft.startFocusTimer(invocationId),
    );
    expect(preparation.isReady, isTrue);
    return (bridge: bridge, review: preparation.review!);
  }

  testWidgets('renders only complete caller copy and opaque review details', (
    tester,
  ) async {
    final owned = await createReview();
    await tester.pumpWidget(_app(review: owned.review));

    for (final text in <String>[
      _copy.eyebrow,
      _copy.title,
      owned.review.interpretation,
      owned.review.effect,
      _copy.sourceBoundary,
      _copy.privacyBoundary,
      _copy.freshnessBoundary,
      _copy.confirmationBoundary,
      _copy.riskLabel,
      _copy.dismissAction,
      _copy.confirmAction,
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(owned.review.actionKind, HavenActionKind.startTimer);
    expect(owned.review.source, HavenActionSource.systemIntent);
    expect(owned.review.requiresExactConfirmation, isTrue);
    expect(owned.review.canExecuteWithoutConfirmation, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismiss returns the exact opaque review only once', (
    tester,
  ) async {
    final owned = await createReview();
    final received = <HavenSystemIntentReview>[];
    var confirmCount = 0;
    await tester.pumpWidget(
      _app(
        review: owned.review,
        onDismiss: received.add,
        onConfirm: (_) => confirmCount += 1,
      ),
    );

    final dismiss = find.byKey(
      const ValueKey<String>('system-intent-dismiss-review'),
    );
    await tester.tap(dismiss);
    await tester.tap(dismiss, warnIfMissed: false);
    await tester.pump();

    expect(received, [same(owned.review)]);
    expect(confirmCount, 0);
    expect(tester.widget<OutlinedButton>(dismiss).onPressed, isNull);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey<String>('system-intent-confirm-review')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('confirm is serialized while its exact callback is pending', (
    tester,
  ) async {
    final owned = await createReview();
    final pending = Completer<void>();
    final received = <HavenSystemIntentReview>[];
    await tester.pumpWidget(
      _app(
        review: owned.review,
        onConfirm: (review) {
          received.add(review);
          return pending.future;
        },
      ),
    );

    final confirm = find.byKey(
      const ValueKey<String>('system-intent-confirm-review'),
    );
    await tester.tap(confirm);
    await tester.tap(confirm, warnIfMissed: false);
    await tester.pump();

    expect(received, [same(owned.review)]);
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    pending.complete();
    await tester.pump();
    expect(received, hasLength(1));
  });

  testWidgets('a different opaque review resets the one-shot controls', (
    tester,
  ) async {
    final first = await createReview(invocationId: 'presentation-first');
    final secondPreparation = first.bridge.prepareReview(
      const HavenSystemIntentDraft.startFocusTimer('presentation-second'),
    );
    final second = secondPreparation.review!;
    await tester.pumpWidget(_app(review: first.review));

    await tester.tap(
      find.byKey(const ValueKey<String>('system-intent-dismiss-review')),
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey<String>('system-intent-confirm-review')),
          )
          .onPressed,
      isNull,
    );

    await tester.pumpWidget(_app(review: second));
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey<String>('system-intent-confirm-review')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('exposes one complete summary and two explicit choices', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final owned = await createReview();
      await tester.pumpWidget(_app(review: owned.review));

      expect(find.bySemanticsLabel(_copy.summarySemantics), findsOneWidget);
      expect(find.bySemanticsLabel(_copy.dismissAction), findsOneWidget);
      expect(find.bySemanticsLabel(_copy.confirmAction), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('remains usable on a narrow surface with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final owned = await createReview();

    await tester.pumpWidget(
      _app(review: owned.review, textScale: 2, width: 280),
    );

    expect(find.text(_copy.confirmAction), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('system-intent-review-card')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
