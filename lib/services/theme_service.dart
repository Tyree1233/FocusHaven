import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FocusHavenTheme { twilight, calmBlue, minimalist }

extension FocusHavenThemeDetails on FocusHavenTheme {
  String get label => switch (this) {
        FocusHavenTheme.twilight => 'Twilight',
        FocusHavenTheme.calmBlue => 'Calm Blue',
        FocusHavenTheme.minimalist => 'Minimalist',
      };

  Color get primary => switch (this) {
        FocusHavenTheme.twilight => const Color(0xFFF16FBA),
        FocusHavenTheme.calmBlue => const Color(0xFF7BDEED),
        FocusHavenTheme.minimalist => const Color(0xFF9FE3C1),
      };

  Color get background => switch (this) {
        FocusHavenTheme.twilight => const Color(0xFF211442),
        FocusHavenTheme.calmBlue => const Color(0xFF10273B),
        FocusHavenTheme.minimalist => const Color(0xFF1E2828),
      };

  Color get surface => switch (this) {
        FocusHavenTheme.twilight => const Color(0xFF352260),
        FocusHavenTheme.calmBlue => const Color(0xFF193E5B),
        FocusHavenTheme.minimalist => const Color(0xFF2A3837),
      };

  Color get shortBreak => switch (this) {
        FocusHavenTheme.twilight => const Color(0xFF72E0B8),
        FocusHavenTheme.calmBlue => const Color(0xFF87E6B1),
        FocusHavenTheme.minimalist => const Color(0xFFB7D98C),
      };

  Color get longBreak => switch (this) {
        FocusHavenTheme.twilight => const Color(0xFF9B82FF),
        FocusHavenTheme.calmBlue => const Color(0xFF9EB8FF),
        FocusHavenTheme.minimalist => const Color(0xFFC4B5FD),
      };
}

class ThemeService extends ChangeNotifier {
  static const _storageKey = 'focusHavenTheme';
  FocusHavenTheme _selectedTheme = FocusHavenTheme.twilight;

  FocusHavenTheme get selectedTheme => _selectedTheme;

  ThemeService() {
    _load();
  }

  Future<void> setTheme(FocusHavenTheme theme) async {
    _selectedTheme = theme;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, theme.name);
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final savedTheme = preferences.getString(_storageKey);
    for (final theme in FocusHavenTheme.values) {
      if (theme.name == savedTheme) {
        _selectedTheme = theme;
        break;
      }
    }
    notifyListeners();
  }
}
