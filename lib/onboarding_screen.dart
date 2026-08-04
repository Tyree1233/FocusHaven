
import 'package:flutter/material.dart';
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  void _navigateToTimer(BuildContext context) {
    Navigator.of(context).pushReplacementNamed('/timer');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Image.asset('assets/focushaven-logo.png', width: 160, height: 160),
              ),
              const SizedBox(height: 36),
              const Text('Welcome to FocusHaven', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('A calm place to focus, recharge, and stay mindful.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white70)),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => _navigateToTimer(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF16FBA),
                  foregroundColor: const Color(0xFF28133F),
                  minimumSize: const Size.fromHeight(56),
                ),
                child: const Text('Begin focus'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
