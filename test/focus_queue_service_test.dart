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
}
