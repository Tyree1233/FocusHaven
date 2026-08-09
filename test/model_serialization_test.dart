import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/models/journal_entry.dart';
import 'package:focushaven/models/parked_thought.dart';
import 'package:focushaven/services/focus_queue_service.dart';

void main() {
  test('journal entry keeps its values through JSON conversion', () {
    final createdAt = DateTime.utc(2026, 8, 6, 12, 30);
    final entry = JournalEntry(
      createdAt: createdAt,
      mood: 'Calm',
      reflection: 'I made room for what matters.',
    );

    final restored = JournalEntry.fromJson(entry.toJson());

    expect(restored.createdAt, createdAt);
    expect(restored.mood, 'Calm');
    expect(restored.reflection, 'I made room for what matters.');
  });

  test('active queue item keeps its values through JSON conversion', () {
    const item = FocusQueueItem(id: 'task-1', title: 'Review notes');

    final restored = FocusQueueItem.fromJson(item.toJson());

    expect(restored.id, 'task-1');
    expect(restored.title, 'Review notes');
    expect(restored.isComplete, isFalse);
    expect(restored.completedAt, isNull);
  });

  test(
    'completed queue item keeps its completion time through JSON conversion',
    () {
      final completedAt = DateTime.utc(2026, 8, 6, 14, 0);
      final item = FocusQueueItem(
        id: 'task-2',
        title: 'Take a break',
        isComplete: true,
        completedAt: completedAt,
      );

      final restored = FocusQueueItem.fromJson(item.toJson());

      expect(restored.isComplete, isTrue);
      expect(restored.completedAt, completedAt);
    },
  );

  test('invalid completion timestamps are treated as missing', () {
    final item = FocusQueueItem.fromJson({
      'id': 'task-3',
      'title': 'Plan tomorrow',
      'isComplete': true,
      'completedAt': 'not-a-date',
    });

    expect(item.completedAt, isNull);
  });

  test('parked thought keeps its values through JSON conversion', () {
    final createdAt = DateTime.utc(2026, 8, 8, 15, 30);
    final completedAt = DateTime.utc(2026, 8, 8, 16);
    final thought = ParkedThought(
      id: 'thought-1',
      text: 'Reply to Jordan',
      createdAt: createdAt,
      completedAt: completedAt,
    );

    final restored = ParkedThought.fromJson(thought.toJson());

    expect(restored, thought);
    expect(restored.isCompleted, isTrue);
  });

  test('parked thought can be completed, renamed, and reopened', () {
    final captured = ParkedThought(
      id: 'thought-2',
      text: 'Review the proposal',
      createdAt: DateTime.utc(2026, 8, 8, 17),
    );
    final completionTime = DateTime.utc(2026, 8, 8, 18);

    final completed = captured.complete(completionTime);
    final renamed = completed.rename('Review the final proposal');
    final reopened = renamed.reopen();

    expect(captured.isCompleted, isFalse);
    expect(completed.completedAt, completionTime);
    expect(renamed.text, 'Review the final proposal');
    expect(renamed.completedAt, completionTime);
    expect(reopened.text, 'Review the final proposal');
    expect(reopened.completedAt, isNull);
    expect(reopened.id, captured.id);
    expect(reopened.createdAt, captured.createdAt);
  });

  test('parked thought rejects malformed persisted data', () {
    expect(
      () => ParkedThought.fromJson({
        'id': 'thought-3',
        'text': 'Call the dentist',
        'createdAt': 'not-a-date',
      }),
      throwsFormatException,
    );
  });
}
