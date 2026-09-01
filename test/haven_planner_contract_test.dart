import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('planner remains a local transparent proposal boundary', () {
    final model = _read('lib/models/haven_planner_proposal.dart');
    final planner = _read('lib/services/haven_planner_service.dart');
    final sheet = _read('lib/widgets/haven_planner_sheet.dart');
    final catalog = _read('lib/l10n/app_en.arb');

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
    expect(sheet, contains('l10n.havenPlannerLocalOnly'));
    expect(sheet, contains('l10n.havenPlannerDescription'));
    expect(sheet, contains('l10n.havenPlannerReviewEach'));
    expect(sheet, contains('l10n.havenPlannerApplyReviewed'));
    expect(sheet, contains('l10n.havenPlannerAddSuccess'));
    expect(catalog, contains('Local planner foundation • no remote AI'));
    expect(catalog, contains('Nothing is saved or changed'));
    expect(catalog, contains('Review each item'));
    expect(catalog, contains('Apply reviewed choices'));
    expect(catalog, contains('timer and calendar were unchanged'));

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
    final catalog = _read('lib/l10n/app_en.arb');

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
    expect(sheet, contains('l10n.havenPlannerConfirmMessage'));
    expect(sheet, contains('l10n.havenPlannerAddToQueue'));
    expect(catalog, contains('Add only these'));
    expect(catalog, contains('Add to Focus Queue'));
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
