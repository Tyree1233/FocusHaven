
import 'package:flutter/material.dart';
import 'dart:async';
import 'firebase_sync_service.dart';
import 'iap_service.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  _TimerScreenState createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  int _secondsRemaining = 1500;
  bool _isPro = false;
  bool _isRunning = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadProStatusAndData();
  }

  void _loadProStatusAndData() async {
    bool isPro = await IAPService.isProUser();
    setState(() {
      _isPro = isPro;
    });
    if (isPro) {
      int? cloudValue = await CloudSyncService().fetchTimerSettings();
      if (cloudValue != null) {
        setState(() {
          _secondsRemaining = cloudValue;
        });
      }
    }
  }

  void _saveSettings() async {
    if (_isPro) {
      await CloudSyncService().syncTimerSettings(_secondsRemaining);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
      return;
    }

    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        timer.cancel();
        setState(() => _isRunning = false);
        return;
      }
      setState(() => _secondsRemaining--);
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _secondsRemaining = 1500;
    });
    _saveSettings();
  }

  String get _formattedTime {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FocusHaven')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('FOCUS SESSION', style: TextStyle(letterSpacing: 1.4, color: Color(0xFFF6B1DA))),
            const SizedBox(height: 12),
            Text(_formattedTime, style: const TextStyle(fontSize: 68, fontWeight: FontWeight.bold)),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _toggleTimer,
              child: Text(_isRunning ? 'Pause session' : 'Begin focus'),
            ),
            TextButton(onPressed: _resetTimer, child: const Text('Reset timer')),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                setState(() => _secondsRemaining += 60);
                _saveSettings();
              },
              child: const Text('Add 1 minute'),
            ),
          ],
        ),
      ),
    );
  }
}
