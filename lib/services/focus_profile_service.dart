import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'privacy_safe_diagnostics.dart';

class FocusProfileService extends ChangeNotifier {
  static const _profileKey = 'focusProfile';
  static const _maximumFocusTypeLength = 80;

  String? _focusType;
  bool _isDisposed = false;

  FocusProfileService() {
    initialized = _load();
  }

  late final Future<void> initialized;

  String? get focusType => _focusType;

  Future<void> saveFocusType(String focusType) async {
    await initialized;
    if (_isDisposed) return;

    final normalizedFocusType = _normalizeFocusType(focusType);
    if (normalizedFocusType == null || _focusType == normalizedFocusType) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_profileKey, normalizedFocusType);
    if (_isDisposed) return;

    _focusType = normalizedFocusType;
    notifyListeners();
  }

  Future<void> clearLocalData() async {
    await initialized;
    if (_isDisposed) return;

    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_profileKey);
    if (_isDisposed) return;

    final changed = _focusType != null;
    _focusType = null;
    if (changed) notifyListeners();
  }

  Future<void> _load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (_isDisposed) return;

      final savedValue = preferences.get(_profileKey);
      if (savedValue != null && savedValue is! String) {
        await preferences.remove(_profileKey);
      } else {
        final savedFocusType = savedValue as String?;
        final normalizedFocusType = savedFocusType == null
            ? null
            : _normalizeFocusType(savedFocusType);
        if (normalizedFocusType == null) {
          if (savedFocusType != null) {
            await preferences.remove(_profileKey);
          }
        } else {
          _focusType = normalizedFocusType;
          if (normalizedFocusType != savedFocusType) {
            await preferences.setString(_profileKey, normalizedFocusType);
          }
        }
      }
    } catch (error) {
      PrivacySafeDiagnostics.report(
        FocusHavenDiagnosticEvent.focusProfileLoad,
        error: error,
      );
    }
    if (!_isDisposed) notifyListeners();
  }

  String? _normalizeFocusType(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.length > _maximumFocusTypeLength) {
      return null;
    }
    return normalized;
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
