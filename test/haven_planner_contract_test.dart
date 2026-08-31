import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('planner remains a local transparent proposal boundary', () {
    final model = _read('lib/models/haven_planner_proposal.dart');
    final planner = _read('lib/services/haven_planner_service.dart');
    final sheet = _read('lib/widgets/haven_planner_sheet.dart');

    for (final contract in <String>[
      'HavenPlannerProposal',
      'HavenPlannerUncertainty',
      'HavenPlannerReviewChoice',
      'affectedLocalData',
      'isLocalOnly',
    ]) {
      expect(model, contains(contract));
    }

    expect(planner, contains('Creates an explainable planning draft'));
    expect(planner, contains('does not know your deadlines'));
    expect(planner, contains('did not read or write a calendar'));
    expect(sheet, contains('Local planner foundation • no remote AI'));
    expect(sheet, contains('Nothing is saved or changed'));
    expect(sheet, contains('Review each item'));
    expect(sheet, contains('Apply reviewed choices'));
    expect(sheet, contains('timer and calendar were unchanged'));

    for (final forbidden in <String>[
      'cloud_functions',
      'firebase_auth',
      'FirebaseFunctions',
      'SharedPreferences',
      'package:http',
      'dart:io',
    ]) {
      expect(planner, isNot(contains(forbidden)));
    }
  });

  test('accepted tasks pass through fresh state-bound Haven actions', () {
    final actionService = _read(
      'lib/services/haven_planner_action_service.dart',
    );
    final sheet = _read('lib/widgets/haven_planner_sheet.dart');

    expect(actionService, contains("'add task: \$title'"));
    expect(actionService, contains('executor.snapshot()'));
    expect(actionService, contains('engine.evaluate(proposal)'));
    expect(actionService, contains('engine.execute('));
    expect(actionService, contains('HavenActionConfirmation.forProposal('));
    expect(actionService, contains('confirmedAtUtc:'));
    expect(actionService, isNot(contains('focusQueue.add')));
    expect(actionService, isNot(contains('SharedPreferences')));

    for (final independentlyReviewed in <String>[
      'havenPlannerAccept-',
      'havenPlannerEditChoice-',
      'havenPlannerReject-',
    ]) {
      expect(sheet, contains(independentlyReviewed));
    }
    expect(sheet, contains('Add only these'));
    expect(sheet, contains('Add to Focus Queue'));
  });

  test('planner adds no native permission or remote dependency', () {
    final androidManifest = _read('android/app/src/main/AndroidManifest.xml');
    final iosInfo = _read('ios/Runner/Info.plist');
    final pubspec = _read('pubspec.yaml');

    for (final forbidden in <String>[
      'ACCESS_FINE_LOCATION',
      'ACCESS_COARSE_LOCATION',
      'READ_CONTACTS',
      'WRITE_CALENDAR',
    ]) {
      expect(androidManifest, isNot(contains(forbidden)));
    }
    for (final forbidden in <String>[
      'NSLocationWhenInUseUsageDescription',
      'NSContactsUsageDescription',
      'NSCalendarsWriteOnlyAccessUsageDescription',
    ]) {
      expect(iosInfo, isNot(contains(forbidden)));
    }
    for (final remotePlannerDependency in <String>[
      'openai',
      'google_generative_ai',
      'langchain',
    ]) {
      expect(
        pubspec,
        isNot(
          matches(
            RegExp('^\\s*$remotePlannerDependency\\s*:', multiLine: true),
          ),
        ),
      );
    }
  });
}

String _read(String path) => File(path).readAsStringSync();
