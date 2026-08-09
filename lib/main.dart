import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ConsumerWidget, ProviderScope, WidgetRef;
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'providers/app_providers.dart';
import 'screens/onboarding_screen.dart';
import 'screens/timer_screen.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';

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
