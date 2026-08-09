import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/theme_service.dart';
import 'package:focushaven/widgets/appearance_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(ThemeService service) {
  return ProviderScope(
    overrides: [themeServiceProvider.overrideWith((ref) => service)],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: const Scaffold(body: AppearanceSheet()),
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

    for (final theme in FocusHavenTheme.values) {
      expect(find.text(theme.label), findsOneWidget);
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

    await tester.tap(find.text('Forest'));
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
}
