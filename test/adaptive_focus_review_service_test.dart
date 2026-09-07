import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/models/adaptive_focus_review.dart';
import 'package:focushaven/models/adaptive_focus_suggestion.dart';
import 'package:focushaven/services/adaptive_focus_review_service.dart';

AdaptiveFocusSuggestion suggestion({
  int currentFocusMinutes = 25,
  int currentBreakMinutes = 5,
  int suggestedFocusMinutes = 15,
  int suggestedBreakMinutes = 5,
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
  test('accepts one exact changed suggestion without mutating an owner', () {
    final service = AdaptiveFocusReviewService();
    final preview = suggestion();
    final ticket = service.beginReview(preview);

    final decision = service.settle(
      ticket: ticket,
      latestSuggestion: preview,
      currentFocusMinutes: 25,
      currentBreakMinutes: 5,
      choice: AdaptiveFocusReviewChoice.acceptSuggestion,
    );

    expect(decision, isNotNull);
    expect(decision!.choice, AdaptiveFocusReviewChoice.acceptSuggestion);
    expect(decision.reviewedSuggestion, same(preview));
    expect(decision.focusMinutes, 15);
    expect(decision.breakMinutes, 5);
    expect(decision.authorizesDelegation, isTrue);
    expect(decision.keepsCurrent, isFalse);
  });

  test('keep current returns only the exact current values', () {
    final service = AdaptiveFocusReviewService();
    final preview = suggestion(
      currentFocusMinutes: 45,
      currentBreakMinutes: 10,
      suggestedFocusMinutes: 25,
      suggestedBreakMinutes: 15,
    );

    final decision = service.settle(
      ticket: service.beginReview(preview),
      latestSuggestion: preview,
      currentFocusMinutes: 45,
      currentBreakMinutes: 10,
      choice: AdaptiveFocusReviewChoice.keepCurrent,
    );

    expect(decision, isNotNull);
    expect(decision!.focusMinutes, 45);
    expect(decision.breakMinutes, 10);
    expect(decision.keepsCurrent, isTrue);
    expect(decision.authorizesDelegation, isFalse);
  });

  test('a ticket is single-use and cannot be replayed', () {
    final service = AdaptiveFocusReviewService();
    final preview = suggestion();
    final ticket = service.beginReview(preview);

    AdaptiveFocusReviewDecision? settle() => service.settle(
      ticket: ticket,
      latestSuggestion: preview,
      currentFocusMinutes: 25,
      currentBreakMinutes: 5,
      choice: AdaptiveFocusReviewChoice.acceptSuggestion,
    );

    expect(settle(), isNotNull);
    expect(settle(), isNull);
    expect(service.cancel(ticket), isFalse);
  });

  test('a newer review supersedes an older exact suggestion', () {
    final service = AdaptiveFocusReviewService();
    final first = suggestion();
    final second = suggestion(
      suggestedFocusMinutes: 10,
      relevantSignalCount: 3,
    );
    final firstTicket = service.beginReview(first);
    final secondTicket = service.beginReview(second);

    expect(
      service.settle(
        ticket: firstTicket,
        latestSuggestion: first,
        currentFocusMinutes: 25,
        currentBreakMinutes: 5,
        choice: AdaptiveFocusReviewChoice.acceptSuggestion,
      ),
      isNull,
    );
    expect(
      service.settle(
        ticket: secondTicket,
        latestSuggestion: second,
        currentFocusMinutes: 25,
        currentBreakMinutes: 5,
        choice: AdaptiveFocusReviewChoice.acceptSuggestion,
      ),
      isNotNull,
    );
  });

  test('changed evidence fails closed and consumes the review', () {
    final service = AdaptiveFocusReviewService();
    final reviewed = suggestion();
    final changed = suggestion(relevantSignalCount: 3);
    final ticket = service.beginReview(reviewed);

    expect(
      service.settle(
        ticket: ticket,
        latestSuggestion: changed,
        currentFocusMinutes: 25,
        currentBreakMinutes: 5,
        choice: AdaptiveFocusReviewChoice.acceptSuggestion,
      ),
      isNull,
    );
    expect(
      service.settle(
        ticket: ticket,
        latestSuggestion: reviewed,
        currentFocusMinutes: 25,
        currentBreakMinutes: 5,
        choice: AdaptiveFocusReviewChoice.acceptSuggestion,
      ),
      isNull,
    );
  });

  test('changed owner durations fail closed and consume the review', () {
    final service = AdaptiveFocusReviewService();
    final preview = suggestion();
    final ticket = service.beginReview(preview);

    expect(
      service.settle(
        ticket: ticket,
        latestSuggestion: preview,
        currentFocusMinutes: 45,
        currentBreakMinutes: 5,
        choice: AdaptiveFocusReviewChoice.acceptSuggestion,
      ),
      isNull,
    );
    expect(service.cancel(ticket), isFalse);
  });

  test('an unchanged preview cannot authorize a duration delegation', () {
    final service = AdaptiveFocusReviewService();
    final unchanged = suggestion(suggestedFocusMinutes: 25);
    final ticket = service.beginReview(unchanged);

    expect(
      service.settle(
        ticket: ticket,
        latestSuggestion: unchanged,
        currentFocusMinutes: 25,
        currentBreakMinutes: 5,
        choice: AdaptiveFocusReviewChoice.acceptSuggestion,
      ),
      isNull,
    );

    final keepTicket = service.beginReview(unchanged);
    final keep = service.settle(
      ticket: keepTicket,
      latestSuggestion: unchanged,
      currentFocusMinutes: 25,
      currentBreakMinutes: 5,
      choice: AdaptiveFocusReviewChoice.keepCurrent,
    );
    expect(keep, isNotNull);
    expect(keep!.authorizesDelegation, isFalse);
  });
}
