import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ConsumerWidget, ProviderScope, WidgetRef;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'providers/app_providers.dart';
import 'screens/onboarding_screen.dart';
import 'screens/timer_screen.dart';
import 'services/auth_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/focus_profile_service.dart';
import 'services/focus_queue_service.dart';
import 'services/iap_service.dart';
import 'services/journal_service.dart';
import 'services/notification_service.dart';
import 'services/reminder_service.dart';
import 'services/theme_service.dart';
import 'services/timer_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final notificationService = NotificationService();
  await notificationService.initialize();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final preferences = await SharedPreferences.getInstance();
  final showOnboarding =
      !(preferences.getBool('hasCompletedOnboarding') ?? false);

  runApp(
    FocusHavenApp(
      notificationService: notificationService,
      showOnboarding: showOnboarding,
    ),
  );
}

class FocusHavenApp extends StatelessWidget {
  const FocusHavenApp({
    super.key,
    this.notificationService,
    this.showOnboarding = true,
  });

  final NotificationService? notificationService;
  final bool showOnboarding;

  @override
  Widget build(BuildContext context) {
    final activeNotificationService =
        notificationService ?? NotificationService();

    return ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(
          activeNotificationService,
        ),
      ],
      child: _FocusHavenRoot(showOnboarding: showOnboarding),
    );
  }
}

/// Bridges Riverpod-owned services to the existing Provider-based views.
///
/// During migration, both APIs resolve the same instances. This prevents
/// duplicate timers, authentication sessions, and purchase listeners while
/// allowing each view to move to Riverpod independently.
class _FocusHavenRoot extends ConsumerWidget {
  const _FocusHavenRoot({required this.showOnboarding});

  final bool showOnboarding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TimerService>.value(
          value: ref.read(timerServiceProvider),
        ),
        ChangeNotifierProvider<AuthService>.value(
          value: ref.read(authServiceProvider),
        ),
        ChangeNotifierProvider<FocusProfileService>.value(
          value: ref.read(focusProfileServiceProvider),
        ),
        ChangeNotifierProvider<FocusQueueService>.value(
          value: ref.read(focusQueueServiceProvider),
        ),
        ChangeNotifierProvider<ThemeService>.value(
          value: ref.read(themeServiceProvider),
        ),
        ChangeNotifierProvider<JournalService>.value(
          value: ref.read(journalServiceProvider),
        ),
        ChangeNotifierProvider<ReminderService>.value(
          value: ref.read(reminderServiceProvider),
        ),
        Provider<IAPService>.value(value: ref.read(iapServiceProvider)),
        Provider<CloudSyncService>.value(
          value: ref.read(cloudSyncServiceProvider),
        ),
        Provider<NotificationService>.value(
          value: ref.read(notificationServiceProvider),
        ),
      ],
      child: _FocusHavenMaterialApp(showOnboarding: showOnboarding),
    );
  }
}

/// Rebuilds only the application theme when the selected palette changes.
class _FocusHavenMaterialApp extends ConsumerWidget {
  const _FocusHavenMaterialApp({required this.showOnboarding});

  final bool showOnboarding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTheme = ref.watch(themeServiceProvider).selectedTheme;

    return MaterialApp(
      title: 'FocusHaven',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: selectedTheme.primary,
              brightness: Brightness.dark,
            ).copyWith(
              primary: selectedTheme.primary,
              secondary: selectedTheme.shortBreak,
              tertiary: selectedTheme.longBreak,
              surface: selectedTheme.surface,
            ),
        scaffoldBackgroundColor: selectedTheme.background,
        appBarTheme: AppBarTheme(
          backgroundColor: selectedTheme.surface,
          foregroundColor: selectedTheme.primary,
        ),
        useMaterial3: true,
      ),
      initialRoute: showOnboarding ? '/' : '/timer',
      routes: {
        '/': (_) => const OnboardingScreen(),
        '/timer': (_) => const TimerScreen(),
      },
    );
  }
}
