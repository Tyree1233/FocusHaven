import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('client source logs only through the privacy-safe boundary', () {
    final offenders = <String>[];
    final consoleCall = RegExp(r'\b(?:debugPrint|print)\s*\(');

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final normalizedPath = entity.path.replaceAll('\\', '/');
      if (normalizedPath.endsWith(
        'lib/services/privacy_safe_diagnostics.dart',
      )) {
        continue;
      }
      if (consoleCall.hasMatch(entity.readAsStringSync())) {
        offenders.add(normalizedPath);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Use PrivacySafeDiagnostics instead of a direct console call. '
          'Direct output can expose private exception or user content.',
    );
  });

  test('client dependencies contain no crash-reporting SDK', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    const forbiddenPackages = <String>[
      'firebase_crashlytics',
      'sentry_flutter',
      'bugsnag_flutter',
      'instabug_flutter',
      'datadog_flutter_plugin',
      'newrelic_mobile',
      'rollbar_flutter',
    ];

    for (final package in forbiddenPackages) {
      expect(
        pubspec,
        isNot(matches(RegExp('^\\s*$package\\s*:', multiLine: true))),
        reason:
            '$package requires a separate product, privacy, retention, and '
            'release review before it may be added.',
      );
    }
  });
}
