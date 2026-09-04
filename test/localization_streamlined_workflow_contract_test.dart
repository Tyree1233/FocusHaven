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

  test('batch workflow reuses isolated single-locale safeguards', () {
    final batchTool = File(
      'tool/localization_streamlined_batch.dart',
    ).readAsStringSync();
    final policy = File(
      'docs/LOCALIZATION_STREAMLINED_LOCALE_WORKFLOW.md',
    ).readAsStringSync();

    for (final command in ['init', 'prepare', 'accept', 'verify']) {
      expect(batchTool, contains('StreamlinedLocaleBatchOperation.$command'));
    }
    expect(batchTool, contains('maxParallelism > 5'));
    expect(batchTool, contains('localesValue.length > 10'));
    expect(batchTool, contains('_requirePrivateDirectory'));
    expect(batchTool, contains("'noLocaleCommandStarted': true"));
    expect(batchTool, contains('isolated locale failures'));
    expect(batchTool, contains(_singleLocalePipelinePath));
    expect(batchTool, isNot(contains('reviewerName')));
    expect(batchTool, isNot(contains('reviewerEmail')));
    expect(batchTool, isNot(contains('git push')));
    expect(batchTool, isNot(contains('productionLocales.add')));
    expect(policy, contains('Batch several independent locales'));
    expect(policy, contains('one private review worksheet per locale'));
    expect(policy, contains('never approves one locale because'));
    expect(policy, contains('another passed.'));
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

const _singleLocalePipelinePath = 'tool/localization_streamlined_pipeline.dart';
