enum CoachingMessageRole { user, coach }

class CoachingMessage {
  const CoachingMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final CoachingMessageRole role;
  final String text;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };

  factory CoachingMessage.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final roleName = json['role'];
    final text = json['text'];
    final createdAtValue = json['createdAt'];
    if (id is! String ||
        id.trim().isEmpty ||
        roleName is! String ||
        text is! String ||
        text.trim().isEmpty ||
        createdAtValue is! String) {
      throw const FormatException('Invalid coaching message');
    }

    CoachingMessageRole? role;
    for (final candidate in CoachingMessageRole.values) {
      if (candidate.name == roleName) {
        role = candidate;
        break;
      }
    }
    final createdAt = DateTime.tryParse(createdAtValue);
    if (role == null || createdAt == null) {
      throw const FormatException('Invalid coaching message');
    }

    return CoachingMessage(
      id: id.trim(),
      role: role,
      text: text.trim(),
      createdAt: createdAt,
    );
  }
}
