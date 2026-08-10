import 'dart:async';

import 'package:flutter/material.dart';

class GuidedBreathingSheet extends StatefulWidget {
  const GuidedBreathingSheet({super.key});

  @override
  State<GuidedBreathingSheet> createState() => _GuidedBreathingSheetState();
}

class _GuidedBreathingSheetState extends State<GuidedBreathingSheet> {
  static const _phaseLabels = ['Breathe in', 'Hold gently', 'Breathe out'];
  static const _phaseDurations = [4, 4, 6];

  Timer? _ticker;
  var _totalRemaining = 60;
  var _phaseIndex = 0;
  var _phaseRemaining = _phaseDurations.first;
  var _isRunning = false;

  String get _formattedTime {
    final minutes = _totalRemaining ~/ Duration.secondsPerMinute;
    final seconds = _totalRemaining % Duration.secondsPerMinute;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  bool get _isComplete => _totalRemaining == 0;

  void _toggle() {
    if (_isComplete) {
      _reset();
      _toggle();
      return;
    }
    if (_isRunning) {
      _ticker?.cancel();
      setState(() => _isRunning = false);
      return;
    }
    setState(() => _isRunning = true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_totalRemaining <= 1) {
        _ticker?.cancel();
        setState(() {
          _totalRemaining = 0;
          _isRunning = false;
        });
        return;
      }
      setState(() {
        _totalRemaining--;
        if (_phaseRemaining <= 1) {
          _phaseIndex = (_phaseIndex + 1) % _phaseLabels.length;
          _phaseRemaining = _phaseDurations[_phaseIndex];
        } else {
          _phaseRemaining--;
        }
      });
    });
  }

  void _reset() {
    _ticker?.cancel();
    setState(() {
      _totalRemaining = 60;
      _phaseIndex = 0;
      _phaseRemaining = _phaseDurations.first;
      _isRunning = false;
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final expanded = _phaseIndex == 0 || _phaseIndex == 1;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 42,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Mindful pause',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Follow a calming 4–4–6 breath for one minute.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 26),
            SizedBox(
              height: 210,
              width: 210,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeInOut,
                  height: expanded ? 180 : 118,
                  width: expanded ? 180 : 118,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary.withValues(alpha: 0.24),
                    border: Border.all(color: colors.primary, width: 3),
                  ),
                  child: Center(
                    child: Text(
                      _isComplete ? 'Complete' : _phaseLabels[_phaseIndex],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Text(
              _formattedTime,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              _isComplete
                  ? 'You made space for yourself.'
                  : '$_phaseRemaining seconds',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _toggle,
                icon: Icon(
                  _isRunning
                      ? Icons.pause
                      : _isComplete
                      ? Icons.replay
                      : Icons.play_arrow,
                ),
                label: Text(
                  _isRunning
                      ? 'Pause'
                      : _isComplete
                      ? 'Try again'
                      : 'Begin breathing',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.surface,
                  minimumSize: const Size.fromHeight(54),
                ),
              ),
            ),
            if (_isRunning || _isComplete)
              TextButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
              ),
          ],
        ),
      ),
    );
  }
}
