import 'system_focus_snapshot.dart';

/// One bounded request from a trusted system surface.
///
/// The request carries no user-authored content. It is tied to the exact
/// snapshot the person acted on so stale surfaces fail closed.
class SystemFocusCommand {
  factory SystemFocusCommand({
    required String requestId,
    required SystemFocusAction action,
    required DateTime snapshotGeneratedAt,
  }) {
    if (!_requestIdPattern.hasMatch(requestId)) {
      throw ArgumentError('The system focus request ID is invalid.');
    }
    if (!snapshotGeneratedAt.isUtc) {
      throw ArgumentError('System focus commands require a UTC snapshot time.');
    }
    return SystemFocusCommand._(
      requestId: requestId,
      action: action,
      snapshotGeneratedAt: snapshotGeneratedAt,
    );
  }

  const SystemFocusCommand._({
    required this.requestId,
    required this.action,
    required this.snapshotGeneratedAt,
  });

  static const schemaVersion = 1;
  static final _requestIdPattern = RegExp(r'^[A-Za-z0-9_-]{8,64}$');
  static const _serializedKeys = <String>{
    'schemaVersion',
    'requestId',
    'action',
    'snapshotGeneratedAt',
  };

  final String requestId;
  final SystemFocusAction action;
  final DateTime snapshotGeneratedAt;

  Map<String, Object> toJson() => {
    'schemaVersion': schemaVersion,
    'requestId': requestId,
    'action': action.name,
    'snapshotGeneratedAt': snapshotGeneratedAt.toIso8601String(),
  };

  factory SystemFocusCommand.fromJson(Map<String, Object?> json) {
    if (json.length != _serializedKeys.length ||
        !json.keys.toSet().containsAll(_serializedKeys)) {
      throw const FormatException('Unexpected system focus command fields.');
    }
    if (json['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported system focus command schema.');
    }

    final requestId = json['requestId'];
    final actionValue = json['action'];
    final snapshotGeneratedAtValue = json['snapshotGeneratedAt'];
    final action = actionValue is String ? _actionByName(actionValue) : null;
    final snapshotGeneratedAt = snapshotGeneratedAtValue is String
        ? DateTime.tryParse(snapshotGeneratedAtValue)
        : null;
    if (requestId is! String ||
        action == null ||
        snapshotGeneratedAt == null ||
        !snapshotGeneratedAt.isUtc) {
      throw const FormatException('Malformed system focus command.');
    }

    try {
      return SystemFocusCommand(
        requestId: requestId,
        action: action,
        snapshotGeneratedAt: snapshotGeneratedAt,
      );
    } on ArgumentError catch (error) {
      throw FormatException('Unsafe system focus command: ${error.message}');
    }
  }

  static SystemFocusAction? _actionByName(String name) {
    for (final action in SystemFocusAction.values) {
      if (action.name == name) return action;
    }
    return null;
  }
}
