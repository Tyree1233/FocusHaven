import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focushaven/models/haven_action.dart';
import 'package:focushaven/models/haven_system_intent.dart';
import 'package:focushaven/services/focus_queue_service.dart';
import 'package:focushaven/services/haven_action_engine.dart';
import 'package:focushaven/services/haven_system_intent_review_service.dart';
import 'package:focushaven/services/timer_service.dart';

enum _Restored { ready, pendingResume, paused }

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final restored in _Restored.values) {
    for (final pause in [true, false]) {
      final route = pause ? 'pause' : 'resume';
      test(
        'restored ${restored.name}: $route outcome and no owner mutation',
        () async {
          final seed = <String, Object>{
            // Synthetic fixture data only; no private device storage is read.
            'focusQueue': jsonEncode([
              {
                'id': 'fixture-active',
                'title': 'Synthetic fixture',
                'isComplete': false,
              },
              {
                'id': 'fixture-completed',
                'title': 'Completed fixture',
                'isComplete': true,
              },
            ]),
            if (restored != _Restored.ready) ...{
              'focusSeconds': 1500,
              'totalSessionSeconds': 1500,
              'secondsRemaining': 600,
              'sessionType': SessionType.focus.index,
            },
            if (restored == _Restored.pendingResume)
              'timerEndsAt': DateTime.now()
                  .add(const Duration(minutes: 10))
                  .millisecondsSinceEpoch,
          };
          SharedPreferences.setMockInitialValues(seed);
          final timer = TimerService();
          final queue = FocusQueueService();
          addTearDown(timer.dispose);
          addTearDown(queue.dispose);
          await Future.wait([timer.initialized, queue.initialized]);
          // Drain initialization's already-scheduled mock preference writes.
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
          final preferences = await SharedPreferences.getInstance();
          var surfaceOpens = 0;
          var timerNotifications = 0;
          var queueNotifications = 0;
          timer.addListener(() => timerNotifications++);
          queue.addListener(() => queueNotifications++);
          final executor = HavenActionExecutor(
            timer: timer,
            focusQueue: queue,
            openSurface: (_) async {
              surfaceOpens++;
              return false;
            },
          );
          final now = DateTime.utc(2026, 9, 15, 12);
          final engine = HavenActionEngine(
            executor: executor,
            clock: () => now,
          );
          final service = HavenSystemIntentReviewService(
            engine: engine,
            clock: () => now,
            idGenerator: () => 'cold-fixture-proposal',
          );
          final expectedActivity = switch (restored) {
            _Restored.ready => HavenTimerActivity.ready,
            _Restored.pendingResume => HavenTimerActivity.pendingResume,
            _Restored.paused => HavenTimerActivity.paused,
          };
          expect(executor.snapshot().activity, expectedActivity);
          expect(timer.isRunning, isFalse);
          expect(timer.isComplete, isFalse);
          expect(timer.endsAt, isNull);
          expect(timer.hasPendingResume, restored == _Restored.pendingResume);
          expect(queue.items, hasLength(1));
          expect(queue.completedItems, hasLength(1));
          if (restored == _Restored.pendingResume) {
            expect(timer.secondsRemaining, inInclusiveRange(580, 600));
            expect(preferences.getBool('hasPendingTimerResume'), isTrue);
            expect(preferences.containsKey('timerEndsAt'), isFalse);
          } else {
            expect(
              timer.secondsRemaining,
              restored == _Restored.ready ? 1500 : 600,
            );
          }

          Map<String, Object?> ownerSnapshot() => {
            'activity': executor.snapshot().activity,
            'token': executor.snapshot().token,
            'session': timer.sessionType,
            'remaining': timer.secondsRemaining,
            'total': timer.totalSessionSeconds,
            'running': timer.isRunning,
            'complete': timer.isComplete,
            'pendingResume': timer.hasPendingResume,
            'endsAt': timer.endsAt,
            'completedFocusSessions': timer.completedFocusSessions,
            'canStartHavenPlan': timer.canStartHavenPlan,
            'canOfferSmartReset': timer.canOfferSmartReset,
            'queueRevision': queue.queueRevision,
            'queueItems': queue.items.map((item) => item.toJson()).toList(),
            'completedQueueItems': queue.completedItems
                .map((item) => item.toJson())
                .toList(),
          };
          String storedSnapshot() {
            final keys = preferences.getKeys().toList()..sort();
            return jsonEncode({
              for (final key in keys) key: preferences.get(key),
            });
          }

          final beforeOwner = ownerSnapshot();
          final beforeStorage = storedSnapshot();
          final draft = pause
              ? const HavenSystemIntentDraft.pauseTimer('cold-pause-fixture')
              : const HavenSystemIntentDraft.resumeTimer('cold-resume-fixture');
          final preparation = service.prepareReview(draft);
          final shouldReview = !pause && restored != _Restored.ready;
          if (shouldReview) {
            expect(
              preparation.status,
              HavenSystemIntentReviewPreparationStatus.ready,
            );
            expect(preparation.policyReason, HavenActionReason.none);
            expect(preparation.review!.actionKind, HavenActionKind.resumeTimer);
            expect(preparation.review!.requiresExactConfirmation, isTrue);
            expect(preparation.review!.canExecuteWithoutConfirmation, isFalse);
          } else {
            expect(
              preparation.status,
              HavenSystemIntentReviewPreparationStatus.unavailable,
            );
            expect(
              preparation.rejectionReason,
              HavenSystemIntentReviewRejectionReason.policyRejected,
            );
            expect(
              preparation.policyReason,
              HavenActionReason.unavailableInCurrentState,
            );
            expect(preparation.review, isNull);
          }
          await Future<void>.delayed(Duration.zero);
          expect(ownerSnapshot(), equals(beforeOwner));
          expect(storedSnapshot(), beforeStorage);

          final replay = service.prepareReview(draft);
          expect(
            replay.status,
            HavenSystemIntentReviewPreparationStatus.replayed,
          );
          expect(
            replay.rejectionReason,
            HavenSystemIntentReviewRejectionReason.duplicateInvocation,
          );
          expect(replay.review, isNull);
          await Future<void>.delayed(Duration.zero);
          expect(ownerSnapshot(), equals(beforeOwner));
          expect(storedSnapshot(), beforeStorage);
          expect(timerNotifications, 0);
          expect(queueNotifications, 0);
          expect(surfaceOpens, 0);
        },
        timeout: const Timeout(Duration(seconds: 20)),
      );
    }
  }
}
