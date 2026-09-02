import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/focus_haven_locales.dart';

import '../tool/localization_catalog_qualification.dart';

const _approvedSourceEqual = <String>{
  'appTitle',
  'durationMinutesShort',
  'havenWindowHeldSameDay',
  'havenWindowHeldMultiDay',
  'accountPro',
  'proTitle',
  'journalMoodCount',
  'reminderDaySeparator',
  'reminderTimeAndDays',
  'timerServiceExportSessionRow',
  'havenPlanServiceExplanationWithDetails',
};

void main() {
  test('C1B candidate passes the complete structural audit', () {
    final source = _json('lib/l10n/app_en.arb');
    final candidate = _json('localization/candidates/app_es.arb');
    final review = _json('localization/reviews/es/qualification.json');
    final evidence = _json('localization/reviews/es/structural-audit.json');

    final result = auditLocalizationCandidate(
      source: source,
      candidate: candidate,
      approvedSourceEqualKeys: _approvedSourceEqual,
    );

    expect(result.sourceMessageCount, 980);
    expect(result.sourcePlaceholderMessageCount, 148);
    expect(result.missingMessages, isEmpty);
    expect(result.extraMessages, isEmpty);
    expect(result.missingSourceMetadata, isEmpty);
    expect(result.missingCandidateMetadata, isEmpty);
    expect(result.placeholderSchemaMismatches, isEmpty);
    expect(result.icuPlaceholderMismatches, isEmpty);
    expect(result.emptyTranslations, isEmpty);
    expect(result.sourceEqualTranslations, isEmpty);
    expect(result.readyForHumanReview(expectedCandidateLocale: 'es'), isTrue);
    expect(review['status'], 'structurally_ready');
    expect(
      review['candidateCatalogSha256'],
      evidence['candidateCatalogSha256'],
    );
    expect(
      review['candidateCatalogSha256'],
      '611d1afcc6eb688f92d56928f08cad5dbfdef2b5031c537c53615accfb16b83f',
    );
    expect(evidence['readyForHumanReview'], isTrue);
    expect(evidence['approvedSourceEqual'], hasLength(11));
  });

  test('ICU branch copy is translated without inventing placeholders', () {
    final candidate = _json('localization/candidates/app_es.arb');
    expect(
      candidate['coachServiceDistractionParkingSaved'],
      'Ya tienes {count} {count, plural, =1 {pensamiento apartado} other {pensamientos apartados}}; deja que permanezcan seguros mientras vuelves.',
    );
  });

  test('Spanish remains planned, inactive, and outside runtime catalogs', () {
    final review = _json('localization/reviews/es/qualification.json');
    final evidence = _json('localization/reviews/es/structural-audit.json');

    expect(FocusHavenLocales.productionLocales, const [Locale('en')]);
    expect(
      FocusHavenLocales.firstTranslationWave.first.status,
      FocusHavenLocaleStatus.integration,
    );
    expect(File('localization/candidates/app_es.arb').existsSync(), isTrue);
    expect(File('lib/l10n/app_es.arb').existsSync(), isTrue);
    expect(review['humanReviewRequired'], isTrue);
    expect(review['humanReviewer'], isNull);
    expect(review['approvedAt'], isNull);
    expect(review['linguisticallyApproved'], isFalse);
    expect(review['runtimeActivated'], isFalse);
    expect(review['voiceAndCoachingQualified'], isFalse);
    expect(review['nativeAndStoreQualified'], isFalse);
    expect(evidence['externalTranslationProviderUsed'], isFalse);
    expect(evidence['privateRuntimeDataUsed'], isFalse);
  });

  test(
    'C1B documentation does not turn structural readiness into approval',
    () {
      final preparation = _normalize(
        File(
          'docs/LOCALIZATION_SPANISH_CANDIDATE_PREPARATION.md',
        ).readAsStringSync(),
      );
      final qualification = _normalize(
        File(
          'docs/LOCALIZATION_TRANSLATION_QUALIFICATION.md',
        ).readAsStringSync(),
      );
      final worksheet = _normalize(
        File(
          'docs/LOCALIZATION_SPANISH_REVIEW_WORKSHEET.md',
        ).readAsStringSync(),
      );

      for (final required in <String>[
        'structurally ready for qualified human review only',
        'No external translation provider or private runtime data was used',
        'Spanish remains planned and inactive',
        'not qualified human approval or locale activation',
      ]) {
        expect(preparation, contains(required), reason: required);
      }
      expect(qualification, contains('No qualified human review has started'));
      expect(worksheet, contains('Final linguistic decision | Not approved'));
    },
  );
}

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ');
