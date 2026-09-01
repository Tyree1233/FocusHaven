import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/l10n/app_localizations.dart';
import 'package:focushaven/models/focus_shield_state.dart';
import 'package:focushaven/widgets/focus_shield_card.dart';

FocusShieldState _state({
  required FocusShieldPhase phase,
  Set<FocusShieldAction> actions = const {},
}) => FocusShieldState(
  phase: phase,
  headline: 'Headline for ${phase.name}',
  detail: 'Honest detail for ${phase.name}.',
  shouldProtect:
      phase == FocusShieldPhase.starting ||
      phase == FocusShieldPhase.protecting ||
      phase == FocusShieldPhase.needsAttention,
  nativeProtectionReported: phase == FocusShieldPhase.protecting,
  availableActions: actions,
);

Widget _app(
  FocusShieldState state, {
  ValueChanged<FocusShieldAction>? onAction,
  double textScale = 1,
  Size surface = const Size(420, 760),
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQueryData(
      size: surface,
      textScaler: TextScaler.linear(textScale),
    ),
    child: child!,
  ),
  theme: ThemeData.dark().copyWith(
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFF16FBA),
      secondary: Color(0xFFF58FC0),
      tertiary: Color(0xFFC58BFF),
      surface: Color(0xFF352260),
    ),
  ),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: surface.width,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: FocusShieldCard(state: state, onAction: onAction),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('labels every phase without inventing protected status', (
    tester,
  ) async {
    const labels = {
      FocusShieldPhase.off: 'OFF',
      FocusShieldPhase.unsupported: 'UNAVAILABLE',
      FocusShieldPhase.needsAuthorization: 'PERMISSION NEEDED',
      FocusShieldPhase.needsSelection: 'SETUP NEEDED',
      FocusShieldPhase.ready: 'READY',
      FocusShieldPhase.starting: 'CONFIRMING',
      FocusShieldPhase.protecting: 'PROTECTED',
      FocusShieldPhase.paused: 'PAUSED',
      FocusShieldPhase.needsAttention: 'NEEDS ATTENTION',
    };

    for (final entry in labels.entries) {
      await tester.pumpWidget(_app(_state(phase: entry.key)));

      expect(find.text('FOCUS SHIELD · ${entry.value}'), findsOneWidget);
      expect(find.text('Headline for ${entry.key.name}'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('details stay behind an explicit tap and explain boundaries', (
    tester,
  ) async {
    final state = _state(phase: FocusShieldPhase.off);
    await tester.pumpWidget(_app(state));

    expect(find.text(state.detail), findsNothing);
    expect(find.byKey(const ValueKey('focus-shield-details')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('toggle-focus-shield')));
    await tester.pump();

    expect(find.text(state.detail), findsOneWidget);
    expect(find.textContaining('Breaks and pauses stay open'), findsOneWidget);
    expect(find.textContaining('stay on this device'), findsOneWidget);
  });

  testWidgets('shows and dispatches only actions admitted by the state', (
    tester,
  ) async {
    final received = <FocusShieldAction>[];
    final state = _state(
      phase: FocusShieldPhase.needsAttention,
      actions: const {
        FocusShieldAction.retryProtection,
        FocusShieldAction.pauseProtection,
        FocusShieldAction.disable,
      },
    );
    await tester.pumpWidget(_app(state, onAction: received.add));
    await tester.tap(find.byKey(const ValueKey('toggle-focus-shield')));
    await tester.pump();

    expect(find.text('Retry protection'), findsOneWidget);
    expect(find.text('Pause protection'), findsOneWidget);
    expect(find.text('Turn off Focus Shield'), findsOneWidget);
    expect(find.text('Choose distractions'), findsNothing);

    for (final action in [
      FocusShieldAction.retryProtection,
      FocusShieldAction.pauseProtection,
      FocusShieldAction.disable,
    ]) {
      final control = find.byKey(
        ValueKey('focus-shield-action-${action.name}'),
      );
      await tester.ensureVisible(control);
      await tester.tap(control);
      await tester.pump();
    }

    expect(received, [
      FocusShieldAction.retryProtection,
      FocusShieldAction.pauseProtection,
      FocusShieldAction.disable,
    ]);
  });

  testWidgets('never presents inert setup controls without a host callback', (
    tester,
  ) async {
    final state = _state(
      phase: FocusShieldPhase.needsSelection,
      actions: const {
        FocusShieldAction.chooseDistractions,
        FocusShieldAction.disable,
      },
    );
    await tester.pumpWidget(_app(state));
    await tester.tap(find.byKey(const ValueKey('toggle-focus-shield')));
    await tester.pump();

    expect(find.text('Choose distractions'), findsNothing);
    expect(find.text('Turn off Focus Shield'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('supports a narrow surface and large accessible text', (
    tester,
  ) async {
    final state = _state(phase: FocusShieldPhase.protecting);
    await tester.pumpWidget(
      _app(state, textScale: 2, surface: const Size(280, 760)),
    );
    await tester.tap(find.byKey(const ValueKey('toggle-focus-shield')));
    await tester.pump();

    expect(find.text('FOCUS SHIELD · PROTECTED'), findsOneWidget);
    expect(find.text(state.detail), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
