import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/services/focus_queue_service.dart';
import 'package:focushaven/services/haven_action_engine.dart';
import 'package:focushaven/services/haven_action_interpreter.dart';
import 'package:focushaven/services/haven_planner_action_service.dart';
import 'package:focushaven/services/timer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('adds each reviewed item through one fresh Haven action', () async {
    final timer = TimerService();
    final queue = FocusQueueService();
    await Future.wait([timer.initialized, queue.initialized]);
    addTearDown(timer.dispose);
    addTearDown(queue.dispose);
    final now = DateTime.utc(2026, 8, 30, 22, 30);
    var nextId = 0;
    final executor = HavenActionExecutor(
      timer: timer,
      focusQueue: queue,
      openSurface: (_) async => false,
    );
    final service = HavenPlannerActionService(
      interpreter: HavenActionInterpreter(
        clock: () => now,
        idGenerator: () => 'planner-action-${nextId++}',
      ),
      engine: HavenActionEngine(executor: executor, clock: () => now),
      executor: executor,
      clock: () => now,
    );

    final before = executor.snapshot();
    final results = await service.addReviewedQueueItems(const <String>[
      'Define the launch result',
      'Review the release checklist',
    ]);

    expect(results.map((result) => result.added), everyElement(isTrue));
    expect(queue.items.map((item) => item.title), <String>[
      'Define the launch result',
      'Review the release checklist',
    ]);
    expect(queue.queueRevision, before.queueRevision + 2);
    expect(timer.isRunning, isFalse);
    expect(timer.secondsRemaining, 1500);
    expect(timer.totalSessionSeconds, 1500);
  });

  test('invalid reviewed text fails closed without a queue mutation', () async {
    final timer = TimerService();
    final queue = FocusQueueService();
    await Future.wait([timer.initialized, queue.initialized]);
    addTearDown(timer.dispose);
    addTearDown(queue.dispose);
    final executor = HavenActionExecutor(
      timer: timer,
      focusQueue: queue,
      openSurface: (_) async => false,
    );
    final service = HavenPlannerActionService(
      interpreter: HavenActionInterpreter(idGenerator: () => 'invalid'),
      engine: HavenActionEngine(executor: executor),
      executor: executor,
    );

    final results = await service.addReviewedQueueItems(const <String>['']);

    expect(results.single.added, isFalse);
    expect(queue.items, isEmpty);
    expect(timer.isRunning, isFalse);
  });
}
