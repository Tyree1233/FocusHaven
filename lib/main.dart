
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/iap_service.dart';
import 'services/notification_service.dart';
import 'services/timer_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/timer_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notificationService = NotificationService();
  await notificationService.initialize();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const FocusHavenApp());
}

class FocusHavenApp extends StatelessWidget {
  const FocusHavenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => TimerService(notificationService: notificationService),
        ),
        ChangeNotifierProvider(create: (_) => AuthService()),
        Provider(create: (_) => IAPService()),
        Provider(create: (_) => CloudSyncService()),
        Provider.value(value: notificationService),
      ],
      child: MaterialApp(
        title: 'FocusHaven',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFF16FBA),
            brightness: Brightness.dark,
            surface: const Color(0xFF352260),
          ),
          scaffoldBackgroundColor: const Color(0xFF211442),
          useMaterial3: true,
        ),
        initialRoute: '/',
        routes: {
          '/': (_) => const OnboardingScreen(),
          '/timer': (_) => const TimerScreen(),
        },
      ),
    );
  }
}
