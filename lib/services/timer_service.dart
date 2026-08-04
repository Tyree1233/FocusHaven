import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TimerService extends ChangeNotifier {
  static const _defaultSeconds = 25 * 60;
  int _secondsRemaining = _defaultSeconds;
  Timer? _ticker;
  bool _isRunning = false;

  int get secondsRemaining => _secondsRemaining;
  bool get isRunning => _isRunning;

  TimerService() {
    _loadFromPrefs();
  }

  void start() {
    if (_isRunning || _secondsRemaining == 0) return;
    _isRunning = true;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsRemaining <= 1) {
        _secondsRemaining = 0;
        pause();
      } else {
        _secondsRemaining--;
        notifyListeners();
      }
    });
    notifyListeners();
    _saveToPrefs();
  }

  void pause() {
    _ticker?.cancel();
    _ticker = null;
    _isRunning = false;
    notifyListeners();
    _saveToPrefs();
  }

  void reset() {
    _ticker?.cancel();
    _ticker = null;
    _isRunning = false;
    _secondsRemaining = _defaultSeconds;
    notifyListeners();
    _saveToPrefs();
  }

  void addMinutes(int minutes) {
    _secondsRemaining += minutes * 60;
    notifyListeners();
    _saveToPrefs();
  }

  void setCustomSeconds(int seconds) {
    _secondsRemaining = seconds.clamp(0, 24 * 60 * 60).toInt();
    notifyListeners();
    _saveToPrefs();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('secondsRemaining', _secondsRemaining);
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _secondsRemaining = prefs.getInt('secondsRemaining') ?? _defaultSeconds;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
