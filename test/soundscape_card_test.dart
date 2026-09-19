import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/services/soundscape_controller.dart';
import 'package:focushaven/widgets/soundscape_card.dart';
import 'support/fake_soundscape_output.dart';

void main() {
  testWidgets('explicit accessible play/pause and volume', (tester) async {
    final output = FakeSoundscapeOutput();
    final sound = SoundscapeController(output);
    addTearDown(sound.dispose);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SoundscapeCard(controller: sound)),
        ),
      );
      expect(output.starts, 0);
      expect(find.bySemanticsLabel('Play sound'), findsOneWidget);
      await tester.tap(find.text('Play sound'));
      await tester.pumpAndSettle();
      expect(find.text('Playing'), findsOneWidget);
      expect(find.bySemanticsLabel('Pause sound'), findsOneWidget);
      await tester.tap(find.text('Pause sound'));
      await tester.pumpAndSettle();
      expect(find.text('Paused'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('320px at 2x text keeps controls reachable without overflow', (
    tester,
  ) async {
    final sound = SoundscapeController(FakeSoundscapeOutput());
    addTearDown(sound.dispose);
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: SoundscapeCard(controller: sound),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Play sound'));
    expect(
      tester
          .getSize(find.byWidgetPredicate((widget) => widget is FilledButton))
          .height,
      greaterThanOrEqualTo(48),
    );
    await tester.ensureVisible(find.byType(Slider));
    expect(tester.takeException(), isNull);
  });
  testWidgets('unavailable output does not offer a working play control', (
    tester,
  ) async {
    final sound = SoundscapeController(
      UnavailableSoundscapeOutput(),
      available: false,
    );
    addTearDown(sound.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SoundscapeCard(controller: sound)),
      ),
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byWidgetPredicate((widget) => widget is FilledButton),
          )
          .onPressed,
      isNull,
    );
    expect(find.textContaining('unavailable on this platform'), findsOneWidget);
  });
}
