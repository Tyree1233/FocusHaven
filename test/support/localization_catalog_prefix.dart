import 'dart:convert';
import 'dart:io';

const adaptiveFocusDeltaMessageCount = 17;

/// Reconstructs the exact catalog bytes that preceded the appended Adaptive
/// Focus delta while refusing any unexpected delta shape or placement.
List<int> catalogBytesBeforeAdaptiveFocus(String path) {
  final raw = File(path).readAsStringSync();
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
