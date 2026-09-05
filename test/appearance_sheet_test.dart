import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/app_localizations.dart';
import 'package:focushaven/l10n/focus_haven_locales.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/locale_service.dart';
import 'package:focushaven/services/theme_service.dart';
import 'package:focushaven/widgets/appearance_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(
  ThemeService service, {
  LocaleService? localeService,
  AppearanceThemeSetter? setTheme,
  AppearanceLanguageSetter? setLanguage,
}) {
  return ProviderScope(
    overrides: [
      themeServiceProvider.overrideWith((ref) => service),
      if (localeService != null)
        localeServiceProvider.overrideWith((ref) => localeService),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: Scaffold(
        body: AppearanceSheet(setTheme: setTheme, setLanguage: setLanguage),
      ),
    ),
  );
}

FocusHavenTheme? _selectedTheme(WidgetTester tester) {
  return tester
      .widget<RadioGroup<FocusHavenTheme>>(
        find.byType(RadioGroup<FocusHavenTheme>),
      )
      .groupValue;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders every appearance and restores the saved selection', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'focusHavenTheme': FocusHavenTheme.calmBlue.name,
    });
    final service = ThemeService();
    await tester.pump();

    await tester.pumpWidget(_app(service));
    await tester.pump();

    expect(find.byTooltip('Back to account settings'), findsOneWidget);
    for (final label in const <String>[
      'Twilight',
      'Calm Blue',
      'Minimalist',
      'Sunset',
      'Forest',
      'Rose Quartz',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(service.selectedTheme, FocusHavenTheme.calmBlue);
    expect(_selectedTheme(tester), FocusHavenTheme.calmBlue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting an appearance updates state and persistence', (
    tester,
  ) async {
    final service = ThemeService();
    await tester.pump();

    await tester.pumpWidget(_app(service));
    await tester.pump();

    final forest = find.text('Forest');
    await tester.ensureVisible(forest);
    await tester.pumpAndSettle();
    await tester.tap(forest);
    await tester.pump();

    expect(service.selectedTheme, FocusHavenTheme.forest);
    expect(_selectedTheme(tester), FocusHavenTheme.forest);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString('focusHavenTheme'),
      FocusHavenTheme.forest.name,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('production languages update the app and persist locally', (
    tester,
  ) async {
    final themeService = ThemeService();
    final localeService = LocaleService();
    await Future.wait([themeService.initialized, localeService.initialized]);

    await tester.pumpWidget(_app(themeService, localeService: localeService));
    await tester.pump();

    expect(
      find.text('English / Español / Français / Deutsch / Português (Brasil)'),
      findsOneWidget,
    );
    expect(find.text('Device / Dispositivo'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Español'), findsOneWidget);
    expect(find.text('Français'), findsOneWidget);
    expect(find.text('Deutsch'), findsOneWidget);
    expect(find.text('Português (Brasil)'), findsOneWidget);

    await tester.tap(find.text('Español'));
    await tester.pumpAndSettle();

    expect(localeService.selectedChoice, FocusHavenLanguageChoice.spanish);
    expect(
      find.text('English / Español / Français / Deutsch / Português (Brasil)'),
      findsOneWidget,
    );
    expect(find.text('Device / Dispositivo'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(LocaleService.storageKey), 'es');

    final frenchOption = find.text('Français');
    await tester.ensureVisible(frenchOption);
    await tester.pumpAndSettle();
    await tester.tap(frenchOption);
    await tester.pumpAndSettle();

    final french = FocusHavenLocales.production.singleWhere(
      (definition) => definition.languageCode == 'fr',
    );
    expect(
      localeService.selectedChoice,
      FocusHavenLanguageChoice.forDefinition(french),
    );
    expect(
      find.text('English / Español / Français / Deutsch / Português (Brasil)'),
      findsOneWidget,
    );
    expect(find.text('Device / Dispositivo'), findsOneWidget);
    expect(preferences.getString(LocaleService.storageKey), 'fr');
    expect(tester.takeException(), isNull);
  });

  testWidgets('serializes overlapping appearance selections', (tester) async {
    final service = ThemeService();
    await tester.pump();
    final pendingSelection = Completer<void>();
    final selections = <FocusHavenTheme>[];

    await tester.pumpWidget(
      _app(
        service,
        setTheme: (theme) async {
          selections.add(theme);
          await pendingSelection.future;
        },
      ),
    );
    await tester.pump();

    final group = tester.widget<RadioGroup<FocusHavenTheme>>(
      find.byType(RadioGroup<FocusHavenTheme>),
    );
    group.onChanged(FocusHavenTheme.forest);
    group.onChanged(FocusHavenTheme.sunset);
    await tester.pump();

    expect(selections, [FocusHavenTheme.forest]);
    expect(
      tester
          .widget<AbsorbPointer>(
            find.byKey(const Key('appearance-selection-guard')),
          )
          .absorbing,
      isTrue,
    );

    pendingSelection.complete();
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<AbsorbPointer>(
            find.byKey(const Key('appearance-selection-guard')),
          )
          .absorbing,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('contains appearance failures and restores selection', (
    tester,
  ) async {
    final service = ThemeService();
    await tester.pump();

    await tester.pumpWidget(
      _app(
        service,
        setTheme: (_) async => throw StateError('theme storage unavailable'),
      ),
    );
    await tester.pump();
    final forest = find.text('Forest');
    await tester.ensureVisible(forest);
    await tester.pumpAndSettle();
    await tester.tap(forest);
    await tester.pumpAndSettle();

    expect(
      find.text('Appearance could not be updated. Please try again.'),
      findsOneWidget,
    );
    expect(_selectedTheme(tester), FocusHavenTheme.twilight);
    expect(tester.takeException(), isNull);
  });
}
