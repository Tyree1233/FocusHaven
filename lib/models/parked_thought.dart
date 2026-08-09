import 'package:flutter/foundation.dart';

/// A distraction saved for later without interrupting the current focus block.
///
/// Completion is retained as history instead of deleting the thought. This
/// keeps active and completed items distinguishable while preserving when each
/// thought was captured and resolved.
@immutable
final class ParkedThought {
  const ParkedThought({
    required this.id,
    required this.text,
    required this.createdAt,
    this.completedAt,
  });

  final String id;
  final String text;
  final DateTime createdAt;
  final DateTime? completedAt;

  bool get isCompleted => completedAt != null;

  ParkedThought rename(String updatedText) => ParkedThought(
    id: id,
    text: updatedText,
    createdAt: createdAt,
    completedAt: completedAt,
  );

  ParkedThought complete(DateTime completionTime) => ParkedThought(
    id: id,
    text: text,
    createdAt: createdAt,
    completedAt: completionTime,
  );

  ParkedThought reopen() =>
      ParkedThought(id: id, text: text, createdAt: createdAt);

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
  };

  factory ParkedThought.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final text = json['text'];
    final createdAt = _parseDate(json['createdAt']);
    final completedValue = json['completedAt'];
    final completedAt = completedValue == null
        ? null
        : _parseDate(completedValue);

    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('Parked thought ID is missing.');
    }
    if (text is! String || text.trim().isEmpty) {
      throw const FormatException('Parked thought text is missing.');
    }

    return ParkedThought(
      id: id,
      text: text,
      createdAt: createdAt,
      completedAt: completedAt,
    );
  }

  static DateTime _parseDate(Object? value) {
    if (value is! String) {
      throw const FormatException('Parked thought date is missing.');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw const FormatException('Parked thought date is invalid.');
    }
    return parsed;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParkedThought &&
          other.id == id &&
          other.text == text &&
          other.createdAt == createdAt &&
          other.completedAt == completedAt;

  @override
  int get hashCode => Object.hash(id, text, createdAt, completedAt);
}
