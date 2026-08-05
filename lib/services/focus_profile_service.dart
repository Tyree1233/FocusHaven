import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FocusProfileService extends ChangeNotifier {
  static const _profileKey = 'focusProfile';
  String? _focusType;

  String? get focusType => _focusType;

  FocusProfileService() {
    _load();
  }

  Future<void> saveFocusType(String focusType) async {
    _focusType = focusType;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_profileKey, focusType);
    notifyListeners();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    _focusType = preferences.getString(_profileKey);
    notifyListeners();
  }
}
