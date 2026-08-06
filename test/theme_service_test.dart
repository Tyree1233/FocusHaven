import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ThemeService> createThemeService() async {
    final service = ThemeService();
    await Future<void>.delayed(Duration.zero);
    return service;
  }

  test('saves the selected appearance theme locally', () async {
    final service = await createThemeService();
    addTearDown(service.dispose);

    await service.setTheme(FocusHavenTheme.forest);

    expect(service.selectedTheme, FocusHavenTheme.forest);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('focusHavenTheme'), 'forest');
  });

  test('clearing local data restores the twilight theme', () async {
    final service = await createThemeService();
    addTearDown(service.dispose);
    await service.setTheme(FocusHavenTheme.sunset);

    await service.clearLocalData();

    expect(service.selectedTheme, FocusHavenTheme.twilight);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('focusHavenTheme'), isFalse);
  });

  test('loads a previously selected appearance theme', () async {
    SharedPreferences.setMockInitialValues({
      'focusHavenTheme': 'roseQuartz',
    });

    final service = await createThemeService();
    addTearDown(service.dispose);

    expect(service.selectedTheme, FocusHavenTheme.roseQuartz);
  });
}
