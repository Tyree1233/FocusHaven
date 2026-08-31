import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/focus_haven_localizations.dart';

const onboardingCompletionPreferenceKey = 'hasCompletedOnboarding';

Future<bool> shouldShowOnboarding() async {
  final preferences = await SharedPreferences.getInstance();
  final savedCompletion = preferences.get(onboardingCompletionPreferenceKey);
  if (savedCompletion is bool) return !savedCompletion;
  if (savedCompletion != null) {
    await preferences.remove(onboardingCompletionPreferenceKey);
  }
  return true;
}

typedef OnboardingCompletionSaver = Future<bool> Function();

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({this.saveCompletion, super.key});

  final OnboardingCompletionSaver? saveCompletion;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isStarting = false;

  Future<bool> _saveCompletion() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.setBool(onboardingCompletionPreferenceKey, true);
  }

  Future<void> _beginFocus() async {
    if (_isStarting) return;
    setState(() => _isStarting = true);
    try {
      final saved = await (widget.saveCompletion ?? _saveCompletion)();
      if (!mounted) return;
      if (!saved) {
        _showMessage(context.l10n.onboardingSaveError);
        return;
      }
      Navigator.of(context).pushReplacementNamed('/timer');
    } catch (_) {
      if (!mounted) return;
      _showMessage(context.l10n.onboardingStartError);
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Image.asset(
                  'assets/focushaven-logo.png',
                  width: 160,
                  height: 160,
                ),
              ),
              const SizedBox(height: 36),
              Text(
                l10n.onboardingTitle,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.onboardingSubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isStarting ? null : _beginFocus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF16FBA),
                    foregroundColor: const Color(0xFF28133F),
                    minimumSize: const Size.fromHeight(56),
                  ),
                  child: Text(
                    _isStarting
                        ? l10n.onboardingOpening
                        : l10n.onboardingBeginFocus,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
