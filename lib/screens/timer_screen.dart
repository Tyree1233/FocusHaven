import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/iap_service.dart';
import '../services/timer_service.dart';

class TimerScreen extends StatelessWidget {
  const TimerScreen({super.key});

  String _formattedTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remaining = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remaining';
  }

  @override
  Widget build(BuildContext context) {
    final timer = context.watch<TimerService>();
    final auth = context.read<AuthService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('FocusHaven'),
        actions: [
          IconButton(icon: const Icon(Icons.account_circle), tooltip: 'Sign in with Google', onPressed: auth.signInWithGoogle),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('FOCUS SESSION', style: TextStyle(letterSpacing: 1.4, color: Color(0xFFF6B1DA))),
              const SizedBox(height: 12),
              Text(_formattedTime(timer.secondsRemaining), style: const TextStyle(fontSize: 68, fontWeight: FontWeight.bold)),
              const SizedBox(height: 28),
              ElevatedButton(onPressed: timer.isRunning ? timer.pause : timer.start, child: Text(timer.isRunning ? 'Pause session' : 'Begin focus')),
              TextButton(onPressed: timer.reset, child: const Text('Reset timer')),
              OutlinedButton(onPressed: () => timer.addMinutes(1), child: const Text('Add 1 minute')),
              const SizedBox(height: 20),
              FloatingActionButton.extended(
                onPressed: () async {
                  final message = await IAPService.isProUser()
                      ? 'Synced to cloud'
                      : 'Upgrade to Pro to sync';
                  if (message == 'Synced to cloud') {
                    await context.read<CloudSyncService>().syncTimerSettings(timer.secondsRemaining);
                  }
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                },
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Sync'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
