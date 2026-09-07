import '../models/adaptive_focus_review.dart';
import '../models/adaptive_focus_suggestion.dart';

/// An opaque, single-use capability for one exact adaptive suggestion.
final class AdaptiveFocusReviewTicket {
  const AdaptiveFocusReviewTicket._(this._generation, this._suggestion);

  final int _generation;
  final AdaptiveFocusSuggestion _suggestion;
}

/// Settles one explicit Adaptive Focus review without mutating application
/// state.
///
/// A new review supersedes the previous one. Stale, replayed, mismatched, or
/// owner-changed reviews fail closed. Even a successful acceptance only
/// returns a text-free decision; this service owns no timer or persistence.
class AdaptiveFocusReviewService {
  int _nextGeneration = 0;
  int? _activeGeneration;

  AdaptiveFocusReviewTicket beginReview(AdaptiveFocusSuggestion suggestion) {
    final generation = ++_nextGeneration;
    _activeGeneration = generation;
    return AdaptiveFocusReviewTicket._(generation, suggestion);
  }

  AdaptiveFocusReviewDecision? settle({
    required AdaptiveFocusReviewTicket ticket,
    required AdaptiveFocusSuggestion latestSuggestion,
    required int currentFocusMinutes,
    required int currentBreakMinutes,
    required AdaptiveFocusReviewChoice choice,
  }) {
    if (_activeGeneration != ticket._generation) return null;
    _activeGeneration = null;

    final reviewed = ticket._suggestion;
    if (latestSuggestion != reviewed ||
        currentFocusMinutes != reviewed.currentFocusMinutes ||
        currentBreakMinutes != reviewed.currentBreakMinutes ||
        (choice == AdaptiveFocusReviewChoice.acceptSuggestion &&
            !reviewed.changesAnything)) {
      return null;
    }

    return AdaptiveFocusReviewDecision(
      choice: choice,
      reviewedSuggestion: reviewed,
      focusMinutes: choice == AdaptiveFocusReviewChoice.acceptSuggestion
          ? reviewed.suggestedFocusMinutes
          : reviewed.currentFocusMinutes,
      breakMinutes: choice == AdaptiveFocusReviewChoice.acceptSuggestion
          ? reviewed.suggestedBreakMinutes
          : reviewed.currentBreakMinutes,
    );
  }

  /// Invalidates the exact review when its surface is dismissed or replaced.
  bool cancel(AdaptiveFocusReviewTicket ticket) {
    if (_activeGeneration != ticket._generation) return false;
    _activeGeneration = null;
    return true;
  }
}
