import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/app_localizations.dart';
import 'package:focushaven/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(OnboardingCompletionSaver saveCompletion) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    initialRoute: '/',
    routes: {
      '/': (_) => OnboardingScreen(saveCompletion: saveCompletion),
      '/timer': (_) =>
          const Scaffold(body: Center(child: Text('Timer destination'))),
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('uses a valid saved onboarding completion before startup', () async {
    SharedPreferences.setMockInitialValues({
      onboardingCompletionPreferenceKey: true,
    });

    expect(await shouldShowOnboarding(), isFalse);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool(onboardingCompletionPreferenceKey), isTrue);
  });

  test('repairs malformed onboarding completion before startup', () async {
    SharedPreferences.setMockInitialValues({
      onboardingCompletionPreferenceKey: 'true',
    });

    expect(await shouldShowOnboarding(), isTrue);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey(onboardingCompletionPreferenceKey), isFalse);
  });

  testWidgets('serializes onboarding completion and navigates after saving', (
    tester,
  ) async {
    final pendingSave = Completer<bool>();
    var saveCalls = 0;

    await tester.pumpWidget(
      _app(() {
        saveCalls += 1;
        return pendingSave.future;
      }),
    );

    final initialButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Begin focus'),
    );
    initialButton.onPressed!.call();
    initialButton.onPressed!.call();
    await tester.pump();

    expect(saveCalls, 1);
    expect(find.text('Opening FocusHaven…'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Opening FocusHaven…'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Timer destination'), findsNothing);

    pendingSave.complete(true);
    await tester.pumpAndSettle();

    expect(find.text('Timer destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps onboarding available when saving throws', (tester) async {
    await tester.pumpWidget(
      _app(() async {
        throw StateError('storage unavailable');
      }),
    );

    await tester.tap(find.text('Begin focus'));
    await tester.pumpAndSettle();

    expect(
      find.text('FocusHaven could not start right now. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Begin focus'), findsOneWidget);
    expect(find.text('Timer destination'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps onboarding available when saving returns false', (
    tester,
  ) async {
    await tester.pumpWidget(_app(() async => false));

    await tester.tap(find.text('Begin focus'));
    await tester.pumpAndSettle();

    expect(
      find.text('FocusHaven could not save your welcome progress.'),
      findsOneWidget,
    );
    expect(find.text('Begin focus'), findsOneWidget);
    expect(find.text('Timer destination'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
