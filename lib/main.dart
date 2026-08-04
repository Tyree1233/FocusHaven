
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'onboarding_screen.dart';
import 'timer_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // The timer remains available until Firebase is configured for a release.
  }
  runApp(const FocusHavenApp());
}

class FocusHavenApp extends StatelessWidget {
  const FocusHavenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
        '/': (context) => OnboardingScreen(),
        '/timer': (context) => TimerScreen(),
      },
    );
  }
}
