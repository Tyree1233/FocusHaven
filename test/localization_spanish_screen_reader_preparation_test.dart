import 'dart:convert';
import 'dart:io';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/app_localizations.dart';
import 'package:focushaven/l10n/focus_haven_locales.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/theme_service.dart';
import 'package:focushaven/widgets/appearance_sheet.dart';
import 'package:focushaven/widgets/custom_duration_sheet.dart';
import 'package:focushaven/widgets/guided_breathing_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Spanish duration wheels expose adjustable semantic actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        _spanishApp(
          const CustomDurationSheet(
            sessionLabel: 'Enfoque',
            sessionColor: Color(0xFFEF65B7),
            initialDuration: Duration(minutes: 7, seconds: 5),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final minutesFinder = find.byKey(
        const ValueKey<String>('custom-duration-minutes-semantics'),
      );
      final secondsFinder = find.byKey(
        const ValueKey<String>('custom-duration-seconds-semantics'),
      );
      final minutesNode = tester.getSemantics(minutesFinder);
      final secondsNode = tester.getSemantics(secondsFinder);

      expect(minutesNode.value, '7 minutos');
      expect(minutesNode.increasedValue, '8 minutos');
      expect(minutesNode.decreasedValue, '6 minutos');
      expect(
        minutesNode.getSemanticsData().hasAction(SemanticsAction.increase),
        isTrue,
      );
      expect(
        minutesNode.getSemanticsData().hasAction(SemanticsAction.decrease),
        isTrue,
      );
      expect(secondsNode.value, '5 segundos');
      expect(secondsNode.increasedValue, '6 segundos');
      expect(secondsNode.decreasedValue, '4 segundos');

      tester.semantics.increase(find.semantics.byValue('7 minutos'));
      tester.semantics.decrease(find.semantics.byValue('5 segundos'));
      await tester.pumpAndSettle();

      expect(tester.getSemantics(minutesFinder).value, '8 minutos');
      expect(tester.getSemantics(secondsFinder).value, '4 segundos');
      final submit = tester.getSemantics(
        find.bySemanticsLabel('Establecer 08:04'),
      );
      expect(submit.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(submit.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('Spanish breathing phase is an announced live region', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_spanishApp(const GuidedBreathingSheet()));
      await tester.pumpAndSettle();

      final statusFinder = find.byKey(
        const ValueKey<String>('guided-breathing-status-semantics'),
      );
      final initialStatus = tester.getSemantics(statusFinder);
      expect(initialStatus.label, 'Inhala');
      expect(initialStatus.value, '4 segundos');
      expect(
        initialStatus.getSemanticsData().flagsCollection.isLiveRegion,
        isTrue,
      );

      final begin = tester.getSemantics(
        find.bySemanticsLabel('Comenzar respiración'),
      );
      expect(begin.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(begin.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Comenzar respiración'),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.getSemantics(statusFinder).value, '3 segundos');

      await tester.tap(find.widgetWithText(TextButton, 'Restablecer'));
      await tester.pump();
      expect(tester.getSemantics(statusFinder).value, '4 segundos');
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('Spanish appearance choices and failures are announced', (
    tester,
  ) async {
    final theme = ThemeService();
    await theme.initialized;
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [themeServiceProvider.overrideWith((ref) => theme)],
          child: _spanishApp(
            AppearanceSheet(
              setTheme: (_) async => throw StateError('synthetic failure'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final selectedTheme = tester.getSemantics(
        find.bySemanticsLabel('Crepúsculo'),
      );
      expect(
        selectedTheme
            .getSemanticsData()
            .flagsCollection
            .isInMutuallyExclusiveGroup,
        isTrue,
      );
      expect(
        selectedTheme.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );

      await tester.tap(find.text('Azul sereno'));
      await tester.pumpAndSettle();

      final error = tester.getSemantics(
        find.byKey(const ValueKey<String>('appearance-update-error-semantics')),
      );
      expect(
        error.label,
        'No se pudo actualizar la apariencia. Inténtalo de nuevo.',
      );
      expect(error.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  test('C3D automated semantics remain exact after physical acceptance', () {
    final qualification =
        jsonDecode(
              File(
                'localization/reviews/es/qualification.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;

    expect(qualification['screenReaderPreparationPhase'], '215G-C3D');
    expect(
      qualification['screenReaderPreparationStatus'],
      'automated_semantics_verified',
    );
    expect(qualification['screenReaderAutomatedSurfaces'], [
      'onboarding',
      'timer_dashboard',
      'focus_coach',
      'haven_actions',
      'account_privacy',
      'appearance',
      'custom_duration',
      'guided_breathing',
      'focus_queue',
      'completed_tasks',
    ]);
    expect(qualification['screenReaderPhysicalAcceptancePassed'], isTrue);
    expect(qualification['screenReaderQualified'], isTrue);
    expect(qualification['productionLocaleAllowed'], isFalse);
    expect(qualification['runtimeActivated'], isFalse);
    expect(FocusHavenLocales.productionLocales, const <Locale>[Locale('en')]);
  });
}

Widget _spanishApp(Widget home) => MaterialApp(
  locale: const Locale('es'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: ThemeData.dark(),
  home: Scaffold(body: home),
);
