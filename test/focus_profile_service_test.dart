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
    await Future<void>.delayed(Duration.zero);
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
}
