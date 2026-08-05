
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/focus_profile_service.dart';
import 'services/iap_service.dart';
import 'services/journal_service.dart';
import 'services/notification_service.dart';
import 'services/timer_service.dart';
import 'services/theme_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/timer_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notificationService = NotificationService();
  await notificationService.initialize();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final preferences = await SharedPreferences.getInstance();
  final showOnboarding = !(preferences.getBool('hasCompletedOnboarding') ?? false);
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
    final activeNotificationService = notificationService ?? NotificationService();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => TimerService(notificationService: activeNotificationService),
        ),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => FocusProfileService()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => JournalService()),
        Provider(create: (_) => IAPService()),
        Provider(create: (_) => CloudSyncService()),
        Provider.value(value: activeNotificationService),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, _) {
          final selectedTheme = themeService.selectedTheme;
          return MaterialApp(
            title: 'FocusHaven',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
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
        },
      ),
    );
  }
}
