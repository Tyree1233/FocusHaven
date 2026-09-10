import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focushaven/l10n/app_localizations.dart';
import 'package:focushaven/models/haven_system_intent.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/focus_queue_service.dart';
import 'package:focushaven/services/haven_system_intent_inbox.dart';
import 'package:focushaven/services/timer_service.dart';
import 'package:focushaven/widgets/haven_system_intent_production_host.dart';

final class _Fixture {
  _Fixture({required this.timer, required this.queue, required this.key});

  final TimerService timer;
  final FocusQueueService queue;
  final GlobalKey<NavigatorState> key;
}

Future<_Fixture> _pumpApp(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  final timer = TimerService();
  final queue = FocusQueueService();
  await Future.wait([timer.initialized, queue.initialized]);
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        timerServiceProvider.overrideWith((ref) => timer),
        focusQueueServiceProvider.overrideWith((ref) => queue),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: HavenSystemIntentProductionHost(
            navigatorKey: navigatorKey,
            child: child!,
          ),
        ),
        home: const Scaffold(body: Center(child: Text('Current route'))),
      ),
    ),
  );
  return _Fixture(timer: timer, queue: queue, key: navigatorKey);
}

HavenSystemIntentInbox _inbox(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(HavenSystemIntentProductionHost)),
    listen: false,
  );
  return container.read(havenSystemIntentInboxProvider);
}

HavenSystemIntentRequest _request(
  HavenSystemIntentKind kind,
  String invocationId,
) => HavenSystemIntentRequest(
  schemaVersion: 1,
  invocationId: invocationId,
  kind: kind,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('inbox is memory-only and rejects a second pending request', () {
    final inbox = HavenSystemIntentInbox();
    addTearDown(inbox.dispose);

    expect(
      inbox.submit(_request(HavenSystemIntentKind.readTimerStatus, 'first')),
      isTrue,
    );
    expect(
      inbox.submit(_request(HavenSystemIntentKind.pauseTimer, 'second')),
      isFalse,
    );
    expect(inbox.takePendingRequest()!.invocationId, 'first');
    expect(inbox.takePendingRequest(), isNull);
  });

  testWidgets('shows complete localized copy above the current route', (
    tester,
  ) async {
    final owned = await _pumpApp(tester, locale: const Locale('de'));
    expect(
      _inbox(tester).submit(
        _request(HavenSystemIntentKind.startFocusTimer, 'localized-start'),
      ),
      isTrue,
    );
    await tester.pump();
    await tester.pump();

    final l10n = lookupAppLocalizations(const Locale('de'));
    expect(find.text('Current route'), findsOneWidget);
    expect(find.text(l10n.systemAssistantReviewEyebrow), findsOneWidget);
    expect(find.text(l10n.systemAssistantReviewTitle), findsOneWidget);
    expect(find.text(l10n.systemAssistantReviewSource), findsOneWidget);
    expect(find.text(l10n.systemAssistantReviewPrivacy), findsOneWidget);
    expect(find.text(l10n.systemAssistantReviewFreshness), findsOneWidget);
    expect(find.text(l10n.systemAssistantReviewConfirmation), findsOneWidget);
    expect(find.text(l10n.systemAssistantReviewConfirm), findsOneWidget);
    expect(owned.timer.isRunning, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explicit confirm executes once through the existing owner', (
    tester,
  ) async {
    final owned = await _pumpApp(tester);
    _inbox(tester).submit(
      _request(HavenSystemIntentKind.startFocusTimer, 'confirmed-start'),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey<String>('system-intent-confirm-review')),
    );
    await tester.pump();

    expect(owned.timer.isRunning, isTrue);
    expect(
      find.byKey(const ValueKey<String>('system-intent-review-card')),
      findsNothing,
    );
  });

  testWidgets('dismiss consumes the review without changing owner state', (
    tester,
  ) async {
    final owned = await _pumpApp(tester);
    _inbox(tester).submit(
      _request(HavenSystemIntentKind.startFocusTimer, 'dismissed-start'),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey<String>('system-intent-dismiss-review')),
    );
    await tester.pump();

    expect(owned.timer.isRunning, isFalse);
    expect(
      find.byKey(const ValueKey<String>('system-intent-review-card')),
      findsNothing,
    );
  });

  testWidgets('owner change removes a stale review before confirmation', (
    tester,
  ) async {
    final owned = await _pumpApp(tester);
    _inbox(
      tester,
    ).submit(_request(HavenSystemIntentKind.startFocusTimer, 'stale-start'));
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('system-intent-review-card')),
      findsOneWidget,
    );

    owned.timer.selectSession(SessionType.shortBreak);
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('system-intent-review-card')),
      findsNothing,
    );
    expect(owned.timer.isRunning, isFalse);
  });

  testWidgets('malformed input fails closed without a visible review', (
    tester,
  ) async {
    await _pumpApp(tester);
    _inbox(tester).submit(
      const HavenSystemIntentRequest(
        schemaVersion: 2,
        invocationId: 'unsupported-schema',
        kind: HavenSystemIntentKind.readTimerStatus,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('system-intent-review-card')),
      findsNothing,
    );
  });

  testWidgets('review remains usable with large text on a narrow route', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await _pumpApp(tester, textScale: 2);
    _inbox(tester).submit(
      _request(HavenSystemIntentKind.readTimerStatus, 'large-text-status'),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('system-intent-review-card')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  test('all runtime locales expose complete generated review copy', () {
    expect(AppLocalizations.supportedLocales, hasLength(17));
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      final messages = <String>[
        l10n.systemAssistantReviewEyebrow,
        l10n.systemAssistantReviewTitle,
        l10n.systemAssistantReviewSource,
        l10n.systemAssistantReviewPrivacy,
        l10n.systemAssistantReviewFreshness,
        l10n.systemAssistantReviewConfirmation,
        l10n.systemAssistantReviewInformationalRisk,
        l10n.systemAssistantReviewReversibleRisk,
        l10n.systemAssistantReviewSummary(
          'Fixture interpretation',
          'Fixture effect',
          'Fixture risk',
        ),
        l10n.systemAssistantReviewDismiss,
        l10n.systemAssistantReviewConfirm,
      ];
      expect(messages, hasLength(11), reason: locale.toLanguageTag());
      for (final message in messages) {
        expect(message.trim(), isNotEmpty, reason: locale.toLanguageTag());
        expect(message, isNot(contains(RegExp(r'\{[^}]+\}'))));
      }
    }
  });
}
