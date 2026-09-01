import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('B4 coaching and voice messages have complete metadata', () {
    final catalog =
        jsonDecode(_read('lib/l10n/app_en.arb')) as Map<String, dynamic>;
    const requiredKeys = <String>{
      'voiceKeepTyping',
      'voiceContinueToMicrophone',
      'voiceDiscard',
      'voiceDismissNotice',
      'voiceRecognitionUnavailableOnDevice',
      'voiceAccessNotGranted',
      'voiceRecognitionDidNotStart',
      'voiceTranscriptionCouldNotStart',
      'voiceTranscriptionStoppedUnexpectedly',
      'voiceRecognitionUnavailableNow',
      'voiceTranscriptionStoppedReviewOrRetry',
      'coachTitle',
      'coachSubtitleEnhanced',
      'coachSubtitlePrivate',
      'coachClearConversationTooltip',
      'coachCloseTooltip',
      'coachEnhancedTitle',
      'coachEnhancedOnDescription',
      'coachEnhancedOffDescription',
      'coachRetryResponse',
      'coachVoiceListening',
      'coachVoicePreparing',
      'coachVoiceStop',
      'coachInputHint',
      'coachVoiceStopTooltip',
      'coachVoiceDictateTooltip',
      'coachSendTooltip',
      'coachCareBoundary',
      'coachEmptyHeadline',
      'coachEmptyDescription',
      'coachSuggestedRepliesSemantics',
      'coachUserLabel',
      'coachThinkingSemantics',
      'coachThinking',
      'coachResponseFailed',
      'coachVoiceDisclosureTitle',
      'coachVoiceDisclosureMessage',
      'coachClearConversationTitle',
      'coachClearConversationMessage',
      'coachKeepConversation',
      'coachClearConversation',
      'coachEnhancedDisclosureTitle',
      'coachEnhancedDisclosureMessage',
      'coachEnhancedKeepLocal',
      'coachEnhancedEnable',
      'coachPromptHelpMeStart',
      'coachPromptOverwhelmed',
      'coachPromptWhatNext',
      'coachPromptThinkThrough',
      'coachPromptGentle',
      'coachPromptListen',
      'coachPromptAccountability',
      'coachReplyBackAfterBreak',
      'coachReplyDidFirstStep',
      'coachReplyStillStuck',
      'coachReplyNeedBreak',
      'coachReplyBreakItDown',
      'havenActionTitle',
      'havenActionCloseTooltip',
      'havenActionIntroduction',
      'havenActionPrivateBoundary',
      'havenActionVoiceDisclosureTitle',
      'havenActionVoiceDisclosureMessage',
      'havenActionVoiceListening',
      'havenActionVoicePreparing',
      'havenActionVoiceReady',
      'havenActionVoiceStop',
      'havenActionInputLabel',
      'havenActionInputHint',
      'havenActionVoiceStopTooltip',
      'havenActionVoiceDictateTooltip',
      'havenActionReview',
      'havenActionSourceVoice',
      'havenActionSourceTyped',
      'havenActionChangeRequest',
      'havenActionWorking',
      'havenActionConfirmExact',
      'havenActionRunReviewed',
      'havenActionExamples',
      'havenActionSemanticsSourceVoice',
      'havenActionSemanticsSourceTyped',
      'havenActionSemanticsNextConfirm',
      'havenActionSemanticsNextRun',
      'havenActionRiskInformational',
      'havenActionRiskReversible',
      'havenActionRiskStateful',
      'havenActionProposalSemantics',
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

    final proposalMetadata =
        catalog['@havenActionProposalSemantics'] as Map<String, dynamic>;
    final placeholders =
        proposalMetadata['placeholders'] as Map<String, dynamic>;
    expect(
      placeholders.keys.toSet(),
      equals({'source', 'interpretation', 'effect', 'risk', 'nextStep'}),
    );
  });

  test('B4 production sheets use generated localization access', () {
    final coach = _read('lib/widgets/coaching_sheet.dart');
    final action = _read('lib/widgets/haven_action_sheet.dart');
    final combined = '$coach\n$action';

    for (final getter in <String>[
      'coachTitle',
      'coachEnhancedDisclosureMessage',
      'coachVoiceDisclosureMessage',
      'coachInputHint',
      'coachCareBoundary',
      'coachSuggestedRepliesSemantics',
      'havenActionTitle',
      'havenActionVoiceDisclosureMessage',
      'havenActionPrivateBoundary',
      'havenActionInputHint',
      'havenActionConfirmExact',
      'havenActionProposalSemantics',
    ]) {
      expect(combined, contains(getter), reason: getter);
    }

    for (final stale in <String>[
      "'Focus Coach'",
      "'Clear conversation'",
      "'Dictate coaching message'",
      "'Enhanced AI'",
      "'Haven action'",
      "'Review action'",
      "'Confirm exact action'",
      "'Nothing runs from speech alone.'",
    ]) {
      expect(combined, isNot(contains(stale)), reason: 'stale literal: $stale');
    }
  });

  test(
    'B4 localizes stable voice notice codes without changing recognition',
    () {
      final service = _read('lib/services/voice_transcription_service.dart');
      final mapper = _read('lib/l10n/voice_transcription_localizations.dart');
      final coach = _read('lib/widgets/coaching_sheet.dart');
      final action = _read('lib/widgets/haven_action_sheet.dart');

      for (final value in <String>[
        'recognitionUnavailableOnDevice',
        'accessNotGranted',
        'recognitionDidNotStart',
        'transcriptionCouldNotStart',
        'stoppedUnexpectedly',
        'recognitionUnavailableNow',
        'stoppedReviewOrRetry',
      ]) {
        expect(service, contains('VoiceTranscriptionNotice.$value'));
        expect(mapper, contains('VoiceTranscriptionNotice.$value'));
      }

      expect(service, contains('VoiceTranscriptionNotice? get noticeCode'));
      expect(service, contains('String? get notice => switch (_noticeCode)'));
      expect(service, isNot(contains('context.l10n')));
      expect(coach, contains('voiceState.noticeCode'));
      expect(action, contains('voice.noticeCode'));
      expect(coach, contains('localizeVoiceTranscriptionNotice'));
      expect(action, contains('localizeVoiceTranscriptionNotice'));
      expect(coach, isNot(contains('Text(voiceState.notice!)')));
      expect(action, isNot(contains('Text(voice.notice!)')));
    },
  );

  test('B4 keeps private and service-generated values opaque', () {
    final coach = _read('lib/widgets/coaching_sheet.dart');
    final action = _read('lib/widgets/haven_action_sheet.dart');

    expect(coach, contains('message.text'));
    expect(coach, contains('coachingState.errorMessage'));
    expect(action, contains('proposal.interpretation'));
    expect(action, contains('proposal.effect'));

    for (final service in <String>[
      'lib/services/coaching_service.dart',
      'lib/services/haven_action_interpreter.dart',
      'lib/services/haven_action_engine.dart',
    ]) {
      final source = _read(service);
      expect(source, isNot(contains('context.l10n')), reason: service);
      expect(
        source,
        isNot(contains('focus_haven_localizations.dart')),
        reason: service,
      );
    }
  });

  test('B4 scope is truthful and planned locales remain inactive', () {
    final inventory = _normalize(
      _read('docs/LOCALIZATION_EXTRACTION_INVENTORY.md'),
    );
    final policy = _normalize(
      _read('docs/LOCALIZATION_AND_GLOBAL_RELEASE_POLICY.md'),
    );
    final roadmap = _normalize(_read('docs/PRODUCT_ROADMAP.md'));
    final readme = _normalize(_read('README.md'));
    final locales = _read('lib/l10n/focus_haven_locales.dart');

    for (final required in <String>[
      'B4 — Coaching and voice',
      'production sheets map `noticeCode` through the generated catalog',
      'User-authored messages and recognized transcripts remain opaque values',
      'B6 still owns service-generated user-facing text',
      'B4 records no audio, contacts no local or remote AI',
      'B6 remains required',
    ]) {
      expect(inventory, contains(required));
    }
    expect(policy, contains('Phase 215G-B4'));
    expect(policy, contains('B6 remains required'));
    expect(roadmap, contains('Phase 215G-B1/B2/B3A/B3B/B3C/B4/B5 extraction'));
    expect(roadmap, contains('remaining B6 extraction slice'));
    expect(readme, contains('Phase 215G-B4'));
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

String _read(String path) => File(path).readAsStringSync();

String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ');
