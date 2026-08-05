class FocusSession {
  const FocusSession({
    required this.completedAt,
    required this.durationSeconds,
    this.focusTask,
  });

  final DateTime completedAt;
  final int durationSeconds;
  final String? focusTask;

  Map<String, dynamic> toJson() => {
        'completedAt': completedAt.toIso8601String(),
        'durationSeconds': durationSeconds,
        if (focusTask != null) 'focusTask': focusTask,
      };

  factory FocusSession.fromJson(Map<String, dynamic> json) {
    return FocusSession(
      completedAt: DateTime.parse(json['completedAt'] as String),
      durationSeconds: json['durationSeconds'] as int,
      focusTask: json['focusTask'] is String ? json['focusTask'] as String : null,
    );
  }
}
