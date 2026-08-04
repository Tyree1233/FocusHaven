class FocusSession {
  const FocusSession({
    required this.completedAt,
    required this.durationSeconds,
  });

  final DateTime completedAt;
  final int durationSeconds;

  Map<String, dynamic> toJson() => {
        'completedAt': completedAt.toIso8601String(),
        'durationSeconds': durationSeconds,
      };

  factory FocusSession.fromJson(Map<String, dynamic> json) {
    return FocusSession(
      completedAt: DateTime.parse(json['completedAt'] as String),
      durationSeconds: json['durationSeconds'] as int,
    );
  }
}
