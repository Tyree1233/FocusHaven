import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ConsumerWidget, ProviderScope, WidgetRef;

import 'firebase_options.dart';
import 'providers/app_providers.dart';
import 'screens/onboarding_screen.dart';
import 'screens/timer_screen.dart';
import 'services/app_check_service.dart';
import 'services/auth_service.dart';
import 'services/coaching_service.dart';
import 'services/focus_profile_service.dart';
import 'services/focus_queue_service.dart';
import 'services/journal_service.dart';
import 'services/notification_service.dart';
import 'services/remote_coaching_responder.dart';
import 'services/reminder_service.dart';
import 'services/theme_service.dart';
import 'services/timer_service.dart';
import 'widgets/focus_shield_platform_host.dart';
import 'widgets/haven_window_platform_host.dart';
import 'widgets/system_focus_platform_host.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final notificationService = NotificationService();
  await notificationService.initialize();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  var remoteCoachingReady = false;
  try {
    remoteCoachingReady = await initializeRemoteCoachingAppCheck();
  } catch (error) {
    debugPrint('Remote coaching App Check setup failed: $error');
  }

  final showOnboarding = await shouldShowOnboarding();
  final authService = AuthService();
  final coachingService = CoachingService(
    enhancedResponder: remoteCoachingReady
        ? createEnhancedCoachingResponder()
        : null,
  );
  final timerService = TimerService(notificationService: notificationService);
  final themeService = ThemeService();
  final focusProfileService = FocusProfileService();
  final focusQueueService = FocusQueueService();
  final journalService = JournalService();
  final reminderService = ReminderService(
    notificationService: notificationService,
  );
  await Future.wait([
    authService.initialized,
    coachingService.initialized,
    timerService.initialized,
    themeService.initialized,
    focusProfileService.initialized,
    focusQueueService.initialized,
    journalService.initialized,
    reminderService.initialized,
  ]);

  runApp(
    FocusHavenApp(
      authService: authService,
      coachingService: coachingService,
      notificationService: notificationService,
      timerService: timerService,
      themeService: themeService,
      focusProfileService: focusProfileService,
      focusQueueService: focusQueueService,
      journalService: journalService,
      reminderService: reminderService,
      showOnboarding: showOnboarding,
    ),
  );
}

class FocusHavenApp extends StatelessWidget {
  const FocusHavenApp({
    super.key,
    this.authService,
    this.coachingService,
    this.notificationService,
    this.timerService,
    this.themeService,
    this.focusProfileService,
    this.focusQueueService,
    this.journalService,
    this.reminderService,
    this.showOnboarding = true,
  });

  final AuthService? authService;
  final CoachingService? coachingService;
  final NotificationService? notificationService;
  final TimerService? timerService;
  final ThemeService? themeService;
  final FocusProfileService? focusProfileService;
  final FocusQueueService? focusQueueService;
  final JournalService? journalService;
  final ReminderService? reminderService;
  final bool showOnboarding;

  @override
  Widget build(BuildContext context) {
    final activeAuthService = authService;
    final activeCoachingService = coachingService;
    final activeNotificationService =
        notificationService ?? NotificationService();
    final activeTimerService = timerService;
    final activeThemeService = themeService;
    final activeFocusProfileService = focusProfileService;
    final activeFocusQueueService = focusQueueService;
    final activeJournalService = journalService;
    final activeReminderService = reminderService;

    return ProviderScope(
      overrides: [
        if (activeAuthService != null)
          authServiceProvider.overrideWith((ref) => activeAuthService),
        if (activeCoachingService != null)
          coachingServiceProvider.overrideWith((ref) => activeCoachingService),
        notificationServiceProvider.overrideWithValue(
          activeNotificationService,
        ),
        if (activeTimerService != null)
          timerServiceProvider.overrideWith((ref) => activeTimerService),
        if (activeThemeService != null)
          themeServiceProvider.overrideWith((ref) => activeThemeService),
        if (activeFocusProfileService != null)
          focusProfileServiceProvider.overrideWith(
            (ref) => activeFocusProfileService,
          ),
        if (activeFocusQueueService != null)
          focusQueueServiceProvider.overrideWith(
            (ref) => activeFocusQueueService,
          ),
        if (activeJournalService != null)
          journalServiceProvider.overrideWith((ref) => activeJournalService),
        if (activeReminderService != null)
          reminderServiceProvider.overrideWith((ref) => activeReminderService),
      ],
      child: HavenWindowPlatformHost(
        child: FocusShieldPlatformHost(
          child: SystemFocusPlatformHost(
            child: _FocusHavenMaterialApp(showOnboarding: showOnboarding),
          ),
        ),
      ),
    );
  }
}

/// Rebuilds only the application theme when the selected palette changes.
class _FocusHavenMaterialApp extends ConsumerWidget {
  const _FocusHavenMaterialApp({required this.showOnboarding});

  final bool showOnboarding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTheme = ref.watch(selectedThemeProvider);

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
