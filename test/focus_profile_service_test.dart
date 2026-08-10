import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/services/focus_profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<FocusProfileService> createProfile() async {
    final profile = FocusProfileService();
    await profile.initialized;
    return profile;
  }

  test('saves a focus profile locally', () async {
    final profile = await createProfile();
    addTearDown(profile.dispose);

    await profile.saveFocusType('Deep work');

    expect(profile.focusType, 'Deep work');
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('focusProfile'), 'Deep work');
  });

  test('clears the saved focus profile', () async {
    final profile = await createProfile();
    addTearDown(profile.dispose);
    await profile.saveFocusType('Creative flow');

    await profile.clearLocalData();

    expect(profile.focusType, isNull);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('focusProfile'), isFalse);
  });

  test('loads and normalizes the saved focus profile on launch', () async {
    SharedPreferences.setMockInitialValues({
      'focusProfile': '  Structured planner  ',
    });

    final profile = await createProfile();
    addTearDown(profile.dispose);

    expect(profile.focusType, 'Structured planner');
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('focusProfile'), 'Structured planner');
  });

  test('rejects invalid values and suppresses duplicate updates', () async {
    final profile = await createProfile();
    addTearDown(profile.dispose);
    var notifications = 0;
    profile.addListener(() => notifications += 1);

    await profile.saveFocusType('  Deep work  ');
    expect(profile.focusType, 'Deep work');
    expect(notifications, 1);

    await profile.saveFocusType('Deep work');
    await profile.saveFocusType('   ');
    await profile.saveFocusType(List<String>.filled(81, 'x').join());

    expect(profile.focusType, 'Deep work');
    expect(notifications, 1);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('focusProfile'), 'Deep work');
  });

  test('removes an invalid saved profile value', () async {
    SharedPreferences.setMockInitialValues({'focusProfile': '   '});

    final profile = await createProfile();
    addTearDown(profile.dispose);

    expect(profile.focusType, isNull);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('focusProfile'), isFalse);
  });

  test(
    'removes a focus profile preference with the wrong value type',
    () async {
      SharedPreferences.setMockInitialValues({'focusProfile': true});

      final profile = await createProfile();
      addTearDown(profile.dispose);

      expect(profile.focusType, isNull);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.containsKey('focusProfile'), isFalse);
    },
  );

  test('initialization and mutations are safe after disposal', () async {
    SharedPreferences.setMockInitialValues({'focusProfile': 'Deep Diver'});
    final profile = FocusProfileService();

    profile.dispose();
    await profile.initialized;
    await profile.saveFocusType('Gentle Flow');
    await profile.clearLocalData();

    expect(profile.focusType, isNull);
  });
}
