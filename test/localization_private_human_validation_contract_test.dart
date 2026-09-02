import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/focus_haven_locales.dart';

void main() {
  test('C2D records complete anonymous validation with exact locks', () {
    final record = _json(
      'localization/reviews/es/private-human-validation.json',
    );
    final qualification = _json('localization/reviews/es/qualification.json');

    expect(record['phase'], '215G-C2D');
    expect(record['status'], 'private_human_validation_complete');
    expect(record['messageCount'], 980);
    expect(record['decisionCounts'], {
      'accepted': 980,
      'revised': 0,
      'blocked': 0,
    });
    expect(record['sourceMutationCount'], 0);
    expect(record['invalidDecisionCount'], 0);
    expect(record['placeholderMismatchCount'], 0);
    expect(record['personalDataIncluded'], isFalse);
    expect(record['candidateChanged'], isFalse);

    expect(qualification['privateHumanValidationPhase'], '215G-C2D');
    expect(qualification['privateHumanValidationComplete'], isTrue);
    expect(qualification['privateHumanValidationMessageCount'], 980);
    expect(
      qualification['privateHumanValidationDecisionCounts'],
      record['decisionCounts'],
    );
    expect(
      qualification['privateHumanValidationPersonalDataIncluded'],
      isFalse,
    );
    expect(
      qualification['privateHumanValidationRecordSha256'],
      _sha256('localization/reviews/es/private-human-validation.json'),
    );
  });

  test('C2D proof contains no reviewer or contact information', () {
    final record = _json(
      'localization/reviews/es/private-human-validation.json',
    );
    final keys = _allKeys(record).map((key) => key.toLowerCase()).toSet();

    for (final forbidden in [
      'reviewer',
      'name',
      'email',
      'phone',
      'address',
      'contact',
      'employer',
      'signature',
      'payment',
      'workbook',
      'metadata',
      'note',
      'completedat',
    ]) {
      expect(
        keys.where((key) => key.contains(forbidden)),
        isEmpty,
        reason: 'The private proof must not contain $forbidden data.',
      );
    }

    expect(
      File('localization/intake/es/reviewer-assignment.json').existsSync(),
      isFalse,
    );
    expect(
      File('localization/reviews/es/reviewer-assignment.json').existsSync(),
      isFalse,
    );
  });

  test('C2D proof remains valid while production stays English-only', () {
    final record = _json(
      'localization/reviews/es/private-human-validation.json',
    );
    final docs = [
      File('README.md').readAsStringSync(),
      File('docs/LOCALIZATION_AND_GLOBAL_RELEASE_POLICY.md').readAsStringSync(),
      File('docs/LOCALIZATION_PRIVATE_HUMAN_VALIDATION.md').readAsStringSync(),
      File('docs/LOCALIZATION_TRANSLATION_QUALIFICATION.md').readAsStringSync(),
      File('docs/PRODUCT_ROADMAP.md').readAsStringSync(),
    ].map(_normalize).join(' ');

    expect(record['runtimeActivated'], isFalse);
    expect(record['voiceAndCoachingQualified'], isFalse);
    expect(record['nativeAndStoreQualified'], isFalse);
    expect(File('lib/l10n/app_es.arb').existsSync(), isTrue);
    expect(FocusHavenLocales.productionLocales, const [Locale('en')]);
    expect(
      FocusHavenLocales.firstTranslationWave.first.status,
      FocusHavenLocaleStatus.integration,
    );
    expect(docs, contains('Phase 215G-C2D'));
    expect(docs, contains('private validation'));
    expect(docs, contains('980'));
    expect(docs, contains('Spanish remains'));
    expect(docs, contains('runtime inactive'));
  });
}

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Set<String> _allKeys(Object? value) {
  final keys = <String>{};
  if (value is Map<String, dynamic>) {
    for (final entry in value.entries) {
      keys.add(entry.key);
      keys.addAll(_allKeys(entry.value));
    }
  } else if (value is List<dynamic>) {
    for (final entry in value) {
      keys.addAll(_allKeys(entry));
    }
  }
  return keys;
}

String _sha256(String path) {
  final result = Process.runSync('shasum', ['-a', '256', path]);
  expect(result.exitCode, 0);
  return result.stdout.toString().trim().split(RegExp(r'\s+')).first;
}

String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ');
