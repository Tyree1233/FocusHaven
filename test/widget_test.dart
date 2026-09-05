import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focushaven/main.dart';
import 'package:focushaven/l10n/app_localizations.dart';
import 'package:focushaven/l10n/focus_haven_locales.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/screens/onboarding_screen.dart';
import 'package:focushaven/services/auth_service.dart';
import 'package:focushaven/services/focus_profile_service.dart';
import 'package:focushaven/services/focus_queue_service.dart';
import 'package:focushaven/services/journal_service.dart';
import 'package:focushaven/services/locale_service.dart';
import 'package:focushaven/services/notification_service.dart';
import 'package:focushaven/services/reminder_service.dart';
import 'package:focushaven/services/theme_service.dart';
import 'package:focushaven/services/timer_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the FocusHaven welcome screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const FocusHavenApp());

    expect(find.text('Welcome to FocusHaven'), findsOneWidget);
    expect(
      find.text('A calm place to focus, recharge, and stay mindful.'),
      findsOneWidget,
    );
    expect(find.text('Begin focus'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('exposes every production-approved locale', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const FocusHavenApp());

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.supportedLocales, FocusHavenLocales.productionLocales);
    expect(materialApp.supportedLocales, const <Locale>[
      Locale('en'),
      Locale('es'),
      Locale('fr'),
      Locale('de'),
      Locale('pt', 'BR'),
    ]);
    expect(
      AppLocalizations.supportedLocales,
      containsAll(const <Locale>[
        Locale('en'),
        Locale('es'),
        Locale('fr'),
        Locale('de'),
        Locale('pt'),
        Locale('pt', 'BR'),
      ]),
    );
    expect(
      materialApp.supportedLocales,
      everyElement(isIn(AppLocalizations.supportedLocales)),
    );
    expect(
      materialApp.localizationsDelegates,
      contains(AppLocalizations.delegate),
    );

    final appContext = tester.element(find.byType(OnboardingScreen));
    expect(materialApp.onGenerateTitle!(appContext), 'FocusHaven');
    expect(tester.takeException(), isNull);
  });

  testWidgets('begin focus saves onboarding and replaces the welcome route', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        initialRoute: '/',
        routes: {
          '/': (_) => const OnboardingScreen(),
          '/timer': (_) =>
              const Scaffold(body: Center(child: Text('Timer destination'))),
        },
      ),
    );

    await tester.tap(find.text('Begin focus'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('hasCompletedOnboarding'), isTrue);
    expect(find.text('Welcome to FocusHaven'), findsNothing);
    expect(find.text('Timer destination'), findsOneWidget);
  });

  testWidgets('restores French and falls back to English when unsupported', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({LocaleService.storageKey: 'fr'});
    final localeService = LocaleService();
    await localeService.initialized;

    await tester.pumpWidget(FocusHavenApp(localeService: localeService));
    await tester.pump();
    expect(find.text('Bienvenue à FocusHaven'), findsOneWidget);

    await localeService.setLanguage(FocusHavenLanguageChoice.system);
    tester.platformDispatcher.localeTestValue = const Locale('ja');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    await tester.pumpAndSettle();

    expect(find.text('Welcome to FocusHaven'), findsOneWidget);
    expect(find.text('Bienvenue à FocusHaven'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the pre-initialized timer supplied at app startup', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'focusSeconds': 90,
      'totalSessionSeconds': 90,
      'secondsRemaining': 90,
    });
    final timer = TimerService();
    await timer.initialized;

    await tester.pumpWidget(
      FocusHavenApp(timerService: timer, showOnboarding: false),
    );
    await tester.pump();

    expect(find.text('01:30'), findsOneWidget);
    expect(find.text('Begin focus'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'uses pre-initialized theme and focus profile supplied at app startup',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'focusHavenTheme': FocusHavenTheme.forest.name,
        'focusProfile': '  Deep Diver  ',
      });
      final themeService = ThemeService();
      final focusProfileService = FocusProfileService();
      await Future.wait([
        themeService.initialized,
        focusProfileService.initialized,
      ]);

      await tester.pumpWidget(
        FocusHavenApp(
          themeService: themeService,
          focusProfileService: focusProfileService,
        ),
      );
      await tester.pump();

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(
        materialApp.theme?.scaffoldBackgroundColor,
        FocusHavenTheme.forest.background,
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      );
      expect(container.read(themeServiceProvider), same(themeService));
      expect(
        container.read(focusProfileServiceProvider),
        same(focusProfileService),
      );
      expect(container.read(selectedThemeProvider), FocusHavenTheme.forest);
      expect(container.read(focusProfileTypeProvider), 'Deep Diver');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('uses the pre-initialized journal supplied at app startup', (
    WidgetTester tester,
  ) async {
    final createdAt = DateTime(2026, 8, 8, 12);
    SharedPreferences.setMockInitialValues({
      'journalEntries': jsonEncode([
        {
          'createdAt': createdAt.toIso8601String(),
          'mood': 'Grateful',
          'reflection': 'This reflection is ready on the first frame.',
        },
      ]),
    });
    final journalService = JournalService();
    await journalService.initialized;

    await tester.pumpWidget(FocusHavenApp(journalService: journalService));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
    expect(container.read(journalServiceProvider), same(journalService));

    final journalState = container.read(journalStateProvider);
    expect(journalState.entries, hasLength(1));
    expect(journalState.entries.single.createdAt, createdAt);
    expect(journalState.entries.single.mood, 'Grateful');
    expect(
      journalState.entries.single.reflection,
      'This reflection is ready on the first frame.',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the pre-initialized queue supplied at app startup', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'focusQueue': jsonEncode([
        {
          'id': 'startup-task',
          'title': 'Ready on the first frame',
          'isComplete': false,
        },
      ]),
    });
    final focusQueueService = FocusQueueService();
    await focusQueueService.initialized;

    await tester.pumpWidget(
      FocusHavenApp(focusQueueService: focusQueueService),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
    expect(container.read(focusQueueServiceProvider), same(focusQueueService));

    final queueState = container.read(focusQueueStateProvider);
    expect(queueState.activeItems, hasLength(1));
    expect(queueState.activeItems.single.id, 'startup-task');
    expect(queueState.activeItems.single.title, 'Ready on the first frame');
    expect(queueState.completedItems, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the pre-initialized reminder supplied at app startup', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'dailyReminderEnabled': true,
      'dailyReminderHour': 18,
      'dailyReminderMinute': 30,
      'dailyReminderWeekdays': ['1', '3', '5'],
    });
    final reminderService = ReminderService(
      notificationService: NotificationService(),
    );
    await reminderService.initialized;

    await tester.pumpWidget(FocusHavenApp(reminderService: reminderService));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
    expect(container.read(reminderServiceProvider), same(reminderService));

    final reminderState = container.read(reminderStateProvider);
    expect(reminderState.isEnabled, isTrue);
    expect(reminderState.time, const TimeOfDay(hour: 18, minute: 30));
    expect(reminderState.weekdays, {1, 3, 5});
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the pre-initialized auth supplied at app startup', (
    WidgetTester tester,
  ) async {
    final authService = AuthService();
    await authService.initialized;

    await tester.pumpWidget(FocusHavenApp(authService: authService));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
    expect(container.read(authServiceProvider), same(authService));

    final authState = container.read(authStateProvider);
    expect(authState.isSignedIn, isFalse);
    expect(authState.displayName, 'Guest');
    expect(authState.signInError, isNull);
    expect(tester.takeException(), isNull);
  });
}
