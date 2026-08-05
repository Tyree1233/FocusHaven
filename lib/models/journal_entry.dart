class JournalEntry {
  const JournalEntry({
    required this.createdAt,
    required this.mood,
    required this.reflection,
  });

  final DateTime createdAt;
  final String mood;
  final String reflection;

  Map<String, dynamic> toJson() => {
        'createdAt': createdAt.toIso8601String(),
        'mood': mood,
        'reflection': reflection,
      };

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      createdAt: DateTime.parse(json['createdAt'] as String),
      mood: json['mood'] as String,
      reflection: json['reflection'] as String,
    );
  }
}
