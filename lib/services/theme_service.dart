import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FocusHavenTheme {
  twilight,
  calmBlue,
  minimalist,
  sunset,
  forest,
  roseQuartz,
}

extension FocusHavenThemeDetails on FocusHavenTheme {
  String get label => switch (this) {
    FocusHavenTheme.twilight => 'Twilight',
    FocusHavenTheme.calmBlue => 'Calm Blue',
    FocusHavenTheme.minimalist => 'Minimalist',
    FocusHavenTheme.sunset => 'Sunset',
    FocusHavenTheme.forest => 'Forest',
    FocusHavenTheme.roseQuartz => 'Rose Quartz',
  };

  Color get primary => switch (this) {
    FocusHavenTheme.twilight => const Color(0xFFF16FBA),
    FocusHavenTheme.calmBlue => const Color(0xFF7BDEED),
    FocusHavenTheme.minimalist => const Color(0xFF9FE3C1),
    FocusHavenTheme.sunset => const Color(0xFFFFB36B),
    FocusHavenTheme.forest => const Color(0xFF82D6A0),
    FocusHavenTheme.roseQuartz => const Color(0xFFF5A7C7),
  };

  Color get background => switch (this) {
    FocusHavenTheme.twilight => const Color(0xFF211442),
    FocusHavenTheme.calmBlue => const Color(0xFF10273B),
    FocusHavenTheme.minimalist => const Color(0xFF1E2828),
    FocusHavenTheme.sunset => const Color(0xFF3B1E1D),
    FocusHavenTheme.forest => const Color(0xFF173229),
    FocusHavenTheme.roseQuartz => const Color(0xFF37232F),
  };

  Color get surface => switch (this) {
    FocusHavenTheme.twilight => const Color(0xFF352260),
    FocusHavenTheme.calmBlue => const Color(0xFF193E5B),
    FocusHavenTheme.minimalist => const Color(0xFF2A3837),
    FocusHavenTheme.sunset => const Color(0xFF5A2A25),
    FocusHavenTheme.forest => const Color(0xFF24513F),
    FocusHavenTheme.roseQuartz => const Color(0xFF543747),
  };

  Color get shortBreak => switch (this) {
    FocusHavenTheme.twilight => const Color(0xFFF58FC0),
    FocusHavenTheme.calmBlue => const Color(0xFF6FE6D0),
    FocusHavenTheme.minimalist => const Color(0xFF7DCEAA),
    FocusHavenTheme.sunset => const Color(0xFFFFD27D),
    FocusHavenTheme.forest => const Color(0xFFB5E6A2),
    FocusHavenTheme.roseQuartz => const Color(0xFFF6B99A),
  };

  Color get longBreak => switch (this) {
    FocusHavenTheme.twilight => const Color(0xFFC58BFF),
    FocusHavenTheme.calmBlue => const Color(0xFF86B9F4),
    FocusHavenTheme.minimalist => const Color(0xFFB9D69A),
    FocusHavenTheme.sunset => const Color(0xFFFF9D9D),
    FocusHavenTheme.forest => const Color(0xFF77C8C1),
    FocusHavenTheme.roseQuartz => const Color(0xFFD6B6E8),
  };
}

class ThemeService extends ChangeNotifier {
  static const _storageKey = 'focusHavenTheme';
  FocusHavenTheme _selectedTheme = FocusHavenTheme.twilight;
  bool _isDisposed = false;

  ThemeService() {
    initialized = _load();
  }

  late final Future<void> initialized;

  FocusHavenTheme get selectedTheme => _selectedTheme;

  Future<void> setTheme(FocusHavenTheme theme) async {
    await initialized;
    if (_isDisposed || _selectedTheme == theme) return;

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, theme.name);
    if (_isDisposed) return;

    _selectedTheme = theme;
    notifyListeners();
  }

  Future<void> clearLocalData() async {
    await initialized;
    if (_isDisposed) return;

    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
    if (_isDisposed) return;

    final changed = _selectedTheme != FocusHavenTheme.twilight;
    _selectedTheme = FocusHavenTheme.twilight;
    if (changed) notifyListeners();
  }

  Future<void> _load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (_isDisposed) return;

      final savedTheme = preferences.getString(_storageKey);
      FocusHavenTheme? selectedTheme;
      for (final theme in FocusHavenTheme.values) {
        if (theme.name == savedTheme) {
          selectedTheme = theme;
          break;
        }
      }
      if (selectedTheme != null) {
        _selectedTheme = selectedTheme;
      } else if (savedTheme != null) {
        await preferences.remove(_storageKey);
      }
    } catch (error) {
      debugPrint('Appearance preference could not be loaded: $error');
    }
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
