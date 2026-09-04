import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../tool/localization_streamlined_batch.dart';

const _sourceDigest =
    'ba6e97b200060f211d3e0d73276e1132e03c8de18ac0778d38c356abe9874e87';

void main() {
  test(
    'parses a bounded multi-locale manifest with independent identities',
    () {
      final manifest = _manifest();

      expect(manifest.maxParallelism, 2);
      expect(manifest.locales.map((entry) => entry.locale), ['de', 'pt-BR']);
      expect(manifest.locales.last.arbLocale, 'pt_BR');
      expect(
        manifest.locales.last.runtimeCatalogPath,
        'lib/l10n/app_pt_BR.arb',
      );
    },
  );

  test('rejects duplicate locales and unexpected manifest fields', () {
    final duplicate = _manifestJson();
    duplicate['locales'] = [
      (duplicate['locales'] as List).first,
      (duplicate['locales'] as List).first,
    ];
    expect(
      () => StreamlinedLocaleBatchManifest.fromJson(duplicate),
      throwsFormatException,
    );

    final unexpected = _manifestJson()..['reviewerName'] = 'Private Person';
    expect(
      () => StreamlinedLocaleBatchManifest.fromJson(unexpected),
      throwsFormatException,
    );
  });

  test('builds deterministic private paths for each batch operation', () {
    final german = _manifest().locales.first;

    expect(
      streamlinedLocaleBatchArguments(
        operation: StreamlinedLocaleBatchOperation.init,
        entry: german,
      ),
      ['init', 'de', 'German', 'Deutsch', 'general_german'],
    );
    expect(
      streamlinedLocaleBatchArguments(
        operation: StreamlinedLocaleBatchOperation.prepare,
        entry: german,
        translationBundleDirectory: '/private/bundles',
        privateReviewDirectory: '/private/reviews',
      ),
      [
        'prepare',
        'localization/plans/de.json',
        '/private/bundles/focushaven-de-translations.json',
        '/private/reviews/focushaven-de-review.csv',
      ],
    );
    expect(
      streamlinedLocaleBatchArguments(
        operation: StreamlinedLocaleBatchOperation.accept,
        entry: german,
        privateReviewDirectory: '/private/reviews',
      ),
      [
        'accept',
        'localization/plans/de.json',
        '/private/reviews/focushaven-de-review.csv',
      ],
    );
    expect(
      streamlinedLocaleBatchArguments(
        operation: StreamlinedLocaleBatchOperation.verify,
        entry: german,
      ),
      ['verify', 'localization/plans/de.json'],
    );
  });

  test(
    'runs locales concurrently while isolating one locale failure',
    () async {
      final calls = <String>[];
      var active = 0;
      var peakActive = 0;
      final firstTwoStarted = Completer<void>();

      final result = await runStreamlinedLocaleBatch(
        manifest: _manifest(),
        operation: StreamlinedLocaleBatchOperation.init,
        commandRunner: (arguments) async {
          calls.add(arguments[1]);
          active += 1;
          if (active > peakActive) peakActive = active;
          if (calls.length == 2 && !firstTwoStarted.isCompleted) {
            firstTwoStarted.complete();
          }
          await firstTwoStarted.future;
          active -= 1;
          return StreamlinedLocaleBatchCommandResult(
            exitCode: arguments[1] == 'de' ? 65 : 0,
            stdout: '${arguments[1]} output',
            stderr: arguments[1] == 'de' ? 'German failed' : '',
          );
        },
      );

      expect(calls, containsAll(['de', 'pt-BR']));
      expect(peakActive, 2);
      expect(result.passed, isFalse);
      expect(result.passedCount, 1);
      expect(result.failedCount, 1);
      expect(result.items.map((item) => item.locale), ['de', 'pt-BR']);
      expect(result.items.first.passed, isFalse);
      expect(result.items.last.passed, isTrue);
      expect(result.toJson(), containsPair('failedCount', 1));
    },
  );
}

StreamlinedLocaleBatchManifest _manifest() =>
    StreamlinedLocaleBatchManifest.fromJson(_manifestJson());

Map<String, dynamic> _manifestJson() => {
  'schemaVersion': 1,
  'workflow': streamlinedLocaleBatchWorkflow,
  'sourceCatalog': 'lib/l10n/app_en.arb',
  'sourceCatalogSha256': _sourceDigest,
  'maxParallelism': 2,
  'locales': [
    {
      'locale': 'de',
      'englishName': 'German',
      'nativeName': 'Deutsch',
      'reviewScope': 'general_german',
    },
    {
      'locale': 'pt-BR',
      'englishName': 'Brazilian Portuguese',
      'nativeName': 'Português (Brasil)',
      'reviewScope': 'brazilian_portuguese',
    },
  ],
};
