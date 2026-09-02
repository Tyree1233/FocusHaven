import 'dart:convert';
import 'dart:io';

final class CatalogQualificationResult {
  const CatalogQualificationResult({
    required this.sourceLocale,
    required this.candidateLocale,
    required this.sourceMessageCount,
    required this.sourcePlaceholderMessageCount,
    required this.missingMessages,
    required this.extraMessages,
    required this.missingSourceMetadata,
    required this.missingCandidateMetadata,
    required this.placeholderSchemaMismatches,
    required this.icuPlaceholderMismatches,
    required this.emptyTranslations,
    required this.sourceEqualTranslations,
  });

  final String? sourceLocale;
  final String? candidateLocale;
  final int sourceMessageCount;
  final int sourcePlaceholderMessageCount;
  final List<String> missingMessages;
  final List<String> extraMessages;
  final List<String> missingSourceMetadata;
  final List<String> missingCandidateMetadata;
  final List<String> placeholderSchemaMismatches;
  final List<String> icuPlaceholderMismatches;
  final List<String> emptyTranslations;
  final List<String> sourceEqualTranslations;

  bool hasExpectedLocales({required String expectedCandidateLocale}) =>
      sourceLocale == 'en' && candidateLocale == expectedCandidateLocale;

  bool get hasCompleteMessageParity =>
      missingMessages.isEmpty && extraMessages.isEmpty;

  bool get hasCompleteMetadata =>
      missingSourceMetadata.isEmpty && missingCandidateMetadata.isEmpty;

  bool get hasSafePlaceholders =>
      placeholderSchemaMismatches.isEmpty && icuPlaceholderMismatches.isEmpty;

  bool readyForHumanReview({required String expectedCandidateLocale}) =>
      hasExpectedLocales(expectedCandidateLocale: expectedCandidateLocale) &&
      hasCompleteMessageParity &&
      hasCompleteMetadata &&
      hasSafePlaceholders &&
      emptyTranslations.isEmpty &&
      sourceEqualTranslations.isEmpty;

  Map<String, Object?> toJson({required String expectedCandidateLocale}) => {
    'sourceLocale': sourceLocale,
    'candidateLocale': candidateLocale,
    'expectedCandidateLocale': expectedCandidateLocale,
    'sourceMessageCount': sourceMessageCount,
    'sourcePlaceholderMessageCount': sourcePlaceholderMessageCount,
    'missingMessages': missingMessages,
    'extraMessages': extraMessages,
    'missingSourceMetadata': missingSourceMetadata,
    'missingCandidateMetadata': missingCandidateMetadata,
    'placeholderSchemaMismatches': placeholderSchemaMismatches,
    'icuPlaceholderMismatches': icuPlaceholderMismatches,
    'emptyTranslations': emptyTranslations,
    'sourceEqualTranslations': sourceEqualTranslations,
    'readyForHumanReview': readyForHumanReview(
      expectedCandidateLocale: expectedCandidateLocale,
    ),
  };
}

CatalogQualificationResult auditLocalizationCandidate({
  required Map<String, dynamic> source,
  required Map<String, dynamic> candidate,
  Set<String> approvedSourceEqualKeys = const {},
}) {
  final sourceKeys = _messageKeys(source);
  final candidateKeys = _messageKeys(candidate);
  final sharedKeys = sourceKeys.intersection(candidateKeys).toList()..sort();

  final missingMessages = sourceKeys.difference(candidateKeys).toList()..sort();
  final extraMessages = candidateKeys.difference(sourceKeys).toList()..sort();
  final missingSourceMetadata = <String>[];
  final missingCandidateMetadata = <String>[];
  final placeholderSchemaMismatches = <String>[];
  final icuPlaceholderMismatches = <String>[];
  final emptyTranslations = <String>[];
  final sourceEqualTranslations = <String>[];
  var sourcePlaceholderMessageCount = 0;

  for (final key in sourceKeys.toList()..sort()) {
    final sourceMetadata = _metadata(source, key);
    if (sourceMetadata == null || !_hasDescription(sourceMetadata)) {
      missingSourceMetadata.add(key);
    }
    if (_placeholderNames(sourceMetadata).isNotEmpty) {
      sourcePlaceholderMessageCount += 1;
    }
  }

  for (final key in sharedKeys) {
    final sourceValue = source[key];
    final candidateValue = candidate[key];
    final sourceMetadata = _metadata(source, key);
    final candidateMetadata = _metadata(candidate, key);

    if (candidateMetadata == null || !_hasDescription(candidateMetadata)) {
      missingCandidateMetadata.add(key);
    }

    final sourceSchema = _placeholderSchema(sourceMetadata);
    final candidateSchema = _placeholderSchema(candidateMetadata);
    if (!_deepEqual(sourceSchema, candidateSchema)) {
      placeholderSchemaMismatches.add(key);
    }

    if (sourceValue is! String || candidateValue is! String) {
      icuPlaceholderMismatches.add(key);
      continue;
    }

    final sourceIcuNames = _icuPlaceholderNames(sourceValue);
    final candidateIcuNames = _icuPlaceholderNames(candidateValue);
    if (!_setEqual(sourceIcuNames, candidateIcuNames) ||
        !_setEqual(candidateIcuNames, sourceSchema.keys.toSet())) {
      icuPlaceholderMismatches.add(key);
    }

    if (candidateValue.trim().isEmpty) {
      emptyTranslations.add(key);
    } else if (candidateValue == sourceValue &&
        !approvedSourceEqualKeys.contains(key)) {
      sourceEqualTranslations.add(key);
    }
  }

  return CatalogQualificationResult(
    sourceLocale: source['@@locale'] as String?,
    candidateLocale: candidate['@@locale'] as String?,
    sourceMessageCount: sourceKeys.length,
    sourcePlaceholderMessageCount: sourcePlaceholderMessageCount,
    missingMessages: missingMessages,
    extraMessages: extraMessages,
    missingSourceMetadata: missingSourceMetadata..sort(),
    missingCandidateMetadata: missingCandidateMetadata..sort(),
    placeholderSchemaMismatches: placeholderSchemaMismatches..sort(),
    icuPlaceholderMismatches: icuPlaceholderMismatches..sort(),
    emptyTranslations: emptyTranslations..sort(),
    sourceEqualTranslations: sourceEqualTranslations..sort(),
  );
}

Set<String> _messageKeys(Map<String, dynamic> catalog) =>
    catalog.keys.where((key) => !key.startsWith('@')).toSet();

Map<String, dynamic>? _metadata(Map<String, dynamic> catalog, String key) {
  final value = catalog['@$key'];
  return value is Map<String, dynamic> ? value : null;
}

bool _hasDescription(Map<String, dynamic> metadata) {
  final description = metadata['description'];
  return description is String && description.trim().isNotEmpty;
}

Map<String, dynamic> _placeholderSchema(Map<String, dynamic>? metadata) {
  final placeholders = metadata?['placeholders'];
  if (placeholders is! Map<String, dynamic>) {
    return const {};
  }
  return Map<String, dynamic>.fromEntries(
    (placeholders.entries.toList()..sort((a, b) => a.key.compareTo(b.key))).map(
      (entry) => MapEntry(entry.key, _normalizeJson(entry.value)),
    ),
  );
}

Set<String> _placeholderNames(Map<String, dynamic>? metadata) =>
    _placeholderSchema(metadata).keys.toSet();

Set<String> _icuPlaceholderNames(String message) {
  final names = <String>{};
  _scanIcuMessage(message, 0, message.length, names);
  return names;
}

void _scanIcuMessage(String message, int start, int end, Set<String> names) {
  var cursor = start;
  while (cursor < end) {
    if (message.codeUnitAt(cursor) != 0x7b) {
      cursor += 1;
      continue;
    }
    final next = _scanIcuArgument(message, cursor, end, names);
    cursor = next > cursor ? next : cursor + 1;
  }
}

int _scanIcuArgument(
  String message,
  int openingBrace,
  int end,
  Set<String> names,
) {
  var cursor = openingBrace + 1;
  cursor = _skipIcuWhitespace(message, cursor, end);
  final nameStart = cursor;
  while (cursor < end && _isIcuIdentifierCodeUnit(message.codeUnitAt(cursor))) {
    cursor += 1;
  }
  if (cursor == nameStart) {
    return openingBrace + 1;
  }
  final name = message.substring(nameStart, cursor);
  cursor = _skipIcuWhitespace(message, cursor, end);
  if (cursor >= end) {
    return end;
  }
  if (message.codeUnitAt(cursor) == 0x7d) {
    names.add(name);
    return cursor + 1;
  }
  if (message.codeUnitAt(cursor) != 0x2c) {
    return openingBrace + 1;
  }

  names.add(name);
  cursor = _skipIcuWhitespace(message, cursor + 1, end);
  final typeStart = cursor;
  while (cursor < end && _isIcuIdentifierCodeUnit(message.codeUnitAt(cursor))) {
    cursor += 1;
  }
  final type = message.substring(typeStart, cursor).toLowerCase();
  cursor = _skipIcuWhitespace(message, cursor, end);
  if (cursor >= end) {
    return end;
  }
  if (message.codeUnitAt(cursor) == 0x7d) {
    return cursor + 1;
  }
  if (message.codeUnitAt(cursor) != 0x2c ||
      (type != 'plural' && type != 'selectordinal' && type != 'select')) {
    return _afterMatchingIcuBrace(message, openingBrace, end);
  }

  return _scanIcuBranches(message, cursor + 1, end, names);
}

int _scanIcuBranches(String message, int start, int end, Set<String> names) {
  var cursor = start;
  while (cursor < end) {
    cursor = _skipIcuWhitespace(message, cursor, end);
    if (cursor >= end || message.codeUnitAt(cursor) == 0x7d) {
      return cursor < end ? cursor + 1 : end;
    }

    final selectorStart = cursor;
    while (cursor < end &&
        message.codeUnitAt(cursor) != 0x7b &&
        message.codeUnitAt(cursor) != 0x7d &&
        !_isIcuWhitespace(message.codeUnitAt(cursor))) {
      cursor += 1;
    }
    final selector = message.substring(selectorStart, cursor);
    cursor = _skipIcuWhitespace(message, cursor, end);
    if (selector.startsWith('offset:')) {
      continue;
    }
    if (cursor >= end || message.codeUnitAt(cursor) != 0x7b) {
      cursor += 1;
      continue;
    }

    final branchEnd = _matchingIcuBrace(message, cursor, end);
    if (branchEnd < 0) {
      return end;
    }
    _scanIcuMessage(message, cursor + 1, branchEnd, names);
    cursor = branchEnd + 1;
  }
  return end;
}

int _afterMatchingIcuBrace(String message, int openingBrace, int end) {
  final closingBrace = _matchingIcuBrace(message, openingBrace, end);
  return closingBrace < 0 ? end : closingBrace + 1;
}

int _matchingIcuBrace(String message, int openingBrace, int end) {
  var depth = 0;
  for (var cursor = openingBrace; cursor < end; cursor += 1) {
    final codeUnit = message.codeUnitAt(cursor);
    if (codeUnit == 0x7b) {
      depth += 1;
    } else if (codeUnit == 0x7d) {
      depth -= 1;
      if (depth == 0) {
        return cursor;
      }
    }
  }
  return -1;
}

int _skipIcuWhitespace(String message, int start, int end) {
  var cursor = start;
  while (cursor < end && _isIcuWhitespace(message.codeUnitAt(cursor))) {
    cursor += 1;
  }
  return cursor;
}

bool _isIcuWhitespace(int codeUnit) =>
    codeUnit == 0x20 ||
    codeUnit == 0x09 ||
    codeUnit == 0x0a ||
    codeUnit == 0x0d;

bool _isIcuIdentifierCodeUnit(int codeUnit) =>
    (codeUnit >= 0x41 && codeUnit <= 0x5a) ||
    (codeUnit >= 0x61 && codeUnit <= 0x7a) ||
    (codeUnit >= 0x30 && codeUnit <= 0x39) ||
    codeUnit == 0x5f;

Object? _normalizeJson(Object? value) {
  if (value is Map) {
    final entries =
        value.entries
            .map((entry) => MapEntry(entry.key.toString(), entry.value))
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    return <String, Object?>{
      for (final entry in entries) entry.key: _normalizeJson(entry.value),
    };
  }
  if (value is List) {
    return value.map(_normalizeJson).toList();
  }
  return value;
}

bool _deepEqual(Object? left, Object? right) =>
    jsonEncode(_normalizeJson(left)) == jsonEncode(_normalizeJson(right));

bool _setEqual(Set<String> left, Set<String> right) =>
    left.length == right.length && left.containsAll(right);

Map<String, dynamic> _readCatalog(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('ARB root must be a JSON object.');
  }
  return decoded;
}

void main(List<String> arguments) {
  if (arguments.length < 3) {
    stderr.writeln(
      'Usage: dart run tool/localization_catalog_qualification.dart '
      '<source.arb> <candidate.arb> <expected-locale> '
      '[approved-source-equal-key ...]',
    );
    exitCode = 64;
    return;
  }

  try {
    final source = _readCatalog(arguments[0]);
    final candidate = _readCatalog(arguments[1]);
    final expectedLocale = arguments[2];
    final result = auditLocalizationCandidate(
      source: source,
      candidate: candidate,
      approvedSourceEqualKeys: arguments.skip(3).toSet(),
    );
    stdout.writeln(
      const JsonEncoder.withIndent(
        '  ',
      ).convert(result.toJson(expectedCandidateLocale: expectedLocale)),
    );
    exitCode =
        result.readyForHumanReview(expectedCandidateLocale: expectedLocale)
        ? 0
        : 1;
  } on Object catch (error) {
    stderr.writeln('Catalog qualification failed: $error');
    exitCode = 65;
  }
}
