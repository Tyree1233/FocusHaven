import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/app_localizations.dart';
import 'package:focushaven/l10n/focus_haven_locales.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/screens/onboarding_screen.dart';
import 'package:focushaven/services/auth_service.dart';
import 'package:focushaven/services/coaching_service.dart';
import 'package:focushaven/services/focus_queue_service.dart';
import 'package:focushaven/services/timer_service.dart';
import 'package:focushaven/services/voice_transcription_service.dart';
import 'package:focushaven/widgets/account_sheet.dart';
import 'package:focushaven/widgets/coaching_sheet.dart';
import 'package:focushaven/widgets/haven_action_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Spanish onboarding survives narrow large-text layout', (
    tester,
  ) async {
    _useNarrowPhone(tester);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        _spanishApp(
          const OnboardingScreen(),
          textScale: 2,
          wrapInScaffold: false,
          routes: {'/timer': (_) => const Scaffold(body: Text('Destino'))},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Te damos la bienvenida a FocusHaven'), findsOneWidget);
      expect(find.text('Comenzar enfoque'), findsOneWidget);
      expect(find.bySemanticsLabel('Comenzar enfoque'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('Spanish Focus Coach survives narrow large-text layout', (
    tester,
  ) async {
    _useNarrowPhone(tester);
    final coach = CoachingService();
    await coach.initialized;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [coachingServiceProvider.overrideWith((ref) => coach)],
        child: _spanishApp(
          const CoachingSheet(contextBuilder: CoachingContext.new),
          textScale: 1.6,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coach de enfoque'), findsOneWidget);
    expect(
      find.text('Orientación privada guardada en este dispositivo'),
      findsOneWidget,
    );
    expect(
      find.text('No tienes que descubrir el siguiente paso sin ayuda.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Cerrar Coach de enfoque'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('coach-message-input')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('coach-message-input')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('coach-voice-input')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('coach-send-message')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Spanish Haven Actions remains reviewable at large text', (
    tester,
  ) async {
    _useNarrowPhone(tester);
    final timer = TimerService();
    final queue = FocusQueueService();
    final voice = VoiceTranscriptionService();
    await Future.wait([timer.initialized, queue.initialized]);
    addTearDown(timer.dispose);
    addTearDown(queue.dispose);
    addTearDown(voice.dispose);

    await tester.pumpWidget(
      _spanishApp(
        HavenActionSheet(
          timerService: timer,
          focusQueueService: queue,
          voiceTranscriptionService: voice,
          onOpenSurface: (_) async {},
        ),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Acciones Haven'), findsOneWidget);
    expect(
      find.text(
        'Texto escrito o transcripción de voz • revisión local • sin IA remota',
      ),
      findsOneWidget,
    );
    expect(find.text('¿Qué debería hacer Haven?'), findsOneWidget);
    expect(find.text('Revisar acción'), findsOneWidget);
    expect(find.byTooltip('Cerrar Acciones Haven'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Spanish account privacy controls survive narrow large text', (
    tester,
  ) async {
    _useNarrowPhone(tester);
    final auth = AuthService(appleSignInSupported: false);
    await auth.initialized;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWith((ref) => auth),
          authStateProvider.overrideWithValue((
            isSignedIn: false,
            displayName: 'Invitado',
            signInError: null,
          )),
        ],
        child: _spanishApp(
          AccountSheet(
            deleteAccount: _noAction,
            deleteCloudBackup: _noAction,
            deleteLocalData: _noAction,
            openPro: _noAction,
            openFocusProfile: _noAction,
            openAppearance: _noAction,
            openPrivacyPolicy: _noAction,
          ),
          textScale: 1.6,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tu cuenta de FocusHaven'), findsOneWidget);
    expect(
      find.text(
        'Inicia sesión para proteger tu historial de enfoque y usar la copia de seguridad en la nube.',
      ),
      findsOneWidget,
    );
    expect(find.text('Iniciar sesión con Google'), findsOneWidget);
    expect(find.text('Eliminar datos locales'), findsOneWidget);
    expect(find.byTooltip('Cerrar configuración de la cuenta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('reviewed Spanish remains available after the C3B layout gate', () {
    expect(
      FocusHavenLocales.productionLocales,
      containsAll(const <Locale>[Locale('en'), Locale('es')]),
    );
    expect(FocusHavenLocales.integrationLocales, isEmpty);
    expect(
      AppLocalizations.supportedLocales,
      containsAll(const <Locale>[Locale('en'), Locale('es')]),
    );
  });

  test('C3B records a bounded critical-surface qualification', () {
    final qualification =
        jsonDecode(
              File(
                'localization/reviews/es/qualification.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final surfaces = qualification['layoutAccessibilitySurfaces'] as List;

    expect(qualification['layoutAccessibilityPhase'], '215G-C3B');
    expect(qualification['layoutAccessibilityStatus'], 'critical_verified');
    expect(qualification['layoutAccessibilityTestWidth'], 320);
    expect(surfaces, [
      'onboarding',
      'focus_coach',
      'haven_actions',
      'account_privacy',
    ]);
    expect(qualification['productionLocaleAllowed'], isTrue);
    expect(qualification['runtimeActivated'], isTrue);
  });
}

Widget _spanishApp(
  Widget home, {
  required double textScale,
  bool wrapInScaffold = true,
  Map<String, WidgetBuilder> routes = const {},
}) => MaterialApp(
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
  home: wrapInScaffold ? Scaffold(body: home) : home,
  routes: routes,
);

void _useNarrowPhone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 720);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _noAction() async {}
