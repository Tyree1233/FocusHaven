import 'adaptive_focus_suggestion.dart';

enum AdaptiveFocusReviewChoice { keepCurrent, acceptSuggestion }

/// One text-free result from explicitly settling an adaptive review.
///
/// The result is not an execution command. A later coordinator must recheck
/// current owner state before delegating an accepted duration to that owner.
class AdaptiveFocusReviewDecision {
  const AdaptiveFocusReviewDecision({
    required this.choice,
    required this.reviewedSuggestion,
    required this.focusMinutes,
    required this.breakMinutes,
  });

  final AdaptiveFocusReviewChoice choice;
  final AdaptiveFocusSuggestion reviewedSuggestion;
  final int focusMinutes;
  final int breakMinutes;

  bool get authorizesDelegation =>
      choice == AdaptiveFocusReviewChoice.acceptSuggestion;
  bool get keepsCurrent => choice == AdaptiveFocusReviewChoice.keepCurrent;
}
