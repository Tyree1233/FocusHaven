import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/services/focus_queue_service.dart';
import 'package:focushaven/services/haven_loop_service.dart';
import 'package:focushaven/services/timer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<({TimerService timer, FocusQueueService queue, HavenLoopService loop})>
  services() async {
    final timer = TimerService();
    final queue = FocusQueueService();
    final loop = HavenLoopService(
      timerService: timer,
      focusQueueService: queue,
    );
    await loop.initialized;
    addTearDown(loop.dispose);
    addTearDown(queue.dispose);
    addTearDown(timer.dispose);
    return (timer: timer, queue: queue, loop: loop);
  }

  test('starts fail closed until its exact local link is restored', () async {
    final timer = TimerService();
    final queue = FocusQueueService();
    final loop = HavenLoopService(
      timerService: timer,
      focusQueueService: queue,
    );
    addTearDown(loop.dispose);
    addTearDown(queue.dispose);
    addTearDown(timer.dispose);

    expect(loop.state.isInitialized, isFalse);

    await loop.initialized;

    expect(loop.state.isInitialized, isTrue);
  });

  test(
    'stores only the selected queue identity and delegates task text',
    () async {
      final owned = await services();
      await owned.queue.add('Prepare the launch brief');
      final item = owned.queue.items.single;

      expect(await owned.loop.selectQueueItem(item), isTrue);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(HavenLoopService.storageKey), item.id);
      expect(owned.timer.focusTask, item.title);
      expect(owned.loop.state.selectedItemId, item.id);
      expect(owned.loop.state.canResolveCompletion, isFalse);
    },
  );

  test('manual intention edit clears the exact queue link', () async {
    final owned = await services();
    await owned.queue.add('Prepare the launch brief');
    await owned.loop.selectQueueItem(owned.queue.items.single);

    await owned.loop.setManualFocusTask('Review launch notes');

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey(HavenLoopService.storageKey), isFalse);
    expect(owned.loop.state.hasSelectedTask, isFalse);
    expect(owned.timer.focusTask, 'Review launch notes');
    expect(owned.queue.items.single.title, 'Prepare the launch brief');
  });

  test('rejects a queue link when the timer does not own Focus', () async {
    final owned = await services();
    await owned.queue.add('Prepare the launch brief');
    owned.timer.selectSession(SessionType.shortBreak);

    expect(await owned.loop.selectQueueItem(owned.queue.items.single), isFalse);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey(HavenLoopService.storageKey), isFalse);
    expect(owned.loop.state.hasSelectedTask, isFalse);
    expect(owned.timer.focusTask, isEmpty);
    expect(owned.queue.items.single.title, 'Prepare the launch brief');
  });

  test(
    'rename and removal invalidate the link without touching the timer',
    () async {
      final owned = await services();
      await owned.queue.add('Prepare the launch brief');
      final item = owned.queue.items.single;
      await owned.loop.selectQueueItem(item);

      await owned.queue.rename(item.id, 'Prepare the exact launch brief');

      expect(owned.loop.state.hasSelectedTask, isFalse);
      expect(owned.timer.focusTask, 'Prepare the launch brief');
      expect(owned.queue.items.single.title, 'Prepare the exact launch brief');
      expect(
        await owned.loop.markSelectedTaskComplete(),
        HavenLoopResolution.unavailable,
      );

      await owned.queue.remove(item.id);
      expect(owned.queue.items, isEmpty);
    },
  );

  test(
    'completed focus requires an explicit complete or keep decision',
    () async {
      SharedPreferences.setMockInitialValues({
        'focusQueue': jsonEncode([
          {
            'id': 'linked-task',
            'title': 'Prepare the launch brief',
            'isComplete': false,
          },
        ]),
        'focusTask': 'Prepare the launch brief',
        'focusSeconds': 1500,
        'secondsRemaining': 0,
        'totalSessionSeconds': 1500,
        'sessionType': SessionType.focus.index,
        'isComplete': true,
        HavenLoopService.storageKey: 'linked-task',
      });
      final owned = await services();

      expect(owned.loop.state.canResolveCompletion, isTrue);
      expect(
        await owned.loop.markSelectedTaskComplete(),
        HavenLoopResolution.completed,
      );
      expect(owned.queue.items, isEmpty);
      expect(owned.queue.completedItems.single.id, 'linked-task');
      expect(owned.timer.focusTask, isEmpty);
      expect(owned.loop.state.hasSelectedTask, isFalse);
    },
  );

  test(
    'keep for later preserves the queue item and consumes the link',
    () async {
      SharedPreferences.setMockInitialValues({
        'focusQueue': jsonEncode([
          {
            'id': 'linked-task',
            'title': 'Prepare the launch brief',
            'isComplete': false,
          },
        ]),
        'focusTask': 'Prepare the launch brief',
        'secondsRemaining': 0,
        'totalSessionSeconds': 1500,
        'sessionType': SessionType.focus.index,
        'isComplete': true,
        HavenLoopService.storageKey: 'linked-task',
      });
      final owned = await services();

      expect(
        await owned.loop.keepSelectedTaskForLater(),
        HavenLoopResolution.keptForLater,
      );
      expect(owned.queue.items.single.id, 'linked-task');
      expect(owned.queue.completedItems, isEmpty);
      expect(owned.timer.focusTask, isEmpty);
      expect(owned.loop.state.hasSelectedTask, isFalse);
    },
  );

  test('session changes clear a stale link without queue mutation', () async {
    final owned = await services();
    await owned.queue.add('Prepare the launch brief');
    await owned.loop.selectQueueItem(owned.queue.items.single);

    owned.timer.selectSession(SessionType.shortBreak);

    expect(owned.loop.state.hasSelectedTask, isFalse);
    expect(owned.queue.items.single.title, 'Prepare the launch brief');
  });

  test('stale cleanup cannot erase a newer reviewed selection', () async {
    final owned = await services();
    await owned.queue.add('Prepare the launch brief');
    await owned.queue.add('Review the launch brief');
    final first = owned.queue.items.first;
    final second = owned.queue.items.last;
    await owned.loop.selectQueueItem(first);

    await owned.queue.rename(first.id, 'Prepare the exact launch brief');
    expect(await owned.loop.selectQueueItem(second), isTrue);
    await Future<void>.delayed(Duration.zero);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(HavenLoopService.storageKey), second.id);
    expect(owned.loop.state.selectedItemId, second.id);
    expect(owned.timer.focusTask, second.title);
  });
}
