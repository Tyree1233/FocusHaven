import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/widgets/pro_benefit.dart';
import 'package:focushaven/widgets/stat_card.dart';
import 'package:focushaven/widgets/timer_countdown.dart';

Widget _materialApp(Widget child, {double textScale = 1}) {
  return MaterialApp(
    theme: ThemeData.dark().copyWith(
      colorScheme: const ColorScheme.dark(primary: Color(0xFFF064B7)),
    ),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  testWidgets('countdown renders narrow timer state and progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timerCountdownStateProvider.overrideWithValue((
            secondsRemaining: 125,
            totalSessionSeconds: 1500,
            progress: 0.5,
          )),
        ],
        child: _materialApp(
          TimerCountdown(
            sessionColor: const Color(0xFFF064B7),
            formatTime: (seconds) {
              final minutes = seconds ~/ 60;
              final remainder = seconds % 60;
              return '$minutes:${remainder.toString().padLeft(2, '0')}';
            },
            durationLabel: (seconds) => '${seconds ~/ 60} minutes',
          ),
        ),
      ),
    );

    expect(find.text('2:05'), findsOneWidget);
    expect(find.text('25 minutes'), findsOneWidget);
    final progress = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(progress.value, 0.5);
    expect(progress.color, const Color(0xFFF064B7));
    expect(tester.takeException(), isNull);
  });

  testWidgets('countdown supports narrow width and large accessible text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            timerCountdownStateProvider.overrideWithValue((
              secondsRemaining: 125,
              totalSessionSeconds: 1500,
              progress: 0.5,
            )),
          ],
          child: _materialApp(
            SizedBox(
              width: 210,
              child: TimerCountdown(
                sessionColor: const Color(0xFFF064B7),
                formatTime: (seconds) {
                  final minutes = seconds ~/ 60;
                  final remainder = seconds % 60;
                  return '$minutes:${remainder.toString().padLeft(2, '0')}';
                },
                durationLabel: (seconds) => '${seconds ~/ 60} minutes',
              ),
            ),
            textScale: 2,
          ),
        ),
      );

      final countdown = find.byKey(const ValueKey('timer-countdown-semantics'));
      expect(tester.getSize(countdown), const Size(210, 210));
      final countdownSemantics = tester.getSemantics(countdown);
      expect(countdownSemantics.label, 'Session timer');
      expect(
        countdownSemantics.value,
        '2 minutes, 5 seconds remaining of 25 minutes. 50 percent complete.',
      );
      expect(find.text('2:05'), findsOneWidget);
      expect(find.text('25 minutes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('stat card renders its icon, value, and label', (tester) async {
    await tester.pumpWidget(
      _materialApp(
        const SizedBox(
          width: 180,
          child: StatCard(
            icon: Icons.calendar_today_outlined,
            value: '42m',
            label: 'today',
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
    expect(find.text('42m'), findsOneWidget);
    expect(find.text('today'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pro benefit renders its themed icon and label', (tester) async {
    await tester.pumpWidget(
      _materialApp(
        const ProBenefit(
          icon: Icons.cloud_done_outlined,
          label: 'Secure cloud backup',
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_done_outlined));
    expect(icon.color, const Color(0xFFF064B7));
    expect(find.text('Secure cloud backup'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
