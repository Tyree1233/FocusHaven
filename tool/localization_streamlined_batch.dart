import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'localization_streamlined_pipeline.dart';

const streamlinedLocaleBatchWorkflow =
    'focus_haven_streamlined_locale_batch_v1';
const _singleLocaleTool = 'tool/localization_streamlined_pipeline.dart';

enum StreamlinedLocaleBatchOperation { init, prepare, accept, verify }

final class StreamlinedLocaleBatchEntry {
  const StreamlinedLocaleBatchEntry({
    required this.locale,
    required this.englishName,
    required this.nativeName,
    required this.reviewScope,
  });

  factory StreamlinedLocaleBatchEntry.fromJson(Map<String, dynamic> json) {
    _requireExactKeys(json, const {
      'locale',
      'englishName',
      'nativeName',
      'reviewScope',
    }, 'locale entry');
    final locale = _requiredString(json, 'locale');
    if (!RegExp(r'^[a-z]{2,3}(?:-[A-Z]{2})?$').hasMatch(locale)) {
      throw const FormatException(
        'Batch locale tags must look like de or pt-BR.',
      );
    }
    return StreamlinedLocaleBatchEntry(
      locale: locale,
      englishName: _requiredString(json, 'englishName'),
      nativeName: _requiredString(json, 'nativeName'),
      reviewScope: _requiredString(json, 'reviewScope'),
    );
  }

  final String locale;
  final String englishName;
  final String nativeName;
  final String reviewScope;

  String get planPath => 'localization/plans/$locale.json';

  String get arbLocale => locale.replaceAll('-', '_');

  String get candidatePath => 'localization/candidates/app_$arbLocale.arb';

  String get structuralAuditPath =>
      'localization/reviews/$locale/structural-audit.json';

  String get approvedCatalogPath =>
      'localization/reviews/$locale/app_$arbLocale.approved.arb';

  String get validationRecordPath =>
      'localization/reviews/$locale/private-human-validation.json';

  String get runtimeCatalogPath => 'lib/l10n/app_$arbLocale.arb';

  String translationBundlePath(String directory) =>
      _join(directory, 'focushaven-$locale-translations.json');

  String privateReviewPath(String directory) =>
      _join(directory, 'focushaven-$locale-review.csv');
}

final class StreamlinedLocaleBatchManifest {
  const StreamlinedLocaleBatchManifest({
    required this.sourceCatalog,
    required this.sourceCatalogSha256,
    required this.maxParallelism,
    required this.locales,
  });

  factory StreamlinedLocaleBatchManifest.fromJson(Map<String, dynamic> json) {
    _requireExactKeys(json, const {
      'schemaVersion',
      'workflow',
      'sourceCatalog',
      'sourceCatalogSha256',
      'maxParallelism',
      'locales',
    }, 'batch manifest');
    if (json['schemaVersion'] != 1 ||
        json['workflow'] != streamlinedLocaleBatchWorkflow) {
      throw const FormatException('Unsupported streamlined-locale batch.');
    }
    final sourceCatalog = _requiredString(json, 'sourceCatalog');
    if (sourceCatalog != streamlinedLocaleSourceCatalog) {
      throw FormatException(
        'sourceCatalog must be $streamlinedLocaleSourceCatalog.',
      );
    }
    final sourceCatalogSha256 = _requiredString(json, 'sourceCatalogSha256');
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sourceCatalogSha256)) {
      throw const FormatException(
        'sourceCatalogSha256 must be a lowercase SHA-256 digest.',
      );
    }
    final maxParallelism = json['maxParallelism'];
    if (maxParallelism is! int || maxParallelism < 1 || maxParallelism > 5) {
      throw const FormatException('maxParallelism must be from 1 through 5.');
    }
    final localesValue = json['locales'];
    if (localesValue is! List ||
        localesValue.isEmpty ||
        localesValue.length > 10) {
      throw const FormatException(
        'A batch must contain between 1 and 10 locales.',
      );
    }
    final locales = <StreamlinedLocaleBatchEntry>[];
    final tags = <String>{};
    for (final value in localesValue) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Every batch locale must be an object.');
      }
      final entry = StreamlinedLocaleBatchEntry.fromJson(value);
      if (!tags.add(entry.locale)) {
        throw FormatException('Duplicate batch locale: ${entry.locale}.');
      }
      locales.add(entry);
    }
    return StreamlinedLocaleBatchManifest(
      sourceCatalog: sourceCatalog,
      sourceCatalogSha256: sourceCatalogSha256,
      maxParallelism: maxParallelism,
      locales: locales,
    );
  }

  final String sourceCatalog;
  final String sourceCatalogSha256;
  final int maxParallelism;
  final List<StreamlinedLocaleBatchEntry> locales;
}

final class StreamlinedLocaleBatchCommandResult {
  const StreamlinedLocaleBatchCommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

typedef StreamlinedLocaleBatchCommandRunner =
    Future<StreamlinedLocaleBatchCommandResult> Function(List<String>);

final class StreamlinedLocaleBatchItemResult {
  const StreamlinedLocaleBatchItemResult({
    required this.locale,
    required this.arguments,
    required this.commandResult,
  });

  final String locale;
  final List<String> arguments;
  final StreamlinedLocaleBatchCommandResult commandResult;

  bool get passed => commandResult.exitCode == 0;

  Map<String, dynamic> toJson() => {
    'locale': locale,
    'passed': passed,
    'exitCode': commandResult.exitCode,
  };
}

final class StreamlinedLocaleBatchResult {
  const StreamlinedLocaleBatchResult({
    required this.operation,
    required this.sourceCatalogSha256,
    required this.items,
  });

  final StreamlinedLocaleBatchOperation operation;
  final String sourceCatalogSha256;
  final List<StreamlinedLocaleBatchItemResult> items;

  bool get passed => items.every((item) => item.passed);

  int get passedCount => items.where((item) => item.passed).length;

  int get failedCount => items.length - passedCount;

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'workflow': streamlinedLocaleBatchWorkflow,
    'operation': operation.name,
    'passed': passed,
    'sourceCatalogSha256': sourceCatalogSha256,
    'localeCount': items.length,
    'passedCount': passedCount,
    'failedCount': failedCount,
    'locales': items.map((item) => item.toJson()).toList(),
  };
}

List<String> streamlinedLocaleBatchArguments({
  required StreamlinedLocaleBatchOperation operation,
  required StreamlinedLocaleBatchEntry entry,
  String? translationBundleDirectory,
  String? privateReviewDirectory,
}) => switch (operation) {
  StreamlinedLocaleBatchOperation.init => [
    'init',
    entry.locale,
    entry.englishName,
    entry.nativeName,
    entry.reviewScope,
  ],
  StreamlinedLocaleBatchOperation.prepare => [
    'prepare',
    entry.planPath,
    entry.translationBundlePath(translationBundleDirectory!),
    entry.privateReviewPath(privateReviewDirectory!),
  ],
  StreamlinedLocaleBatchOperation.accept => [
    'accept',
    entry.planPath,
    entry.privateReviewPath(privateReviewDirectory!),
  ],
  StreamlinedLocaleBatchOperation.verify => ['verify', entry.planPath],
};

Future<StreamlinedLocaleBatchResult> runStreamlinedLocaleBatch({
  required StreamlinedLocaleBatchManifest manifest,
  required StreamlinedLocaleBatchOperation operation,
  required StreamlinedLocaleBatchCommandRunner commandRunner,
  String? translationBundleDirectory,
  String? privateReviewDirectory,
}) async {
  if (operation == StreamlinedLocaleBatchOperation.prepare &&
      (translationBundleDirectory == null || privateReviewDirectory == null)) {
    throw ArgumentError(
      'prepare requires translation-bundle and private-review directories.',
    );
  }
  if (operation == StreamlinedLocaleBatchOperation.accept &&
      privateReviewDirectory == null) {
    throw ArgumentError('accept requires a private-review directory.');
  }

  final results = await _concurrentMap(
    manifest.locales,
    manifest.maxParallelism,
    (entry) async {
      final arguments = streamlinedLocaleBatchArguments(
        operation: operation,
        entry: entry,
        translationBundleDirectory: translationBundleDirectory,
        privateReviewDirectory: privateReviewDirectory,
      );
      final result = await commandRunner(arguments);
      return StreamlinedLocaleBatchItemResult(
        locale: entry.locale,
        arguments: arguments,
        commandResult: result,
      );
    },
  );
  return StreamlinedLocaleBatchResult(
    operation: operation,
    sourceCatalogSha256: manifest.sourceCatalogSha256,
    items: results,
  );
}

Future<void> main(List<String> arguments) async {
  if (arguments.length < 2) {
    _usage();
    exitCode = 64;
    return;
  }
  try {
    final operation = StreamlinedLocaleBatchOperation.values.firstWhere(
      (value) => value.name == arguments.first,
      orElse: () => throw const FormatException('Unknown batch operation.'),
    );
    final expectedLength = switch (operation) {
      StreamlinedLocaleBatchOperation.init ||
      StreamlinedLocaleBatchOperation.verify => 2,
      StreamlinedLocaleBatchOperation.accept => 3,
      StreamlinedLocaleBatchOperation.prepare => 4,
    };
    if (arguments.length != expectedLength) {
      _usage();
      exitCode = 64;
      return;
    }

    final manifest = StreamlinedLocaleBatchManifest.fromJson(
      _jsonObject(arguments[1]),
    );
    _verifySourceLock(manifest);
    final translationBundleDirectory =
        operation == StreamlinedLocaleBatchOperation.prepare
        ? arguments[2]
        : null;
    final privateReviewDirectory = switch (operation) {
      StreamlinedLocaleBatchOperation.prepare => arguments[3],
      StreamlinedLocaleBatchOperation.accept => arguments[2],
      _ => null,
    };
    if (translationBundleDirectory != null) {
      _requirePrivateDirectory(translationBundleDirectory);
    }
    if (privateReviewDirectory != null) {
      _requirePrivateDirectory(privateReviewDirectory);
    }
    final preflightErrors = _preflight(
      manifest: manifest,
      operation: operation,
      translationBundleDirectory: translationBundleDirectory,
      privateReviewDirectory: privateReviewDirectory,
    );
    if (preflightErrors.isNotEmpty) {
      stderr.writeln(
        _prettyJson({
          'workflow': streamlinedLocaleBatchWorkflow,
          'operation': operation.name,
          'passed': false,
          'preflightErrors': preflightErrors,
          'noLocaleCommandStarted': true,
        }),
      );
      exitCode = 65;
      return;
    }

    final result = await runStreamlinedLocaleBatch(
      manifest: manifest,
      operation: operation,
      translationBundleDirectory: translationBundleDirectory,
      privateReviewDirectory: privateReviewDirectory,
      commandRunner: _runSingleLocaleCommand,
    );
    for (final item in result.items) {
      stdout.writeln('=== ${item.locale} ${operation.name} ===');
      if (item.commandResult.stdout.trim().isNotEmpty) {
        stdout.writeln(item.commandResult.stdout.trimRight());
      }
      if (item.commandResult.stderr.trim().isNotEmpty) {
        stderr.writeln(item.commandResult.stderr.trimRight());
      }
    }
    stdout.writeln(_prettyJson(result.toJson()));
    if (!result.passed) {
      stderr.writeln(
        'Batch ${operation.name} completed with isolated locale failures. '
        'Successful locales were not rolled back or approved on behalf of '
        'failed locales.',
      );
      exitCode = 65;
    }
  } on Object catch (error) {
    stderr.writeln('Streamlined locale batch failed: $error');
    exitCode = 66;
  }
}

Future<StreamlinedLocaleBatchCommandResult> _runSingleLocaleCommand(
  List<String> arguments,
) async {
  final result = await Process.run(Platform.resolvedExecutable, [
    'run',
    _singleLocaleTool,
    ...arguments,
  ]);
  return StreamlinedLocaleBatchCommandResult(
    exitCode: result.exitCode,
    stdout: result.stdout.toString(),
    stderr: result.stderr.toString(),
  );
}

List<String> _preflight({
  required StreamlinedLocaleBatchManifest manifest,
  required StreamlinedLocaleBatchOperation operation,
  String? translationBundleDirectory,
  String? privateReviewDirectory,
}) {
  final errors = <String>[];
  for (final entry in manifest.locales) {
    void requirePath(String path) {
      if (!File(path).existsSync()) errors.add('${entry.locale}:missing:$path');
    }

    void refusePath(String path) {
      if (File(path).existsSync() || Directory(path).existsSync()) {
        errors.add('${entry.locale}:already_exists:$path');
      }
    }

    void requireLockedPlan() {
      if (!File(entry.planPath).existsSync()) {
        errors.add('${entry.locale}:missing:${entry.planPath}');
        return;
      }
      try {
        final plan = StreamlinedLocalePlan.fromJson(
          _jsonObject(entry.planPath),
        );
        if (plan.locale != entry.locale ||
            plan.englishName != entry.englishName ||
            plan.nativeName != entry.nativeName ||
            plan.reviewScope != entry.reviewScope ||
            plan.sourceCatalog != manifest.sourceCatalog ||
            plan.sourceCatalogSha256 != manifest.sourceCatalogSha256) {
          errors.add('${entry.locale}:plan_manifest_lock_mismatch');
        }
      } on Object {
        errors.add('${entry.locale}:invalid_plan:${entry.planPath}');
      }
    }

    switch (operation) {
      case StreamlinedLocaleBatchOperation.init:
        for (final path in [
          entry.planPath,
          entry.candidatePath,
          entry.structuralAuditPath,
          entry.approvedCatalogPath,
          entry.validationRecordPath,
          entry.runtimeCatalogPath,
        ]) {
          refusePath(path);
        }
        break;
      case StreamlinedLocaleBatchOperation.prepare:
        requireLockedPlan();
        requirePath(entry.translationBundlePath(translationBundleDirectory!));
        refusePath(entry.candidatePath);
        refusePath(entry.structuralAuditPath);
        refusePath(entry.approvedCatalogPath);
        refusePath(entry.validationRecordPath);
        refusePath(entry.runtimeCatalogPath);
        refusePath(entry.privateReviewPath(privateReviewDirectory!));
        break;
      case StreamlinedLocaleBatchOperation.accept:
        requireLockedPlan();
        requirePath(entry.candidatePath);
        requirePath(entry.structuralAuditPath);
        requirePath(entry.privateReviewPath(privateReviewDirectory!));
        refusePath(entry.approvedCatalogPath);
        refusePath(entry.validationRecordPath);
        refusePath(entry.runtimeCatalogPath);
        break;
      case StreamlinedLocaleBatchOperation.verify:
        requireLockedPlan();
        requirePath(entry.candidatePath);
        requirePath(entry.structuralAuditPath);
        requirePath(entry.approvedCatalogPath);
        requirePath(entry.validationRecordPath);
        break;
    }
  }
  return errors;
}

void _verifySourceLock(StreamlinedLocaleBatchManifest manifest) {
  final source = File(manifest.sourceCatalog);
  if (!source.existsSync() ||
      _sha256File(source.path) != manifest.sourceCatalogSha256) {
    throw StateError(
      'The English source catalog does not match the batch lock.',
    );
  }
}

void _requirePrivateDirectory(String path) {
  final repository = Directory.current.absolute.path;
  final absolute = Directory(path).absolute.path;
  if (absolute == repository ||
      absolute.startsWith('$repository${Platform.pathSeparator}')) {
    throw ArgumentError(
      'Translation bundles and private review worksheets must remain outside '
      'Git.',
    );
  }
}

Future<List<R>> _concurrentMap<T, R>(
  List<T> values,
  int parallelism,
  Future<R> Function(T) action,
) async {
  final results = List<R?>.filled(values.length, null);
  var nextIndex = 0;

  Future<void> worker() async {
    while (nextIndex < values.length) {
      final index = nextIndex;
      nextIndex += 1;
      results[index] = await action(values[index]);
    }
  }

  await Future.wait(
    List.generate(math.min(parallelism, values.length), (_) => worker()),
  );
  return results.cast<R>();
}

Map<String, dynamic> _jsonObject(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw FormatException('$path must contain a JSON object.');
  }
  return decoded;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

void _requireExactKeys(
  Map<String, dynamic> json,
  Set<String> expected,
  String label,
) {
  final actual = json.keys.toSet();
  if (actual.difference(expected).isNotEmpty ||
      expected.difference(actual).isNotEmpty) {
    throw FormatException('$label has an invalid schema.');
  }
}

String _sha256File(String path) {
  final result = Process.runSync('shasum', ['-a', '256', path]);
  if (result.exitCode != 0) throw StateError('Unable to hash $path.');
  return result.stdout.toString().trim().split(RegExp(r'\s+')).first;
}

String _join(String directory, String filename) =>
    '${directory.endsWith(Platform.pathSeparator) ? directory.substring(0, directory.length - 1) : directory}${Platform.pathSeparator}$filename';

String _prettyJson(Object? value) =>
    '${const JsonEncoder.withIndent('  ').convert(value)}\n';

void _usage() {
  stderr.writeln('''
Usage:
  dart run tool/localization_streamlined_batch.dart init <batch.json>
  dart run tool/localization_streamlined_batch.dart prepare <batch.json> <private-translation-directory> <private-review-directory>
  dart run tool/localization_streamlined_batch.dart accept <batch.json> <private-review-directory>
  dart run tool/localization_streamlined_batch.dart verify <batch.json>
''');
}
