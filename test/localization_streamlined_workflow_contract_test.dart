import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('streamlined workflow keeps private review and activation separate', () {
    final tool = File(
      'tool/localization_streamlined_pipeline.dart',
    ).readAsStringSync();
    final policy = File(
      'docs/LOCALIZATION_STREAMLINED_LOCALE_WORKFLOW.md',
    ).readAsStringSync();

    for (final command in ['init', 'prepare', 'accept', 'verify']) {
      expect(tool, contains("case '$command':"));
      expect(policy, contains(command));
    }
    expect(tool, contains('_requirePrivatePath(reviewPath)'));
    expect(
      tool,
      contains('The private review worksheet must remain outside Git.'),
    );
    expect(tool, isNot(contains('reviewerName')));
    expect(tool, isNot(contains('reviewerEmail')));
    expect(tool, isNot(contains('git push')));
    expect(tool, isNot(contains('productionLocales.add')));
    expect(
      policy,
      contains('one locale commit, push it once, and verify its CI once'),
    );
    expect(
      policy,
      contains('A safely unavailable optional feature does not block'),
    );
  });

  test('production picker is derived from the locale registry', () {
    final picker = File('lib/widgets/appearance_sheet.dart').readAsStringSync();
    final service = File('lib/services/locale_service.dart').readAsStringSync();

    expect(picker, contains('...FocusHavenLocales.production.map('));
    expect(picker, contains('FocusHavenLanguageChoice.forDefinition('));
    expect(service, contains('...FocusHavenLocales.production.map('));
    expect(service, contains('definition.languageTag'));
  });
}
