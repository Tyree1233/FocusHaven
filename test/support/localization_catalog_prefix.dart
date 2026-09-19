import 'dart:convert';
import 'dart:io';

const adaptiveFocusDeltaMessageCount = 17;

/// Reconstructs the exact catalog bytes that preceded the appended Adaptive
/// Focus delta while refusing any unexpected delta shape or placement.
List<int> catalogBytesBeforeAdaptiveFocus(String path) {
  final complete = utf8.decode(catalogBytesBeforeSoundscapes(path));
  final raw = complete.contains('\n  "systemAssistantReview')
      ? utf8.decode(catalogBytesBeforeSystemAssistant(path))
      : complete;
  const markerText = '\n  "adaptiveFocus';
  final marker = raw.indexOf(markerText);
  if (marker < 1 || raw[marker - 1] != ',') {
    throw StateError('Adaptive Focus delta is not appended exactly: $path');
  }

  final delta = jsonDecode('{${raw.substring(marker)}');
  if (delta is! Map<String, dynamic>) {
    throw StateError('Adaptive Focus delta is not a JSON object: $path');
  }
  final messages = delta.keys
      .where((key) => key.startsWith('adaptiveFocus'))
      .toList(growable: false);
  final metadata = delta.keys
      .where((key) => key.startsWith('@adaptiveFocus'))
      .toList(growable: false);
  if (delta.length != adaptiveFocusDeltaMessageCount * 2 ||
      messages.length != adaptiveFocusDeltaMessageCount ||
      metadata.length != adaptiveFocusDeltaMessageCount) {
    throw StateError('Adaptive Focus delta count or keys changed: $path');
  }

  final original = '${raw.substring(0, marker - 1)}\n}\n';
  final decoded = jsonDecode(original);
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Catalog prefix is not a JSON object: $path');
  }
  return utf8.encode(original);
}

Map<String, dynamic> catalogBeforeAdaptiveFocus(String path) =>
    jsonDecode(utf8.decode(catalogBytesBeforeAdaptiveFocus(path)))
        as Map<String, dynamic>;

const systemAssistantDeltaMessageCount = 11;

/// Reconstructs the exact catalog bytes that preceded the appended System
/// Assistant delta while preserving the earlier Adaptive Focus integration.
List<int> catalogBytesBeforeSystemAssistant(String path) {
  final raw = utf8.decode(catalogBytesBeforeSoundscapes(path));
  const markerText = '\n  "systemAssistantReview';
  final marker = raw.indexOf(markerText);
  if (marker < 1 || raw[marker - 1] != ',') {
    throw StateError('System Assistant delta is not appended exactly: $path');
  }

  final delta = jsonDecode('{${raw.substring(marker)}');
  if (delta is! Map<String, dynamic>) {
    throw StateError('System Assistant delta is not a JSON object: $path');
  }
  final messages = delta.keys
      .where((key) => key.startsWith('systemAssistantReview'))
      .toList(growable: false);
  final metadata = delta.keys
      .where((key) => key.startsWith('@systemAssistantReview'))
      .toList(growable: false);
  if (delta.length != systemAssistantDeltaMessageCount * 2 ||
      messages.length != systemAssistantDeltaMessageCount ||
      metadata.length != systemAssistantDeltaMessageCount) {
    throw StateError('System Assistant delta count or keys changed: $path');
  }

  final original = '${raw.substring(0, marker - 1)}\n}\n';
  final decoded = jsonDecode(original);
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Catalog prefix is not a JSON object: $path');
  }
  return utf8.encode(original);
}

Map<String, dynamic> catalogBeforeSystemAssistant(String path) =>
    jsonDecode(utf8.decode(catalogBytesBeforeSystemAssistant(path)))
        as Map<String, dynamic>;

/// Strip only the appended, exact sixteen-message soundscape delta so earlier
/// catalog hash checks continue checking their original bytes, not new copy.
List<int> catalogBytesBeforeSoundscapes(String path) {
  final raw = File(path).readAsStringSync();
  final marker = raw.indexOf('\n  "soundscape');
  if (marker == -1) return utf8.encode(raw);
  if (marker < 1 || raw[marker - 1] != ',') {
    throw StateError('Soundscape delta is not appended exactly: $path');
  }
  final delta = jsonDecode('{${raw.substring(marker)}') as Map<String, dynamic>;
  final source =
      jsonDecode(
            File(
              'localization/proposals/app_en_soundscapes_review.arb',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  source.remove('@@locale');
  if (delta.length != 32 ||
      source.length != 32 ||
      !delta.keys.toSet().containsAll(source.keys)) {
    throw StateError('Soundscape delta count or keys changed: $path');
  }
  return utf8.encode('${raw.substring(0, marker - 1)}\n}\n');
}
