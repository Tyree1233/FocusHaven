import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const contractPath =
      'docs/contracts/android_system_assistant_app_actions_mapping_v1.json';
  const expectedRoutes = <String>{
    'readTimerStatus',
    'startFocusTimer',
    'pauseTimer',
    'resumeTimer',
    'openFocusQueue',
  };

  Map<String, dynamic> readContract() =>
      jsonDecode(File(contractPath).readAsStringSync()) as Map<String, dynamic>;

  test('mapping selects one exact truthful capability per route', () {
    final contract = readContract();
    final routes = (contract['routes'] as List<dynamic>)
        .cast<Map<String, dynamic>>();

    expect(contract['schemaVersion'], 1);
    expect(
      contract['contract'],
      'focus_haven_phase217j_android_app_actions_mapping_review_v1',
    );
    expect(routes, hasLength(5));
    expect(routes.map((route) => route['route']).toSet(), expectedRoutes);
    expect(
      routes.map((route) => route['fulfillmentAction']).toSet(),
      hasLength(5),
    );
    expect(
      routes.every(
        (route) =>
            route['fulfillmentAction'].toString().startsWith(
              'com.focushaven.app.action.REVIEW_',
            ) &&
            (route['assistantValuesAcceptedIntoRequest'] as List<dynamic>)
                .isEmpty,
      ),
      isTrue,
    );

    final timerRoutes = routes.where(
      (route) => route['route'] != 'openFocusQueue',
    );
    expect(timerRoutes, hasLength(4));
    for (final route in timerRoutes) {
      expect(route['capabilityType'], 'customIntent');
      expect(
        route['capabilityId'],
        startsWith('custom.actions.intent.REVIEW_'),
      );
      expect(route['queryPatternResource'], startsWith('@array/'));
      expect(route['assistantParameterKeys'], isEmpty);
    }

    final queue = routes.singleWhere(
      (route) => route['route'] == 'openFocusQueue',
    );
    expect(queue['capabilityType'], 'builtInIntent');
    expect(queue['capabilityId'], 'actions.intent.OPEN_APP_FEATURE');
    expect(queue['queryPatternResource'], isNull);
    expect(queue['assistantParameterKeys'], ['feature']);
    expect(queue['requiredInlineInventory'], {
      'parameter': 'feature',
      'shortcutId': 'focus_queue_review',
      'constantValue': 'focus_queue_review',
    });
  });

  test('mapping preserves the exact text-free Phase 217H handoff', () {
    final contract = readContract();

    expect(contract['targetPackage'], 'com.focushaven.app');
    expect(contract['targetClass'], 'com.focushaven.app.MainActivity');
    expect(contract['requestPayloadKeys'], [
      'schemaVersion',
      'invocationId',
      'kind',
    ]);

    final encoded = jsonEncode(contract);
    for (final forbidden in <String>[
      'taskTitle',
      'queueItem',
      'durationSeconds',
      'transcript',
      'utterance',
      'journal',
      'coachingHistory',
      'accountValue',
    ]) {
      expect(encoded, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('locale eligibility is explicit and never inferred from app copy', () {
    final constraints =
        readContract()['platformConstraints'] as Map<String, dynamic>;

    expect(constraints['customIntentQueryPatternLocale'], 'en-US');
    expect(constraints['customIntentUserInvocationLocales'], ['en-US']);
    expect(
      (constraints['openAppFeatureUserInvocationLocales'] as List<dynamic>)
          .toSet(),
      {
        'en-US',
        'en-GB',
        'en-CA',
        'en-IN',
        'en-BE',
        'en-SG',
        'en-AU',
        'es-ES',
        'pt-BR',
      },
    );
    expect(constraints['unsupportedLocaleClaimsForbidden'], isTrue);
    expect(
      constraints['forbiddenBuiltInIntents'],
      containsAll(<String>[
        'actions.intent.START_EXERCISE',
        'actions.intent.PAUSE_EXERCISE',
        'actions.intent.RESUME_EXERCISE',
        'actions.intent.GET_EXERCISE_OBSERVATION',
        'actions.intent.GET_THING',
        'actions.intent.GET_ITEM_LIST',
      ]),
    );
  });

  test('review evidence grants no registration or execution authority', () {
    final contract = readContract();

    for (final key in <String>[
      'registrationEnabled',
      'shortcutsXmlCreated',
      'manifestMetadataCreated',
      'queryPatternResourceCreated',
      'dependencyAdded',
      'requestSubmissionEnabled',
      'havenActionExecutionEnabled',
    ]) {
      expect(contract[key], isFalse, reason: key);
    }
    final registration =
        jsonDecode(
              File(
                'docs/contracts/android_system_assistant_app_actions_registration_v1.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(
      registration['mappingReviewContract'],
      'docs/contracts/android_system_assistant_app_actions_mapping_v1.json',
    );
    expect(registration['reviewSettlementEnabled'], isFalse);
    expect(registration['havenActionExecutionEnabled'], isFalse);
  });

  test('documentation keeps registration and release gates closed', () {
    final review = _normalize(
      File(
        'docs/ANDROID_SYSTEM_ASSISTANT_APP_ACTIONS_MAPPING_REVIEW.md',
      ).readAsStringSync(),
    );

    for (final required in <String>[
      'no timer-control BII',
      'must not be repurposed',
      'required constant `feature` inventory match is validated and discarded',
      'only for `en-US`',
      'must not claim that all seventeen',
      'Phase 217J creates no `shortcuts.xml`',
      'Mapping approval is not registration or release approval',
      'visible in-app Confirm action',
    ]) {
      expect(review, contains(required), reason: required);
    }
  });
}

String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();
