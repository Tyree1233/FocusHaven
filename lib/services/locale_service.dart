import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/focus_haven_locales.dart';

enum FocusHavenLanguageChoice { system, english, spanish }

extension FocusHavenLanguageChoiceLocale on FocusHavenLanguageChoice {
  Locale? get locale => switch (this) {
    FocusHavenLanguageChoice.system => null,
    FocusHavenLanguageChoice.english => const Locale('en'),
    FocusHavenLanguageChoice.spanish => const Locale('es'),
  };
}

/// Owns the person's local, reversible language preference.
///
/// A missing preference follows the device language. Unsupported device
/// languages fall back to English because English is first in the production
/// locale list. The preference is local-only and is never included in cloud
/// backup data.
class LocaleService extends ChangeNotifier {
  static const storageKey = 'focusHavenLanguage';

  FocusHavenLanguageChoice _selectedChoice = FocusHavenLanguageChoice.system;
  bool _isDisposed = false;

  LocaleService() {
    initialized = _load();
  }

  late final Future<void> initialized;

  FocusHavenLanguageChoice get selectedChoice => _selectedChoice;

  Locale? get selectedLocale => _selectedChoice.locale;

  Future<void> setLanguage(FocusHavenLanguageChoice choice) async {
    await initialized;
    if (_isDisposed || _selectedChoice == choice) return;

    final locale = choice.locale;
    if (locale != null &&
        !FocusHavenLocales.productionLocales.contains(locale)) {
      throw ArgumentError.value(choice, 'choice', 'Unsupported language');
    }

    final preferences = await SharedPreferences.getInstance();
    if (choice == FocusHavenLanguageChoice.system) {
      await preferences.remove(storageKey);
    } else {
      await preferences.setString(storageKey, locale!.languageCode);
    }
    if (_isDisposed) return;

    _selectedChoice = choice;
    notifyListeners();
  }

  Future<void> clearLocalData() async {
    await initialized;
    if (_isDisposed) return;

    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(storageKey);
    if (_isDisposed) return;

    final changed = _selectedChoice != FocusHavenLanguageChoice.system;
    _selectedChoice = FocusHavenLanguageChoice.system;
    if (changed) notifyListeners();
  }

  Future<void> _load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (_isDisposed) return;

      final savedValue = preferences.get(storageKey);
      final savedLanguage = savedValue is String ? savedValue : null;
      final choice = switch (savedLanguage) {
        'en' => FocusHavenLanguageChoice.english,
        'es' => FocusHavenLanguageChoice.spanish,
        _ => FocusHavenLanguageChoice.system,
      };
      if (savedValue != null && choice == FocusHavenLanguageChoice.system) {
        await preferences.remove(storageKey);
      }
      _selectedChoice = choice;
    } catch (_) {
      _selectedChoice = FocusHavenLanguageChoice.system;
    }
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
