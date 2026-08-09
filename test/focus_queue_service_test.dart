import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/services/focus_queue_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<FocusQueueService> createQueue() async {
    final queue = FocusQueueService();
    await Future<void>.delayed(Duration.zero);
    return queue;
  }

  test('adds a cleaned task and persists it', () async {
    final queue = await createQueue();
    addTearDown(queue.dispose);

    await queue.add('  Review   the   project  ');

    expect(queue.remainingCount, 1);
    expect(queue.items.single.title, 'Review the project');

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('focusQueue'), isNotNull);
  });

  test('adding during startup preserves the saved queue', () async {
    SharedPreferences.setMockInitialValues({
      'focusQueue': jsonEncode([
        {'id': 'saved-1', 'title': 'Saved before launch', 'isComplete': false},
      ]),
    });

    final queue = FocusQueueService();
    addTearDown(queue.dispose);

    await queue.add('Added immediately');

    expect(queue.items, hasLength(2));
    expect(
      queue.items.map((item) => item.title),
      containsAll(['Saved before launch', 'Added immediately']),
    );

    final preferences = await SharedPreferences.getInstance();
    final saved = jsonDecode(preferences.getString('focusQueue')!) as List;
    expect(saved, hasLength(2));
  });

  test('does not add an empty task', () async {
    final queue = await createQueue();
    addTearDown(queue.dispose);

    await queue.add('   ');

    expect(queue.items, isEmpty);
  });

  test('limits a task title to 100 characters', () async {
    final queue = await createQueue();
    addTearDown(queue.dispose);

    await queue.add(List.filled(101, 'a').join());

    expect(queue.items.single.title, hasLength(100));
  });

  test('renames a task with a cleaned title', () async {
    final queue = await createQueue();
    addTearDown(queue.dispose);
    await queue.add('Read notes');

    await queue.rename(queue.items.single.id, '  Review   project notes ');

    expect(queue.items.single.title, 'Review project notes');
  });

  test(
    'renaming a completed task preserves its completion timestamp',
    () async {
      final completedAt = DateTime.now().subtract(const Duration(minutes: 1));
      SharedPreferences.setMockInitialValues({
        'focusQueue': jsonEncode([
          {
            'id': 'done-1',
            'title': 'Original completed task',
            'isComplete': true,
            'completedAt': completedAt.toIso8601String(),
          },
        ]),
      });

      final queue = await createQueue();
      addTearDown(queue.dispose);

      await queue.rename('done-1', 'Renamed completed task');

      final item = queue.completedItems.single;
      expect(item.title, 'Renamed completed task');
      expect(item.completedAt, isNotNull);
      expect(item.completedAt!.isAtSameMomentAs(completedAt), isTrue);

      final preferences = await SharedPreferences.getInstance();
      final saved = jsonDecode(preferences.getString('focusQueue')!) as List;
      final savedItem = Map<String, dynamic>.from(saved.single as Map);
      expect(savedItem['completedAt'], completedAt.toIso8601String());
    },
  );

  test('does not replace a task title with an empty value', () async {
    final queue = await createQueue();
    addTearDown(queue.dispose);
    await queue.add('Read notes');

    await queue.rename(queue.items.single.id, '   ');

    expect(queue.items.single.title, 'Read notes');
  });

  test('no-op task actions do not persist or notify listeners', () async {
    final queue = await createQueue();
    addTearDown(queue.dispose);
    await queue.add('Keep this task');

    final preferences = await SharedPreferences.getInstance();
    final savedBefore = preferences.getString('focusQueue');
    final revisionBefore = queue.queueRevision;
    var notifications = 0;
    queue.addListener(() => notifications++);

    await queue.rename(queue.items.single.id, '  Keep   this task  ');
    await queue.rename('missing-id', 'Missing task');
    await queue.toggle('missing-id');
    await queue.remove('missing-id');

    expect(queue.queueRevision, revisionBefore);
    expect(notifications, 0);
    expect(preferences.getString('focusQueue'), savedBefore);
    expect(queue.items.single.title, 'Keep this task');
  });

  test('completing a task moves it to completed items', () async {
    final queue = await createQueue();
    addTearDown(queue.dispose);
    await queue.add('Read for twenty minutes');
    final id = queue.items.single.id;

    await queue.toggle(id);

    expect(queue.items, isEmpty);
    expect(queue.completedItems, hasLength(1));
    expect(queue.completedItems.single.title, 'Read for twenty minutes');
    expect(queue.completedToday, 1);
  });

  test('toggling a completed task restores it to the active queue', () async {
    final queue = await createQueue();
    addTearDown(queue.dispose);
    await queue.add('Plan tomorrow');
    final id = queue.items.single.id;
    await queue.toggle(id);

    await queue.toggle(id);

    expect(queue.items, hasLength(1));
    expect(queue.items.single.completedAt, isNull);
    expect(queue.completedItems, isEmpty);
  });

  test('clearing local data removes all queue items', () async {
    final queue = await createQueue();
    addTearDown(queue.dispose);
    await queue.add('One task');

    await queue.clearLocalData();

    expect(queue.items, isEmpty);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('focusQueue'), isFalse);
  });

  test('loads saved active and completed tasks on launch', () async {
    SharedPreferences.setMockInitialValues({
      'focusQueue': jsonEncode([
        {'id': 'active-1', 'title': 'Review notes', 'isComplete': false},
        {
          'id': 'done-1',
          'title': 'Plan tomorrow',
          'isComplete': true,
          'completedAt': '2026-08-07T12:00:00.000',
        },
      ]),
    });

    final queue = await createQueue();
    addTearDown(queue.dispose);

    expect(queue.items.single.title, 'Review notes');
    expect(queue.completedItems.single.title, 'Plan tomorrow');
  });

  test(
    'preserves valid tasks when individual saved records are invalid',
    () async {
      SharedPreferences.setMockInitialValues({
        'focusQueue': jsonEncode([
          {
            'id': 'active-1',
            'title': '  Review   notes  ',
            'isComplete': false,
          },
          {'id': 'missing-title', 'isComplete': false},
          {'id': 42, 'title': 'Invalid ID', 'isComplete': false},
          'not a queue record',
          {
            'id': 'done-1',
            'title': 'Plan tomorrow',
            'isComplete': true,
            'completedAt': '2026-08-07T12:00:00.000',
          },
        ]),
      });

      final queue = await createQueue();
      addTearDown(queue.dispose);

      expect(queue.items, hasLength(1));
      expect(queue.items.single.title, 'Review notes');
      expect(queue.completedItems, hasLength(1));
      expect(queue.completedItems.single.title, 'Plan tomorrow');
    },
  );

  test('keeps only the first saved task when IDs are duplicated', () async {
    SharedPreferences.setMockInitialValues({
      'focusQueue': jsonEncode([
        {'id': 'same-id', 'title': 'First task', 'isComplete': false},
        {'id': 'same-id', 'title': 'Duplicate task', 'isComplete': false},
      ]),
    });

    final queue = await createQueue();
    addTearDown(queue.dispose);

    expect(queue.items, hasLength(1));
    expect(queue.items.single.title, 'First task');
  });

  test('starts with an empty queue when saved data is invalid', () async {
    SharedPreferences.setMockInitialValues({'focusQueue': 'not valid JSON'});

    final queue = await createQueue();
    addTearDown(queue.dispose);

    expect(queue.items, isEmpty);
    expect(queue.completedItems, isEmpty);
  });
}
