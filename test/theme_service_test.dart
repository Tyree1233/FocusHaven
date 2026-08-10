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
    await service.initialized;
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
    SharedPreferences.setMockInitialValues({'focusHavenTheme': 'roseQuartz'});

    final service = await createThemeService();
    addTearDown(service.dispose);

    expect(service.selectedTheme, FocusHavenTheme.roseQuartz);
  });

  test('keeps the default theme when a saved theme is unrecognized', () async {
    SharedPreferences.setMockInitialValues({'focusHavenTheme': 'unknown'});
    final service = await createThemeService();
    addTearDown(service.dispose);

    expect(service.selectedTheme, FocusHavenTheme.twilight);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('focusHavenTheme'), isFalse);
  });

  test('removes an appearance preference with the wrong value type', () async {
    SharedPreferences.setMockInitialValues({'focusHavenTheme': true});

    final service = await createThemeService();
    addTearDown(service.dispose);

    expect(service.selectedTheme, FocusHavenTheme.twilight);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('focusHavenTheme'), isFalse);
  });

  test('does not rebuild for repeated selection of the active theme', () async {
    final service = await createThemeService();
    addTearDown(service.dispose);
    var notifications = 0;
    service.addListener(() => notifications += 1);

    await service.setTheme(FocusHavenTheme.twilight);
    expect(notifications, 0);

    await service.setTheme(FocusHavenTheme.forest);
    expect(notifications, 1);

    await service.setTheme(FocusHavenTheme.forest);
    expect(notifications, 1);
  });

  test('initialization and mutations are safe after disposal', () async {
    SharedPreferences.setMockInitialValues({'focusHavenTheme': 'forest'});
    final service = ThemeService();

    service.dispose();
    await service.initialized;
    await service.setTheme(FocusHavenTheme.sunset);
    await service.clearLocalData();

    expect(service.selectedTheme, FocusHavenTheme.twilight);
  });
}
