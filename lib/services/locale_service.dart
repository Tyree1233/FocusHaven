import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/focus_haven_locales.dart';

@immutable
class FocusHavenLanguageChoice {
  const FocusHavenLanguageChoice._(this.languageTag);

  static const system = FocusHavenLanguageChoice._(null);
  static const english = FocusHavenLanguageChoice._('en');
  static const spanish = FocusHavenLanguageChoice._('es');

  factory FocusHavenLanguageChoice.forDefinition(
    FocusHavenLocaleDefinition definition,
  ) => FocusHavenLanguageChoice._(definition.languageTag);

  final String? languageTag;

  Locale? get locale {
    final tag = languageTag;
    if (tag == null) return null;
    return FocusHavenLocales.productionDefinitionForTag(tag)?.locale;
  }

  @override
  bool operator ==(Object other) =>
      other is FocusHavenLanguageChoice && other.languageTag == languageTag;

  @override
  int get hashCode => languageTag.hashCode;
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

  List<FocusHavenLanguageChoice> get availableChoices => [
    FocusHavenLanguageChoice.system,
    ...FocusHavenLocales.production.map(FocusHavenLanguageChoice.forDefinition),
  ];

  Future<void> setLanguage(FocusHavenLanguageChoice choice) async {
    await initialized;
    if (_isDisposed || _selectedChoice == choice) return;

    final tag = choice.languageTag;
    final locale = choice.locale;
    if (tag != null && locale == null) {
      throw ArgumentError.value(choice, 'choice', 'Unsupported language');
    }

    final preferences = await SharedPreferences.getInstance();
    if (choice == FocusHavenLanguageChoice.system) {
      await preferences.remove(storageKey);
    } else {
      await preferences.setString(storageKey, tag!);
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
      final definition = savedLanguage == null
          ? null
          : FocusHavenLocales.productionDefinitionForTag(savedLanguage);
      final choice = definition == null
          ? FocusHavenLanguageChoice.system
          : FocusHavenLanguageChoice.forDefinition(definition);
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
