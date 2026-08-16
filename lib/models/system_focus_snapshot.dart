enum SystemFocusSession { focus, shortBreak, longBreak }

enum SystemFocusActivity { ready, running, paused, completed, pendingResume }

enum SystemFocusAction {
  start,
  pause,
  resume,
  reset,
  beginNextSession,
  discardPending,
}

/// A bounded, text-free contract for trusted system surfaces.
///
/// Widgets, lock-screen experiences, notifications, and companion devices can
/// render this snapshot without receiving task names, reflections, journal
/// content, coaching messages, history, mood data, or account identifiers.
class SystemFocusSnapshot {
  factory SystemFocusSnapshot({
    required SystemFocusSession session,
    required SystemFocusActivity activity,
    required int secondsRemaining,
    required int totalSessionSeconds,
    required DateTime generatedAt,
    DateTime? endsAt,
  }) {
    _validate(
      activity: activity,
      secondsRemaining: secondsRemaining,
      totalSessionSeconds: totalSessionSeconds,
      generatedAt: generatedAt,
      endsAt: endsAt,
    );
    return SystemFocusSnapshot._(
      session: session,
      activity: activity,
      secondsRemaining: secondsRemaining,
      totalSessionSeconds: totalSessionSeconds,
      generatedAt: generatedAt.toUtc(),
      endsAt: endsAt?.toUtc(),
    );
  }

  const SystemFocusSnapshot._({
    required this.session,
    required this.activity,
    required this.secondsRemaining,
    required this.totalSessionSeconds,
    required this.generatedAt,
    required this.endsAt,
  });

  static const schemaVersion = 1;
  static const maximumSessionSeconds = 24 * 60 * 60;
  static const _serializedKeys = <String>{
    'schemaVersion',
    'session',
    'activity',
    'secondsRemaining',
    'totalSessionSeconds',
    'generatedAt',
    'endsAt',
  };

  final SystemFocusSession session;
  final SystemFocusActivity activity;
  final int secondsRemaining;
  final int totalSessionSeconds;
  final DateTime generatedAt;

  /// The authoritative UTC deadline for a running countdown only.
  final DateTime? endsAt;

  double get progress =>
      1 - (secondsRemaining / totalSessionSeconds).clamp(0.0, 1.0);

  Set<SystemFocusAction> get availableActions => switch (activity) {
    SystemFocusActivity.ready => const {SystemFocusAction.start},
    SystemFocusActivity.running => const {
      SystemFocusAction.pause,
      SystemFocusAction.reset,
    },
    SystemFocusActivity.paused => const {
      SystemFocusAction.resume,
      SystemFocusAction.reset,
    },
    SystemFocusActivity.completed => const {SystemFocusAction.beginNextSession},
    SystemFocusActivity.pendingResume => const {
      SystemFocusAction.resume,
      SystemFocusAction.discardPending,
    },
  };

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'session': session.name,
    'activity': activity.name,
    'secondsRemaining': secondsRemaining,
    'totalSessionSeconds': totalSessionSeconds,
    'generatedAt': generatedAt.toIso8601String(),
    'endsAt': endsAt?.toIso8601String(),
  };

  factory SystemFocusSnapshot.fromJson(Map<String, Object?> json) {
    if (json.length != _serializedKeys.length ||
        !json.keys.toSet().containsAll(_serializedKeys)) {
      throw const FormatException('Unexpected system focus snapshot fields.');
    }
    if (json['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported system focus snapshot schema.');
    }

    final session = _enumByName(SystemFocusSession.values, json['session']);
    final activity = _enumByName(SystemFocusActivity.values, json['activity']);
    final secondsRemaining = json['secondsRemaining'];
    final totalSessionSeconds = json['totalSessionSeconds'];
    final generatedAt = _dateTime(json['generatedAt']);
    final endsAtValue = json['endsAt'];
    final endsAt = endsAtValue == null ? null : _dateTime(endsAtValue);
    if (session == null ||
        activity == null ||
        secondsRemaining is! int ||
        totalSessionSeconds is! int ||
        generatedAt == null ||
        (endsAtValue != null && endsAt == null)) {
      throw const FormatException('Malformed system focus snapshot.');
    }

    try {
      return SystemFocusSnapshot(
        session: session,
        activity: activity,
        secondsRemaining: secondsRemaining,
        totalSessionSeconds: totalSessionSeconds,
        generatedAt: generatedAt,
        endsAt: endsAt,
      );
    } on ArgumentError catch (error) {
      throw FormatException('Unsafe system focus snapshot: ${error.message}');
    }
  }

  static void _validate({
    required SystemFocusActivity activity,
    required int secondsRemaining,
    required int totalSessionSeconds,
    required DateTime generatedAt,
    required DateTime? endsAt,
  }) {
    if (totalSessionSeconds < 1 ||
        totalSessionSeconds > maximumSessionSeconds ||
        secondsRemaining < 0 ||
        secondsRemaining > totalSessionSeconds) {
      throw ArgumentError('System focus durations must be safely bounded.');
    }
    if (activity == SystemFocusActivity.completed && secondsRemaining != 0) {
      throw ArgumentError('A completed snapshot must have no time remaining.');
    }
    if (activity != SystemFocusActivity.completed && secondsRemaining == 0) {
      throw ArgumentError('Only a completed snapshot may have no time left.');
    }
    if (activity == SystemFocusActivity.running) {
      if (endsAt == null || !endsAt.isAfter(generatedAt)) {
        throw ArgumentError('A running snapshot requires a future deadline.');
      }
      final deadlineSeconds = endsAt.difference(generatedAt).inSeconds;
      if ((deadlineSeconds - secondsRemaining).abs() > 1) {
        throw ArgumentError('The running deadline must match the countdown.');
      }
    } else if (endsAt != null) {
      throw ArgumentError('Only a running snapshot may expose a deadline.');
    }
  }

  static T? _enumByName<T extends Enum>(List<T> values, Object? value) {
    if (value is! String) return null;
    for (final candidate in values) {
      if (candidate.name == value) return candidate;
    }
    return null;
  }

  static DateTime? _dateTime(Object? value) {
    if (value is! String) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null || !parsed.isUtc) return null;
    return parsed;
  }
}
