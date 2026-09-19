import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const contractPath =
      'docs/contracts/android_system_assistant_app_actions_registration_v1.json';

  Map<String, dynamic> readContract() =>
      jsonDecode(File(contractPath).readAsStringSync()) as Map<String, dynamic>;

  test('retained registration maps exactly the five historical routes', () {
    final contract = readContract();
    final mapping =
        jsonDecode(
              File(
                contract['mappingReviewContract'] as String,
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final registrationRoutes = (contract['routes'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final reviewedRoutes = (mapping['routes'] as List<dynamic>)
        .cast<Map<String, dynamic>>();

    expect(contract['schemaVersion'], 1);
    expect(
      contract['contract'],
      'focus_haven_phase217k_android_app_actions_registration_v1',
    );
    expect(contract['mappingReviewCommit'], isNotEmpty);
    expect(registrationRoutes, hasLength(5));
    expect(
      registrationRoutes.map((route) => route['route']).toList(),
      reviewedRoutes.map((route) => route['route']).toList(),
    );
    expect(
      registrationRoutes.map((route) => route['capabilityId']).toList(),
      reviewedRoutes.map((route) => route['capabilityId']).toList(),
    );
    expect(
      registrationRoutes.map((route) => route['fulfillmentAction']).toList(),
      reviewedRoutes.map((route) => route['fulfillmentAction']).toList(),
    );
  });

  test('shortcuts resource has four custom capabilities and one queue BII', () {
    final shortcuts = File(
      'android/app/src/main/res/xml/shortcuts.xml',
    ).readAsStringSync();
    final capabilities = RegExp(r'<capability(?:\s|>)').allMatches(shortcuts);

    expect(capabilities, hasLength(5));
    for (final capability in <String>[
      'custom.actions.intent.REVIEW_FOCUS_TIMER_STATUS',
      'custom.actions.intent.REVIEW_START_FOCUS_TIMER',
      'custom.actions.intent.REVIEW_PAUSE_FOCUS_TIMER',
      'custom.actions.intent.REVIEW_RESUME_FOCUS_TIMER',
      'actions.intent.OPEN_APP_FEATURE',
    ]) {
      expect(shortcuts, contains('android:name="$capability"'));
    }
    expect(RegExp(r'app:queryPatterns=').allMatches(shortcuts), hasLength(4));
    expect(
      RegExp(
        r'android:targetClass="com\.focushaven\.app\.MainActivity"',
      ).allMatches(shortcuts),
      hasLength(5),
    );
    expect(shortcuts, contains('android:shortcutId="focus_queue_review"'));
    expect(shortcuts, contains('app:shortcutMatchRequired="true"'));
    expect(shortcuts, isNot(contains('<url-template')));
    expect(shortcuts, isNot(contains('android:data=')));
  });

  test(
    'custom query patterns link from default resources with en-US scope',
    () {
      final queryFiles = Directory('android/app/src/main/res')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (file) => file.path.endsWith(
              'android_system_assistant_app_action_queries.xml',
            ),
          )
          .toList(growable: false);

      expect(queryFiles, hasLength(1));
      expect(queryFiles.single.path, contains('/values/'));
      final queries = queryFiles.single.readAsStringSync();
      expect(RegExp(r'<string-array ').allMatches(queries), hasLength(4));
      expect(RegExp(r'<item>').allMatches(queries), hasLength(4));
      expect(queries, isNot(contains('{')));
      expect(queries, isNot(contains('%')));
    },
  );

  test('discovery is detached; dependency and review fulfillment remain', () {
    final contract = readContract();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/com/focushaven/app/MainActivity.kt',
    ).readAsStringSync();

    // This is the unchanged historical Phase 217K record, not current enablement.
    expect(contract['registrationSourceEnabled'], isTrue);
    expect(manifest, isNot(contains('android.app.shortcuts')));
    expect(manifest, isNot(contains('@xml/shortcuts')));
    expect(gradle, contains('androidx.core:core:1.17.0'));
    expect(activity, contains('override fun onCreate'));
    expect(activity, contains('override fun onNewIntent'));
    expect(
      activity,
      contains('resolveSystemAssistantAndroidAppAction(assistantInput)'),
    );
    expect(
      activity,
      contains('Intent(Intent.ACTION_MAIN).setPackage(packageName)'),
    );
  });

  test(
    'no app variant advertises deferred external Assistant capabilities',
    () {
      final manifests = Directory('android/app/src')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('/AndroidManifest.xml'));
      expect(manifests, isNotEmpty);
      for (final file in manifests) {
        final source = file.readAsStringSync();
        for (final forbidden in [
          'android.app.shortcuts',
          '@xml/shortcuts',
          'actions.intent.',
          'com.focushaven.app.action.REVIEW_',
        ]) {
          expect(source, isNot(contains(forbidden)), reason: file.path);
        }
      }
    },
  );

  test('retained code does not publish dynamic Assistant shortcuts', () {
    final sources =
        [
          ...Directory('android/app/src/main').listSync(recursive: true),
          ...Directory('lib').listSync(recursive: true),
        ].whereType<File>().where(
          (file) => ['.kt', '.java', '.dart'].any(file.path.endsWith),
        );
    for (final file in sources) {
      final source = file.readAsStringSync();
      for (final forbidden in [
        'setDynamicShortcuts(',
        'addDynamicShortcuts(',
        'pushDynamicShortcut(',
        'requestPinShortcut(',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: file.path);
      }
    }
  });

  test('capture precedes plugins and replay intent is cleared', () {
    final activity = File(
      'android/app/src/main/kotlin/com/focushaven/app/MainActivity.kt',
    ).readAsStringSync();
    for (final signature in [
      'override fun onCreate(savedInstanceState: Bundle?)',
      'override fun onNewIntent(intent: Intent)',
    ]) {
      final start = activity.indexOf(signature);
      expect(start, greaterThanOrEqualTo(0));
      final end = activity.indexOf('\n    }', start);
      final body = activity.substring(start, end);
      final capture = body.indexOf(
        'val assistantInput = captureSystemAssistantAndroidAppAction(intent)',
      );
      final initialize = body.indexOf('super.');
      final resolve = body.indexOf(
        'resolveSystemAssistantAndroidAppAction(assistantInput)',
      );
      expect(capture, greaterThanOrEqualTo(0));
      expect(initialize, greaterThan(capture));
      expect(resolve, greaterThan(initialize));
    }
    expect(activity, contains('input.submitTo('));
    expect(
      activity,
      contains('setIntent(Intent(Intent.ACTION_MAIN).setPackage(packageName))'),
    );
    expect(activity, isNot(contains('private val assistantInput')));
    expect(activity, isNot(contains('private var assistantInput')));
    expect(activity, isNot(contains('PROXY_PACKAGE')));
  });

  test(
    'resolver rejects unreviewed inputs and submits no Assistant values',
    () {
      final resolver = File(
        'android/app/src/main/kotlin/com/focushaven/app/'
        'HavenSystemAssistantAndroidAppActionResolver.kt',
      ).readAsStringSync();
      final ingress = File(
        'android/app/src/main/kotlin/com/focushaven/app/'
        'HavenSystemAssistantAndroidIngress.kt',
      ).readAsStringSync();

      for (final required in <String>[
        'routeByAction[action] ?: return',
        'hasData || hasClipData || hasSelector',
        'extras.size == 1',
        'extras.isEmpty()',
        'extras[FEATURE_EXTRA] == FOCUS_QUEUE_REVIEW_ID',
        'HavenSystemAssistantAndroidRequest.create(invocationId, route)',
        'store.submit(route, invocationId)',
      ]) {
        expect(resolver, contains(required), reason: required);
      }
      expect(ingress, contains('mapOf('));
      for (final key in ['schemaVersion', 'invocationId', 'kind']) {
        expect(ingress, contains('"$key"'));
      }
      for (final forbidden in <String>[
        'HavenActionEngine',
        'TimerService',
        'FocusQueueService',
        'transcript',
        'utterance',
        'durationSeconds',
        'taskTitle',
      ]) {
        expect(resolver, isNot(contains(forbidden)), reason: forbidden);
      }
    },
  );

  test('preview, release, settlement, and execution remain closed', () {
    final contract = readContract();
    for (final key in <String>[
      'assistantPreviewCreated',
      'signedBuildCreated',
      'realDeviceValidated',
      'playDisclosureValidated',
      'distributionAuthorized',
      'reviewSettlementEnabled',
      'havenActionExecutionEnabled',
    ]) {
      expect(contract[key], isFalse, reason: key);
    }
    expect(contract['requestPayloadKeys'], [
      'schemaVersion',
      'invocationId',
      'kind',
    ]);
    final inventory =
        contract['openAppFeatureInventory'] as Map<String, dynamic>;
    expect(inventory['acceptedExtraValue'], 'focus_queue_review');
    expect(inventory['copiedIntoRequest'], isFalse);
  });
}
