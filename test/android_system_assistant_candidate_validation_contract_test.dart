import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const validationPath =
      'docs/contracts/android_system_assistant_candidate_validation_v1.json';

  Map<String, dynamic> readJson(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  test('candidate matrix inherits exactly the five registered routes', () {
    final validation = readJson(validationPath);
    final registration = readJson(validation['registrationContract'] as String);
    final validationRoutes = (validation['routes'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final registrationRoutes = (registration['routes'] as List<dynamic>)
        .cast<Map<String, dynamic>>();

    expect(validation['schemaVersion'], 1);
    expect(
      validation['contract'],
      'focus_haven_phase217l_android_app_actions_candidate_validation_v1',
    );
    expect(
      validation['registrationCommit'],
      'e0ff7de519b8b5c6151dbc59f61adbbf689ab07c',
    );
    expect(validationRoutes, hasLength(5));
    for (final key in <String>['route', 'capabilityId', 'fulfillmentAction']) {
      expect(
        validationRoutes.map((route) => route[key]).toList(),
        registrationRoutes.map((route) => route[key]).toList(),
        reason: key,
      );
    }
    for (final route in validationRoutes) {
      expect(route['launchModes'], ['cold', 'warm']);
      expect(route['expectedMutation'], 'none');
    }
  });

  test('locale matrix does not widen custom-intent eligibility', () {
    final validation = readJson(validationPath);
    final routes = (validation['routes'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final customRoutes = routes
        .where(
          (route) => (route['capabilityId'] as String).startsWith('custom.'),
        )
        .toList(growable: false);
    final builtInRoutes = routes
        .where(
          (route) => (route['capabilityId'] as String).startsWith('actions.'),
        )
        .toList(growable: false);

    expect(customRoutes, hasLength(4));
    expect(
      customRoutes.map((route) => route['assistantLocaleContract']).toSet(),
      {'matching-en-US-only'},
    );
    expect(builtInRoutes, hasLength(1));
    expect(
      builtInRoutes.single['assistantLocaleContract'],
      'official-bii-locale-only',
    );
  });

  test('negative, accessibility, candidate, and Play gates are complete', () {
    final validation = readJson(validationPath);

    expect(
      validation['requiredNegativeCases'],
      containsAll(<String>[
        'unknown-action',
        'timer-extra',
        'missing-queue-feature',
        'changed-queue-feature',
        'additional-queue-extra',
        'uri-data',
        'clip-data',
        'selector',
        'invalid-invocation-id',
        'missing-reviewed-copy',
        'activity-recreation-replay',
      ]),
    );
    expect(
      validation['requiredAccessibilityChecks'],
      containsAll(<String>[
        'talkback-focus-order',
        'talkback-announcement-order',
        'large-text',
        'increased-display-size',
        'no-clipping-or-overlap',
        'dismiss-and-confirm-distinct',
        'no-action-ran-disclosure',
      ]),
    );
    expect(
      validation['requiredCandidateIdentity'],
      containsAll(<String>[
        'sourceCommit',
        'sourceTree',
        'artifactSha256',
        'signingCertificateSha256',
        'assistantVersion',
        'testToolVersion',
        'deviceLocale',
        'assistantLocale',
        'observedAtUtc',
      ]),
    );
    expect(
      validation['requiredPlayGates'],
      containsAll(<String>[
        'current-app-actions-terms',
        'eligible-test-track',
        'app-content',
        'app-access',
        'privacy-policy',
        'data-safety',
        'uploaded-artifact-identity',
        'app-actions-review-status',
        'explicit-distribution-authorization',
      ]),
    );
  });

  test('foundation records no external validation or release authority', () {
    final validation = readJson(validationPath);

    expect(validation['foundationOnly'], isTrue);
    for (final key in <String>[
      'externalOperationsAuthorized',
      'assistantPreviewCreated',
      'googleAccountContacted',
      'realDeviceAccessed',
      'signedCandidateCreated',
      'playConsoleAccessed',
      'playArtifactUploaded',
      'appActionsReviewRequested',
      'appActionsReviewApproved',
      'distributionAuthorized',
      'reviewSettlementEnabled',
      'havenActionExecutionEnabled',
    ]) {
      expect(validation[key], isFalse, reason: key);
    }
    expect(validation['expectedDestination'], 'inAppConfirmActionReview');
    expect(validation['expectedRequestPayloadKeys'], [
      'schemaVersion',
      'invocationId',
      'kind',
    ]);
  });

  test('review text distinguishes preview, review, and distribution', () {
    final review = File(
      'docs/ANDROID_SYSTEM_ASSISTANT_CANDIDATE_VALIDATION.md',
    ).readAsStringSync();
    final normalizedReview = review.replaceAll(RegExp(r'\s+'), ' ');

    for (final required in <String>[
      'A blank result is not a pass',
      'Every route must be checked from both a cold app launch and a warm '
          'activity',
      'An unavailable action must instead produce a correlated policy '
          'rejection',
      'A process-cold launch starts a new application process',
      'A missing review alone is not proof of rejection',
      'Device and official-tool evidence remain separate requirements',
      'Recreating `MainActivity`',
      'matching `en-US` device and Assistant language settings',
      'TalkBack, large text, and increased display size',
      'An upload is not approval',
      'App approval is not App Actions approval',
      'App Actions approval is not FocusHaven distribution authorization',
    ]) {
      expect(normalizedReview, contains(required), reason: required);
    }
  });
}
