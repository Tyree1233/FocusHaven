import '../models/adaptive_focus_delegation.dart';
import '../models/adaptive_focus_review.dart';
import '../models/adaptive_focus_suggestion.dart';
import 'adaptive_focus_review_service.dart';
import 'timer_service.dart';

/// An opaque, single-use capability for one exact owner-ready review.
final class AdaptiveFocusOwnerReviewTicket {
  const AdaptiveFocusOwnerReviewTicket._(
    this._generation,
    this._suggestion,
    this._reviewTicket,
  );

  final int _generation;
  final AdaptiveFocusSuggestion _suggestion;
  final AdaptiveFocusReviewTicket _reviewTicket;
}

/// Settles an explicit adaptive review at the authoritative timer boundary.
///
/// This service owns no presentation, localization, persistence, network, or
/// AI behavior. It can only ask [TimerService] to atomically apply one exact,
/// freshly reviewed pair while the Focus timer remains completely ready.
class AdaptiveFocusDelegationService {
  factory AdaptiveFocusDelegationService({
    required TimerService timer,
    AdaptiveFocusReviewService? reviewService,
  }) => AdaptiveFocusDelegationService._(
    timer,
    reviewService ?? AdaptiveFocusReviewService(),
  );

  AdaptiveFocusDelegationService._(this._timer, this._reviewService);

  final TimerService _timer;
  final AdaptiveFocusReviewService _reviewService;
  int _nextGeneration = 0;
  int? _activeGeneration;

  AdaptiveFocusOwnerReviewTicket? beginReview(
    AdaptiveFocusSuggestion suggestion,
  ) {
    if (!_timer.canApplyReviewedAdaptiveDurations ||
        !_hasWholeMinuteDefaults ||
        suggestion.currentFocusMinutes != _currentFocusMinutes ||
        suggestion.currentBreakMinutes != _currentBreakMinutes) {
      return null;
    }

    final generation = ++_nextGeneration;
    _activeGeneration = generation;
    return AdaptiveFocusOwnerReviewTicket._(
      generation,
      suggestion,
      _reviewService.beginReview(suggestion),
    );
  }

  AdaptiveFocusDelegationResult settleAndApply({
    required AdaptiveFocusOwnerReviewTicket ticket,
    required AdaptiveFocusSuggestion latestSuggestion,
    required AdaptiveFocusReviewChoice choice,
  }) {
    if (_activeGeneration != ticket._generation) {
      return AdaptiveFocusDelegationResult.rejected;
    }
    _activeGeneration = null;

    if (!_timer.canApplyReviewedAdaptiveDurations || !_hasWholeMinuteDefaults) {
      _reviewService.cancel(ticket._reviewTicket);
      return AdaptiveFocusDelegationResult.rejected;
    }

    final decision = _reviewService.settle(
      ticket: ticket._reviewTicket,
      latestSuggestion: latestSuggestion,
      currentFocusMinutes: _currentFocusMinutes,
      currentBreakMinutes: _currentBreakMinutes,
      choice: choice,
    );
    if (decision == null || decision.reviewedSuggestion != ticket._suggestion) {
      return AdaptiveFocusDelegationResult.rejected;
    }

    if (decision.keepsCurrent) {
      return AdaptiveFocusDelegationResult.keptCurrent(
        focusMinutes: decision.focusMinutes,
        breakMinutes: decision.breakMinutes,
      );
    }

    final applied = _timer.applyReviewedAdaptiveDurations(
      expectedFocusSeconds: ticket._suggestion.currentFocusMinutes * 60,
      expectedBreakSeconds: ticket._suggestion.currentBreakMinutes * 60,
      focusSeconds: decision.focusMinutes * 60,
      breakSeconds: decision.breakMinutes * 60,
    );
    if (!applied) return AdaptiveFocusDelegationResult.rejected;

    return AdaptiveFocusDelegationResult.applied(
      focusMinutes: decision.focusMinutes,
      breakMinutes: decision.breakMinutes,
    );
  }

  /// Invalidates the exact owner ticket when its review is dismissed.
  bool cancel(AdaptiveFocusOwnerReviewTicket ticket) {
    if (_activeGeneration != ticket._generation) return false;
    _activeGeneration = null;
    return _reviewService.cancel(ticket._reviewTicket);
  }

  bool get _hasWholeMinuteDefaults =>
      _timer.focusDurationSeconds % 60 == 0 &&
      _timer.shortBreakDurationSeconds % 60 == 0;
  int get _currentFocusMinutes => _timer.focusDurationSeconds ~/ 60;
  int get _currentBreakMinutes => _timer.shortBreakDurationSeconds ~/ 60;
}
