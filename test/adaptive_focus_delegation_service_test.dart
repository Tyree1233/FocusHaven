import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focushaven/models/adaptive_focus_delegation.dart';
import 'package:focushaven/models/adaptive_focus_review.dart';
import 'package:focushaven/models/adaptive_focus_suggestion.dart';
import 'package:focushaven/services/adaptive_focus_delegation_service.dart';
import 'package:focushaven/services/timer_service.dart';

AdaptiveFocusSuggestion suggestion({
  int currentFocusMinutes = 25,
  int currentBreakMinutes = 5,
  int suggestedFocusMinutes = 15,
  int suggestedBreakMinutes = 10,
  int relevantSignalCount = 2,
}) => AdaptiveFocusSuggestion(
  currentFocusMinutes: currentFocusMinutes,
  currentBreakMinutes: currentBreakMinutes,
  suggestedFocusMinutes: suggestedFocusMinutes,
  suggestedBreakMinutes: suggestedBreakMinutes,
  direction: suggestedFocusMinutes < currentFocusMinutes
      ? AdaptiveFocusDirection.gentler
      : suggestedFocusMinutes > currentFocusMinutes
      ? AdaptiveFocusDirection.roomToGrow
      : AdaptiveFocusDirection.keepCurrent,
  breakDirection: suggestedBreakMinutes > currentBreakMinutes
      ? AdaptiveFocusBreakDirection.moreRecovery
      : AdaptiveFocusBreakDirection.keepCurrent,
  basis: AdaptiveFocusBasis.recoveryPriority,
  evidenceStrength: AdaptiveFocusEvidenceStrength.supported,
  relevantSignalCount: relevantSignalCount,
  usesRecoveryPattern: true,
  usesLatestReflection: false,
  usesRepeatedRhythm: false,
  usesForecast: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<TimerService> createTimer() async {
    final timer = TimerService();
    await timer.initialized;
    addTearDown(timer.dispose);
    return timer;
  }

  test(
    'explicit acceptance atomically updates both defaults without starting',
    () async {
      final timer = await createTimer();
      final service = AdaptiveFocusDelegationService(timer: timer);
      final preview = suggestion();
      final ticket = service.beginReview(preview);
      var notifications = 0;
      timer.addListener(() => notifications++);

      final result = service.settleAndApply(
        ticket: ticket!,
        latestSuggestion: preview,
        choice: AdaptiveFocusReviewChoice.acceptSuggestion,
      );

      expect(result.outcome, AdaptiveFocusDelegationOutcome.applied);
      expect(result.wasApplied, isTrue);
      expect(result.focusMinutes, 15);
      expect(result.breakMinutes, 10);
      expect(timer.focusDurationSeconds, 15 * 60);
      expect(timer.shortBreakDurationSeconds, 10 * 60);
      expect(timer.secondsRemaining, 15 * 60);
      expect(timer.totalSessionSeconds, 15 * 60);
      expect(timer.sessionType, SessionType.focus);
      expect(timer.isRunning, isFalse);
      expect(timer.isComplete, isFalse);
      expect(timer.hasPendingResume, isFalse);
      expect(timer.canApplyReviewedAdaptiveDurations, isTrue);
      expect(notifications, 1);

      await Future<void>.delayed(Duration.zero);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getInt('focusSeconds'), 15 * 60);
      expect(preferences.getInt('shortBreakSeconds'), 10 * 60);
      expect(preferences.getInt('secondsRemaining'), 15 * 60);
      expect(preferences.getInt('totalSessionSeconds'), 15 * 60);
    },
  );

  test(
    'keep current consumes the ticket without changing timer state',
    () async {
      final timer = await createTimer();
      final service = AdaptiveFocusDelegationService(timer: timer);
      final preview = suggestion();
      final ticket = service.beginReview(preview);
      var notifications = 0;
      timer.addListener(() => notifications++);

      final result = service.settleAndApply(
        ticket: ticket!,
        latestSuggestion: preview,
        choice: AdaptiveFocusReviewChoice.keepCurrent,
      );

      expect(result.outcome, AdaptiveFocusDelegationOutcome.keptCurrent);
      expect(result.keptCurrent, isTrue);
      expect(result.focusMinutes, 25);
      expect(result.breakMinutes, 5);
      expect(timer.focusDurationSeconds, 25 * 60);
      expect(timer.shortBreakDurationSeconds, 5 * 60);
      expect(timer.isRunning, isFalse);
      expect(notifications, 0);
      expect(
        service
            .settleAndApply(
              ticket: ticket,
              latestSuggestion: preview,
              choice: AdaptiveFocusReviewChoice.acceptSuggestion,
            )
            .wasRejected,
        isTrue,
      );
    },
  );

  test('changed evidence fails closed and consumes the owner ticket', () async {
    final timer = await createTimer();
    final service = AdaptiveFocusDelegationService(timer: timer);
    final reviewed = suggestion();
    final changed = suggestion(relevantSignalCount: 3);
    final ticket = service.beginReview(reviewed)!;

    expect(
      service
          .settleAndApply(
            ticket: ticket,
            latestSuggestion: changed,
            choice: AdaptiveFocusReviewChoice.acceptSuggestion,
          )
          .wasRejected,
      isTrue,
    );
    expect(
      service
          .settleAndApply(
            ticket: ticket,
            latestSuggestion: reviewed,
            choice: AdaptiveFocusReviewChoice.acceptSuggestion,
          )
          .wasRejected,
      isTrue,
    );
    expect(timer.focusDurationSeconds, 25 * 60);
    expect(timer.shortBreakDurationSeconds, 5 * 60);
  });

  test('a newer owner review supersedes the earlier capability', () async {
    final timer = await createTimer();
    final service = AdaptiveFocusDelegationService(timer: timer);
    final first = suggestion();
    final second = suggestion(
      suggestedFocusMinutes: 10,
      relevantSignalCount: 3,
    );
    final firstTicket = service.beginReview(first)!;
    final secondTicket = service.beginReview(second)!;

    expect(
      service
          .settleAndApply(
            ticket: firstTicket,
            latestSuggestion: first,
            choice: AdaptiveFocusReviewChoice.acceptSuggestion,
          )
          .wasRejected,
      isTrue,
    );
    expect(
      service
          .settleAndApply(
            ticket: secondTicket,
            latestSuggestion: second,
            choice: AdaptiveFocusReviewChoice.acceptSuggestion,
          )
          .wasApplied,
      isTrue,
    );
    expect(timer.focusDurationSeconds, 10 * 60);
  });

  test(
    'changed owner defaults reject acceptance without partial mutation',
    () async {
      final timer = await createTimer();
      final service = AdaptiveFocusDelegationService(timer: timer);
      final preview = suggestion();
      final ticket = service.beginReview(preview)!;

      timer.setCustomDuration(30, 0);
      final result = service.settleAndApply(
        ticket: ticket,
        latestSuggestion: preview,
        choice: AdaptiveFocusReviewChoice.acceptSuggestion,
      );

      expect(result.wasRejected, isTrue);
      expect(timer.focusDurationSeconds, 30 * 60);
      expect(timer.shortBreakDurationSeconds, 5 * 60);
      expect(timer.secondsRemaining, 30 * 60);
      expect(timer.isRunning, isFalse);
    },
  );

  test(
    'active, paused, completed, and non-Focus states reject delegation',
    () async {
      final timer = await createTimer();
      final preview = suggestion();

      final activeService = AdaptiveFocusDelegationService(timer: timer);
      final activeTicket = activeService.beginReview(preview)!;
      timer.start();
      expect(
        activeService
            .settleAndApply(
              ticket: activeTicket,
              latestSuggestion: preview,
              choice: AdaptiveFocusReviewChoice.acceptSuggestion,
            )
            .wasRejected,
        isTrue,
      );
      timer.pause();
      expect(
        AdaptiveFocusDelegationService(timer: timer).beginReview(preview),
        isNull,
      );

      timer.reset();
      timer.selectSession(SessionType.shortBreak);
      expect(
        AdaptiveFocusDelegationService(timer: timer).beginReview(preview),
        isNull,
      );
      expect(timer.focusDurationSeconds, 25 * 60);
      expect(timer.shortBreakDurationSeconds, 5 * 60);
    },
  );

  test(
    'non-minute defaults and mismatched previews cannot begin review',
    () async {
      final timer = await createTimer();
      timer.setCustomDuration(25, 1);
      final service = AdaptiveFocusDelegationService(timer: timer);

      expect(service.beginReview(suggestion()), isNull);

      timer.setCustomDuration(25, 0);
      expect(service.beginReview(suggestion(currentFocusMinutes: 45)), isNull);
    },
  );

  test(
    'invalid or unchanged accepted values fail at the timer owner',
    () async {
      final timer = await createTimer();

      expect(
        timer.applyReviewedAdaptiveDurations(
          expectedFocusSeconds: 25 * 60,
          expectedBreakSeconds: 5 * 60,
          focusSeconds: 25 * 60,
          breakSeconds: 5 * 60,
        ),
        isFalse,
      );
      expect(
        timer.applyReviewedAdaptiveDurations(
          expectedFocusSeconds: 25 * 60,
          expectedBreakSeconds: 5 * 60,
          focusSeconds: 15 * 60 + 1,
          breakSeconds: 5 * 60,
        ),
        isFalse,
      );
      expect(
        timer.applyReviewedAdaptiveDurations(
          expectedFocusSeconds: 25 * 60,
          expectedBreakSeconds: 5 * 60,
          focusSeconds: 181 * 60,
          breakSeconds: 5 * 60,
        ),
        isFalse,
      );
      expect(
        timer.applyReviewedAdaptiveDurations(
          expectedFocusSeconds: 25 * 60,
          expectedBreakSeconds: 5 * 60,
          focusSeconds: 15 * 60,
          breakSeconds: 0,
        ),
        isFalse,
      );
      expect(timer.focusDurationSeconds, 25 * 60);
      expect(timer.shortBreakDurationSeconds, 5 * 60);
    },
  );

  test('cancel invalidates one exact owner review', () async {
    final timer = await createTimer();
    final service = AdaptiveFocusDelegationService(timer: timer);
    final preview = suggestion();
    final ticket = service.beginReview(preview)!;

    expect(service.cancel(ticket), isTrue);
    expect(service.cancel(ticket), isFalse);
    expect(
      service
          .settleAndApply(
            ticket: ticket,
            latestSuggestion: preview,
            choice: AdaptiveFocusReviewChoice.acceptSuggestion,
          )
          .wasRejected,
      isTrue,
    );
  });
}
