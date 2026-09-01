import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('B6C1 Haven action service catalog has complete metadata', () {
    final catalog =
        jsonDecode(_read('lib/l10n/app_en.arb')) as Map<String, dynamic>;
    const requiredKeys = <String>{
      'havenActionServiceUnsupportedSource',
      'havenActionServiceEmptyRequest',
      'havenActionServiceRequestTooLong',
      'havenActionServiceProtectedAction',
      'havenActionServiceMultipleActions',
      'havenActionServiceUnsupportedAction',
      'havenActionServiceTimerStatusInterpretation',
      'havenActionServiceTimerStatusEffect',
      'havenActionServiceStartTimerInterpretation',
      'havenActionServiceStartTimerEffect',
      'havenActionServicePauseTimerInterpretation',
      'havenActionServicePauseTimerEffect',
      'havenActionServiceResumeTimerInterpretation',
      'havenActionServiceResumeTimerEffect',
      'havenActionServiceAddTimePrompt',
      'havenActionServiceAddedTimeInvalid',
      'havenActionServiceAddTimeInterpretation',
      'havenActionServiceAddTimeEffect',
      'havenActionServiceOpenInterpretation',
      'havenActionServiceOpenEffect',
      'havenActionServiceQueueItemInvalid',
      'havenActionServiceQueueItemInterpretation',
      'havenActionServiceQueueItemEffect',
      'havenActionServiceSessionFocus',
      'havenActionServiceSessionShortBreak',
      'havenActionServiceSessionLongBreak',
      'havenActionServiceActivityReady',
      'havenActionServiceActivityRunning',
      'havenActionServiceActivityPaused',
      'havenActionServiceActivityPendingResume',
      'havenActionServiceActivityCompleted',
      'havenActionServiceSurfaceFocusQueue',
      'havenActionServiceSurfaceHavenPlan',
      'havenActionServiceSurfaceSmartReset',
      'havenActionServiceSurfaceLocalCoach',
      'havenActionServiceSurfaceSettings',
      'havenActionServiceInvalidProposal',
      'havenActionServiceInvalidProposalTime',
      'havenActionServiceExpiredProposal',
      'havenActionServiceStaleProposal',
      'havenActionServicePauseUnavailable',
      'havenActionServiceResumeUnavailable',
      'havenActionServiceStartUnavailable',
      'havenActionServiceAddTimeUnavailable',
      'havenActionServiceTimerLimitExceeded',
      'havenActionServiceHavenPlanUnavailable',
      'havenActionServiceSmartResetUnavailable',
      'havenActionServiceQueueItemInvalidProposal',
      'havenActionServiceDuplicateProposal',
      'havenActionServiceConfirmationRequired',
      'havenActionServiceConfirmationMismatch',
      'havenActionServiceRejected',
      'havenActionServiceFailure',
      'havenActionServiceTimerStarted',
      'havenActionServiceTimerPaused',
      'havenActionServiceTimerResumed',
      'havenActionServiceTimeAdded',
      'havenActionServiceSurfaceOpened',
      'havenActionServiceQueueItemAdded',
    };

    for (final key in requiredKeys) {
      expect(catalog[key], isA<String>(), reason: 'missing message: $key');
      final metadata = catalog['@$key'];
      expect(metadata, isA<Map<String, dynamic>>(), reason: 'metadata: $key');
      expect(
        (metadata as Map<String, dynamic>)['description'],
        isNotEmpty,
        reason: 'description: $key',
      );
    }

    expect(_placeholderKeys(catalog, 'havenActionServiceTimerStatusEffect'), {
      'session',
      'activity',
      'time',
    });
    expect(
      _placeholderKeys(catalog, 'havenActionServiceStartTimerInterpretation'),
      {'session'},
    );
    expect(
      _placeholderKeys(catalog, 'havenActionServiceAddTimeInterpretation'),
      {'minutes'},
    );
    expect(_placeholderKeys(catalog, 'havenActionServiceOpenEffect'), {
      'surface',
    });
    expect(_placeholderKeys(catalog, 'havenActionServiceQueueItemEffect'), {
      'title',
    });
  });

  test('B6C1 interpreter policy and engine use catalog-owned output', () {
    const paths = <String>[
      'lib/services/haven_action_interpreter.dart',
      'lib/services/haven_action_policy.dart',
      'lib/services/haven_action_engine.dart',
    ];
    final combined = paths.map(_read).join('\n');

    for (final path in paths) {
      final source = _read(path);
      expect(source, contains("import '../l10n/app_localizations.dart';"));
      expect(source, contains("import '../l10n/service_localizations.dart';"));
      expect(source, contains('AppLocalizations? localizations'));
      expect(
        source,
        contains('localizations ?? defaultServiceLocalizations()'),
      );
    }

    for (final getter in <String>[
      'havenActionServiceUnsupportedSource',
      'havenActionServiceTimerStatusEffect',
      'havenActionServiceQueueItemEffect',
      'havenActionServiceInvalidProposal',
      'havenActionServiceStaleProposal',
      'havenActionServiceDuplicateProposal',
      'havenActionServiceConfirmationMismatch',
      'havenActionServiceTimerStarted',
      'havenActionServiceQueueItemAdded',
    ]) {
      expect(combined, contains(getter), reason: getter);
    }

    for (final stale in <String>[
      "'That input source cannot create a Haven action proposal.'",
      "'I found more than one action. Please ask for one change at a time.'",
      "'The proposal is invalid. Nothing was changed.'",
      "'That proposal was already handled. Nothing was replayed.'",
      "'The timer started.'",
      "'The reviewed item was added to Focus Queue.'",
    ]) {
      expect(combined, isNot(contains(stale)), reason: stale);
    }
  });

  test('B6C1 presentation paths pass the selected catalog explicitly', () {
    final actionSheet = _read('lib/widgets/haven_action_sheet.dart');
    final plannerAction = _read(
      'lib/services/haven_planner_action_service.dart',
    );
    final plannerSheet = _read('lib/widgets/haven_planner_sheet.dart');

    expect(actionSheet, contains('localizations: context.l10n'));
    expect(actionSheet, contains('final l10n = context.l10n;'));
    expect(actionSheet, contains('localizations: l10n'));
    expect(plannerAction, contains('AppLocalizations? localizations'));
    expect(plannerAction, contains('localizations: localizations'));
    expect(plannerSheet, contains('localizations: context.l10n'));
  });

  test('B6C1 preserves private inputs and action authority boundaries', () {
    final interpreter = _read('lib/services/haven_action_interpreter.dart');
    final policy = _read('lib/services/haven_action_policy.dart');
    final engine = _read('lib/services/haven_action_engine.dart');
    final catalog = _read('lib/l10n/app_en.arb');

    expect(interpreter, contains('maxInputLength = 240'));
    expect(interpreter, contains('maxQueueTitleLength = 100'));
    expect(interpreter, contains('maxAddedMinutes = 60'));
    expect(interpreter, contains('proposalLifetime = Duration(minutes: 2)'));
    expect(interpreter, contains('_containsProtectedRequest'));
    expect(interpreter, contains('HavenActionSource.voiceTranscript'));
    expect(policy, contains('proposal.stateToken != state.token'));
    expect(policy, contains('maxSessionSeconds = 24 * 60 * 60'));
    expect(engine, contains('_consumedProposalIds'));
    expect(engine, contains('proposal.confirmationFingerprint'));
    expect(engine, contains('timer.addTime'));
    expect(engine, contains('focusQueue.add'));
    expect(catalog, isNot(contains('Review the launch checklist')));
    expect(catalog, isNot(contains('Private queue title')));
  });

  test('B6C1 remains partial and planned locales stay inactive', () {
    final inventory = _normalize(
      _read('docs/LOCALIZATION_EXTRACTION_INVENTORY.md'),
    );
    final policy = _normalize(
      _read('docs/LOCALIZATION_AND_GLOBAL_RELEASE_POLICY.md'),
    );
    final roadmap = _normalize(_read('docs/PRODUCT_ROADMAP.md'));
    final readme = _normalize(_read('README.md'));
    final locales = _read('lib/l10n/focus_haven_locales.dart');

    expect(inventory, contains('B6C1 — Haven action service results'));
    expect(inventory, contains('User-authored queue titles remain opaque'));
    expect(inventory, contains('B6C2 — Local-Coach responses and receipts'));
    expect(inventory, contains('B6C3 — Remaining service results'));
    expect(policy, contains('Phase 215G-B6C1'));
    expect(policy, contains('B6 remains required through B6C3'));
    expect(roadmap, contains('B1–B6C1 extraction shipped'));
    expect(roadmap, contains('remaining B6 extraction work is B6C2 and B6C3'));
    expect(readme, contains('Phase 215G-B6C1'));
    expect(
      locales,
      contains("static const productionLocales = <Locale>[Locale('en')]"),
    );
    expect(
      Directory('lib/l10n')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.arb'))
          .length,
      1,
    );
  });
}

Set<String> _placeholderKeys(Map<String, dynamic> catalog, String key) {
  final metadata = catalog['@$key'] as Map<String, dynamic>;
  final placeholders = metadata['placeholders'] as Map<String, dynamic>;
  return placeholders.keys.toSet();
}

String _read(String path) => File(path).readAsStringSync();

String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ');
