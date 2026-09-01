import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/app_localizations.dart';
import 'package:focushaven/services/coaching_service.dart';

void main() {
  test('B6C2 Local Coach catalog owns every referenced response key', () {
    final catalog =
        jsonDecode(_read('lib/l10n/app_en.arb')) as Map<String, dynamic>;
    final source = _read('lib/services/coaching_service.dart');
    final referencedKeys = RegExp(
      r'(?:l10n|localizations)\.(coachService[A-Za-z0-9_]+)',
    ).allMatches(source).map((match) => match.group(1)!).toSet();
    final catalogKeys = catalog.keys
        .where((key) => key.startsWith('coachService'))
        .toSet();

    expect(referencedKeys, isNotEmpty);
    expect(catalogKeys, equals(referencedKeys));
    for (final key in referencedKeys) {
      expect(catalog[key], isA<String>(), reason: 'missing message: $key');
      final metadata = catalog['@$key'];
      expect(metadata, isA<Map<String, dynamic>>(), reason: 'metadata: $key');
      expect(
        (metadata as Map<String, dynamic>)['description'],
        isNotEmpty,
        reason: 'description: $key',
      );
    }

    expect(_placeholderKeys(catalog, 'coachServiceGentleResponse'), {
      'recognition',
      'task',
    });
    expect(_placeholderKeys(catalog, 'coachServiceAccountabilityResponse'), {
      'task',
      'queueDirection',
      'timerDirection',
    });
    expect(_placeholderKeys(catalog, 'coachServiceGeneralChallengeResponse'), {
      'gentleOpening',
      'personalNote',
      'challenge',
      'task',
    });
  });

  test('B6C2 Local Coach and presentation use the selected catalog', () {
    final service = _read('lib/services/coaching_service.dart');
    final sheet = _read('lib/widgets/coaching_sheet.dart');
    final timer = _read('lib/screens/timer_screen.dart');

    expect(service, contains('AppLocalizations? localizations'));
    expect(service, contains('context.withLocalizations(l10n)'));
    expect(service, contains('defaultServiceLocalizations()'));
    expect(service, contains('fallbackReason?.userMessage(l10n)'));
    expect(sheet, contains('localizations: context.l10n'));
    expect(timer, contains('coach.clearLocalData('));
    expect(timer, contains('localizations: context.l10n'));

    for (final stale in <String>[
      "'Your coach could not respond right now. Please retry.'",
      "'Your enhanced coaching preference could not be saved. Please retry.'",
      "'That sounds like a lot to hold at once. Let’s make the next move '",
      "'Direct version, without shame: commit to “\$task” for ten minutes. '",
    ]) {
      expect(service, isNot(contains(stale)), reason: stale);
    }
  });

  test('B6C2 catalog context remains local and private values stay opaque', () {
    const privateTask = 'Private launch notes';
    const privateProfile = 'Private focus profile';
    const privateMood = 'Private reflection mood';
    final l10n = lookupAppLocalizations(const Locale('en'));
    const context = CoachingContext(
      focusTask: privateTask,
      focusProfile: privateProfile,
      recentMood: privateMood,
    );
    final localized = context.withLocalizations(l10n);
    final promptData = localized.toPromptData();
    final catalog = _read('lib/l10n/app_en.arb');

    expect(localized.localizations, same(l10n));
    expect(promptData['focusTask'], privateTask);
    expect(promptData['focusProfile'], privateProfile);
    expect(promptData['recentMood'], privateMood);
    expect(promptData, isNot(contains('localizations')));
    expect(promptData, isNot(contains('locale')));
    expect(catalog, isNot(contains(privateTask)));
    expect(catalog, isNot(contains(privateProfile)));
    expect(catalog, isNot(contains(privateMood)));
  });

  test('B6C2 preserves English understanding and service boundaries', () {
    final service = _read('lib/services/coaching_service.dart');

    for (final boundary in <String>[
      "'kill myself'",
      "'stop coaching'",
      "'help me think this through'",
      "'need to vent'",
      "'hold me accountable'",
      "'be gentle'",
      'LocalCoachingResponder.isSafetyConcern(message)',
      'LocalCoachingResponder.isBoundaryRequest(message)',
      'LocalCoachingResponder.isRepairRequest(message)',
      '_enhancedCoachingEnabled && _enhancedResponder != null',
      '_maximumMessages = 40',
      '_maximumMessageLength = 800',
    ]) {
      expect(service, contains(boundary), reason: boundary);
    }
  });

  test('B6C2 remains partial and planned locales stay inactive', () {
    final inventory = _normalize(
      _read('docs/LOCALIZATION_EXTRACTION_INVENTORY.md'),
    );
    final policy = _normalize(
      _read('docs/LOCALIZATION_AND_GLOBAL_RELEASE_POLICY.md'),
    );
    final roadmap = _normalize(_read('docs/PRODUCT_ROADMAP.md'));
    final readme = _normalize(_read('README.md'));
    final locales = _read('lib/l10n/focus_haven_locales.dart');

    expect(inventory, contains('B6C2 — Local-Coach responses and receipts'));
    expect(inventory, contains('B6C3 — Remaining service results'));
    expect(policy, contains('Phase 215G-B6C2'));
    expect(policy, contains('B6 remains required through B6C3'));
    expect(roadmap, contains('B1–B6C2 extraction shipped'));
    expect(roadmap, contains('remaining B6 extraction work is B6C3'));
    expect(readme, contains('Phase 215G-B6C2'));
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
