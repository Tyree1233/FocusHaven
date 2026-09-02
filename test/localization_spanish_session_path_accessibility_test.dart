import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/app_localizations.dart';
import 'package:focushaven/l10n/focus_haven_locales.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/screens/timer_screen.dart';
import 'package:focushaven/services/focus_queue_service.dart';
import 'package:focushaven/services/theme_service.dart';
import 'package:focushaven/services/timer_service.dart';
import 'package:focushaven/widgets/appearance_sheet.dart';
import 'package:focushaven/widgets/completed_tasks_sheet.dart';
import 'package:focushaven/widgets/custom_duration_sheet.dart';
import 'package:focushaven/widgets/focus_queue_sheet.dart';
import 'package:focushaven/widgets/guided_breathing_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Spanish timer dashboard survives narrow large-text layout', (
    tester,
  ) async {
    _useNarrowPhone(tester);
    final timer = TimerService();
    final queue = FocusQueueService();
    await Future.wait([timer.initialized, queue.initialized]);
    final semantics = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            timerServiceProvider.overrideWith((ref) => timer),
            focusQueueServiceProvider.overrideWith((ref) => queue),
            authStateProvider.overrideWithValue((
              isSignedIn: false,
              displayName: 'Invitado',
              signInError: null,
            )),
            authIsSignedInProvider.overrideWithValue(false),
          ],
          child: _spanishApp(const TimerScreen(), textScale: 1.6),
        ),
      );
      await tester.pump();

      expect(find.text('ENFOQUE'), findsOneWidget);
      expect(find.text('Comenzar enfoque'), findsOneWidget);
      expect(find.byTooltip('Pausa consciente'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('timer-countdown-semantics')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Temporizador de sesión'), findsOneWidget);

      final primaryAction = find.byKey(
        const ValueKey<String>('timer-primary-action'),
      );
      await tester.ensureVisible(primaryAction);
      await tester.pumpAndSettle();
      expect(primaryAction.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('Spanish Appearance remains scrollable and selectable', (
    tester,
  ) async {
    _useNarrowPhone(tester);
    final theme = ThemeService();
    await theme.initialized;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [themeServiceProvider.overrideWith((ref) => theme)],
        child: _spanishApp(const AppearanceSheet(), textScale: 1.6),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Apariencia'), findsOneWidget);
    expect(
      find.text('Elige el ambiente que mejor se adapte a tu concentración.'),
      findsOneWidget,
    );
    expect(
      find.byTooltip('Volver a la configuración de la cuenta'),
      findsOneWidget,
    );
    final lastTheme = find.text('Cuarzo rosa');
    await tester.ensureVisible(lastTheme);
    await tester.pumpAndSettle();
    expect(lastTheme.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Spanish Custom Duration keeps its confirmation reachable', (
    tester,
  ) async {
    _useNarrowPhone(tester);

    await tester.pumpWidget(
      _spanishApp(
        const CustomDurationSheet(
          sessionLabel: 'Enfoque',
          sessionColor: Color(0xFFEF65B7),
          initialDuration: Duration(minutes: 7, seconds: 5),
        ),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Duración de Enfoque'), findsOneWidget);
    expect(
      find.text('Toca un favorito o desplázate por los minutos y segundos.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('custom-duration-scroll')),
      findsOneWidget,
    );
    final submit = find.byKey(const ValueKey<String>('custom-duration-submit'));
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    expect(find.text('Establecer 07:05'), findsOneWidget);
    expect(submit.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Spanish Mindful Pause keeps breathing controls reachable', (
    tester,
  ) async {
    _useNarrowPhone(tester);

    await tester.pumpWidget(
      _spanishApp(const GuidedBreathingSheet(), textScale: 1.6),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pausa consciente'), findsOneWidget);
    expect(
      find.text('Sigue una respiración relajante 4–4–6 durante un minuto.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('guided-breathing-scroll')),
      findsOneWidget,
    );
    final begin = find.widgetWithText(FilledButton, 'Comenzar respiración');
    await tester.ensureVisible(begin);
    await tester.pumpAndSettle();
    expect(begin.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Spanish Focus Queue preserves private task text and actions', (
    tester,
  ) async {
    _useNarrowPhone(tester);
    final queue = await _queueWith([
      {
        'id': 'active-task',
        'title': 'Opaque private task title',
        'isComplete': false,
      },
      {
        'id': 'completed-task',
        'title': 'Opaque completed task title',
        'isComplete': true,
        'completedAt': '2026-09-02T12:00:00.000',
      },
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [focusQueueServiceProvider.overrideWith((ref) => queue)],
        child: _spanishApp(
          FocusQueueSheet(
            onTaskSelected: (_) async => false,
            onEditTask: (_) async {},
            onShowCompleted: () {},
          ),
          textScale: 1.6,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cola de enfoque'), findsOneWidget);
    expect(
      find.text(
        'Elige una tarea para convertirla en tu intención de enfoque actual.',
      ),
      findsOneWidget,
    );
    final add = find.byKey(const ValueKey<String>('focus-queue-add-task'));
    await tester.scrollUntilVisible(
      add,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Añadir tarea'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Opaque private task title'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Opaque private task title'), findsOneWidget);
    final edit = find.byTooltip('Editar tarea');
    final remove = find.byTooltip('Eliminar tarea');
    await tester.ensureVisible(remove);
    await tester.pumpAndSettle();
    expect(edit.hitTestable(), findsOneWidget);
    expect(remove.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Spanish Completed Tasks keeps restore controls reachable', (
    tester,
  ) async {
    _useNarrowPhone(tester);
    final queue = await _queueWith([
      {
        'id': 'completed-task',
        'title': 'Opaque completed task title',
        'isComplete': true,
        'completedAt': '2026-09-02T12:00:00.000',
      },
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [focusQueueServiceProvider.overrideWith((ref) => queue)],
        child: _spanishApp(
          CompletedTasksSheet(dateLabel: (_) => '2 sept 2026'),
          textScale: 1.6,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tareas completadas'), findsOneWidget);
    expect(
      find.text('Un registro tranquilo de lo que atendiste.'),
      findsOneWidget,
    );
    expect(find.text('Opaque completed task title'), findsOneWidget);
    expect(find.text('Completada el 2 sept 2026'), findsOneWidget);
    final restore = find.byTooltip('Devolver a la cola');
    await tester.ensureVisible(restore);
    await tester.pumpAndSettle();
    expect(restore.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('C3C keeps the reviewed catalog and production allowlist unchanged', () {
    const digest =
        '611d1afcc6eb688f92d56928f08cad5dbfdef2b5031c537c53615accfb16b83f';
    expect(_sha256('lib/l10n/app_es.arb'), digest);
    expect(_sha256('localization/candidates/app_es.arb'), digest);
    expect(FocusHavenLocales.productionLocales, const <Locale>[Locale('en')]);
    expect(FocusHavenLocales.integrationLocales, const <Locale>[Locale('es')]);
  });

  test('C3C records a bounded session-path qualification', () {
    final qualification =
        jsonDecode(
              File(
                'localization/reviews/es/qualification.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;

    expect(qualification['sessionPathAccessibilityPhase'], '215G-C3C');
    expect(
      qualification['sessionPathAccessibilityStatus'],
      'expanded_verified',
    );
    expect(qualification['sessionPathAccessibilityTestWidth'], 320);
    expect(qualification['sessionPathAccessibilityTextScale'], 1.6);
    expect(qualification['sessionPathAccessibilitySurfaces'], [
      'timer_dashboard',
      'appearance',
      'custom_duration',
      'guided_breathing',
      'focus_queue',
      'completed_tasks',
    ]);
    expect(qualification['productionLocaleAllowed'], isFalse);
    expect(qualification['runtimeActivated'], isFalse);
    expect(qualification['voiceAndCoachingQualified'], isFalse);
    expect(qualification['nativeAndStoreQualified'], isFalse);
  });
}

Widget _spanishApp(Widget home, {required double textScale}) => MaterialApp(
  locale: const Locale('es'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: ThemeData.dark(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(body: home),
);

void _useNarrowPhone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 720);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<FocusQueueService> _queueWith(List<Map<String, Object?>> items) async {
  SharedPreferences.setMockInitialValues({'focusQueue': jsonEncode(items)});
  final queue = FocusQueueService();
  await queue.initialized;
  return queue;
}

String _sha256(String path) {
  final result = Process.runSync('shasum', ['-a', '256', path]);
  expect(result.exitCode, 0);
  return result.stdout.toString().trim().split(RegExp(r'\s+')).first;
}
