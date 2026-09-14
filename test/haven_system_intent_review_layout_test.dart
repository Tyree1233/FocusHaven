import 'dart:ui' show SemanticsAction;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focushaven/l10n/app_localizations.dart';
import 'package:focushaven/main.dart';
import 'package:focushaven/models/haven_system_intent.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/focus_queue_service.dart';
import 'package:focushaven/services/timer_service.dart';
import 'package:focushaven/widgets/haven_system_intent_production_host.dart';

final _card = find.byKey(const ValueKey<String>('system-intent-review-card'));
final _confirm = find.byKey(
  const ValueKey<String>('system-intent-confirm-review'),
);
final _dismiss = find.byKey(
  const ValueKey<String>('system-intent-dismiss-review'),
);
final _bodyScroll = find.byKey(
  const ValueKey<String>('system-intent-review-body-scroll'),
);
final _fullScroll = find.byKey(
  const ValueKey<String>('system-intent-review-full-scroll'),
);

final class _Fixture {
  _Fixture(this.timer, this.queue, this.backgroundFocus, this.locale);
  final TimerService timer;
  final FocusQueueService queue;
  final FocusNode backgroundFocus;
  final Locale locale;
  int backgroundTaps = 0;
  AppLocalizations get l10n => lookupAppLocalizations(locale);
}

Future<void> _withReview(
  WidgetTester tester,
  Future<void> Function(_Fixture fixture) check, {
  Locale locale = const Locale('en'),
  Size physicalSize = const Size(720, 1600),
  double pixelRatio = 2.625,
  double textScale = 1,
  bool onboarding = false,
  HavenSystemIntentKind kind = HavenSystemIntentKind.readTimerStatus,
}) async {
  SharedPreferences.setMockInitialValues({});
  final previousPlatform = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = pixelRatio;
  tester.view.padding = FakeViewPadding(
    top: 24 * pixelRatio,
    bottom: 24 * pixelRatio,
  );
  tester.view.viewPadding = FakeViewPadding(
    top: 24 * pixelRatio,
    bottom: 24 * pixelRatio,
  );
  final semantics = tester.ensureSemantics();
  const channel = MethodChannel('com.focushaven/system_assistant_android');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    channel,
    (_) async => false,
  );
  final timer = TimerService();
  final queue = FocusQueueService();
  final focus = FocusNode();
  final fixture = _Fixture(timer, queue, focus, locale);
  try {
    await Future.wait([timer.initialized, queue.initialized]);
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      onboarding
          ? FocusHavenApp(
              timerService: timer,
              focusQueueService: queue,
              showOnboarding: true,
              locale: locale,
            )
          : ProviderScope(
              overrides: [
                timerServiceProvider.overrideWith((ref) => timer),
                focusQueueServiceProvider.overrideWith((ref) => queue),
              ],
              child: MaterialApp(
                navigatorKey: navigatorKey,
                locale: locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: ThemeData.dark(useMaterial3: true),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: HavenSystemIntentProductionHost(
                    navigatorKey: navigatorKey,
                    child: child!,
                  ),
                ),
                home: Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: TextButton(
                      key: const ValueKey<String>('covered-route-action'),
                      focusNode: focus,
                      onPressed: () => fixture.backgroundTaps += 1,
                      child: const Text('Covered route action'),
                    ),
                  ),
                ),
              ),
            ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HavenSystemIntentProductionHost)),
      listen: false,
    );
    expect(
      container
          .read(havenSystemIntentInboxProvider)
          .submit(
            HavenSystemIntentRequest(
              schemaVersion: 1,
              invocationId: 'review-layout-fixture',
              kind: kind,
            ),
          ),
      isTrue,
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(_card, findsOneWidget);
    expect(timer.isRunning, isFalse);
    expect(queue.items, isEmpty);
    await check(fixture);
    expect(tester.takeException(), isNull);
  } finally {
    try {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    } finally {
      // Unmounting ProviderScope disposes its overridden ChangeNotifiers.
      focus.dispose();
      semantics.dispose();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  }
}

void _expectChoicesInsideSafeArea(WidgetTester tester) {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final safe = Rect.fromLTRB(0, 24, size.width, size.height - 24);
  for (final choice in [_dismiss, _confirm]) {
    final rect = tester.getRect(choice);
    expect(safe.contains(rect.topLeft), isTrue);
    expect(safe.contains(rect.bottomRight - const Offset(0.01, 0.01)), isTrue);
    expect(choice.hitTestable(), findsOneWidget);
  }
}

void main() {
  testWidgets('opaque review and both choices fit the saved phone viewport', (
    tester,
  ) async {
    await _withReview(tester, (fixture) async {
      expect(find.text('Welcome to FocusHaven'), findsOneWidget);
      expect(tester.widget<Material>(_card).color!.a, 1);
      expect(_bodyScroll, findsOneWidget);
      expect(_fullScroll, findsNothing);
      _expectChoicesInsideSafeArea(tester);
      final before = tester.getRect(_confirm);
      await tester.drag(_bodyScroll, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.getRect(_confirm), before);
      expect(fixture.timer.isRunning, isFalse);
    }, onboarding: true);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('choices remain reachable in ${locale.toLanguageTag()}', (
      tester,
    ) async {
      await _withReview(
        tester,
        (fixture) async {
          _expectChoicesInsideSafeArea(tester);
          for (final copy in [
            fixture.l10n.systemAssistantReviewSource,
            fixture.l10n.systemAssistantReviewPrivacy,
            fixture.l10n.systemAssistantReviewFreshness,
            fixture.l10n.systemAssistantReviewConfirmation,
          ]) {
            final line = find.text(copy);
            expect(line, findsOneWidget);
            await tester.ensureVisible(line);
            await tester.pumpAndSettle();
            final viewport = tester.getRect(_bodyScroll);
            expect(viewport.overlaps(tester.getRect(line)), isTrue);
            _expectChoicesInsideSafeArea(tester);
          }
          expect(fixture.timer.isRunning, isFalse);
        },
        locale: locale,
        textScale: 2,
      );
    });
  }

  testWidgets('compact landscape can scroll to both complete choices', (
    tester,
  ) async {
    await _withReview(
      tester,
      (fixture) async {
        expect(_fullScroll, findsOneWidget);
        for (final choice in [_dismiss, _confirm]) {
          await tester.ensureVisible(choice);
          await tester.pumpAndSettle();
          expect(choice.hitTestable(), findsOneWidget);
        }
        expect(fixture.timer.isRunning, isFalse);
      },
      physicalSize: const Size(640, 320),
      pixelRatio: 1,
    );
  });

  testWidgets('very large text scrolls without reducing the text scale', (
    tester,
  ) async {
    await _withReview(
      tester,
      (fixture) async {
        expect(_fullScroll, findsOneWidget);
        expect(MediaQuery.textScalerOf(tester.element(_card)).scale(14), 42);
        await tester.ensureVisible(_confirm);
        await tester.pumpAndSettle();
        expect(_confirm.hitTestable(), findsOneWidget);
        expect(fixture.timer.isRunning, isFalse);
      },
      physicalSize: const Size(320, 900),
      pixelRatio: 1,
      textScale: 3,
    );
  });

  testWidgets('covered route is inert until explicit dismissal', (
    tester,
  ) async {
    await _withReview(
      tester,
      (fixture) async {
        final background = find.byKey(
          const ValueKey<String>('covered-route-action'),
        );
        expect(
          find.semantics.byLabel('Covered route action').evaluate(),
          isEmpty,
        );
        expect(fixture.backgroundFocus.canRequestFocus, isFalse);
        await tester.tap(background, warnIfMissed: false);
        await tester.tapAt(const Offset(4, 400));
        await tester.pump();
        expect(fixture.backgroundTaps, 0);
        expect(_card, findsOneWidget);
        await tester.tap(_dismiss);
        await tester.pumpAndSettle();
        expect(_card, findsNothing);
        expect(fixture.timer.isRunning, isFalse);
        expect(fixture.backgroundFocus.canRequestFocus, isTrue);
        expect(
          find.semantics.byLabel('Covered route action').evaluate(),
          hasLength(1),
        );
        await tester.tap(background);
        expect(fixture.backgroundTaps, 1);
      },
      physicalSize: const Size(900, 700),
      pixelRatio: 1,
    );
  });

  testWidgets('accessible choices retain the existing one-shot action', (
    tester,
  ) async {
    await _withReview(tester, (fixture) async {
      final confirm = find.bySemanticsLabel(
        fixture.l10n.systemAssistantReviewConfirm,
      );
      final dismiss = find.bySemanticsLabel(
        fixture.l10n.systemAssistantReviewDismiss,
      );
      expect(
        tester
            .getSemantics(confirm)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      expect(
        tester
            .getSemantics(dismiss)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      final properties = tester.widget<Semantics>(confirm).properties;
      properties.onTap!();
      properties.onTap!();
      await tester.pumpAndSettle();
      expect(fixture.timer.isRunning, isTrue);
      expect(_card, findsNothing);
      expect(fixture.queue.items, isEmpty);
    }, kind: HavenSystemIntentKind.startFocusTimer);
  });
}
