import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/focus_haven_localizations.dart';
import '../models/adaptive_focus_delegation.dart';
import '../models/adaptive_focus_review.dart';
import '../models/adaptive_focus_suggestion.dart';
import '../providers/app_providers.dart';
import '../services/adaptive_focus_delegation_service.dart';
import 'adaptive_focus_review_card.dart';

/// Production-localized adapter for one exact Adaptive Focus suggestion.
///
/// The adapter owns only the short-lived review ticket and presentation
/// dismissal. The timer owner still revalidates and applies every choice.
class AdaptiveFocusProductionReview extends ConsumerStatefulWidget {
  const AdaptiveFocusProductionReview({required this.suggestion, super.key});

  final AdaptiveFocusSuggestion suggestion;

  @override
  ConsumerState<AdaptiveFocusProductionReview> createState() =>
      _AdaptiveFocusProductionReviewState();
}

class _AdaptiveFocusProductionReviewState
    extends ConsumerState<AdaptiveFocusProductionReview> {
  late final AdaptiveFocusDelegationService _delegation;
  AdaptiveFocusOwnerReviewTicket? _ticket;
  AdaptiveFocusSuggestion? _settledSuggestion;
  bool _applied = false;

  @override
  void initState() {
    super.initState();
    _delegation = ref.read(adaptiveFocusDelegationServiceProvider);
    _ticket = _delegation.beginReview(widget.suggestion);
  }

  @override
  void didUpdateWidget(covariant AdaptiveFocusProductionReview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.suggestion == widget.suggestion) return;

    final ticket = _ticket;
    if (ticket != null) _delegation.cancel(ticket);
    _ticket = null;

    final settled = _settledSuggestion;
    final suppressAppliedContinuation =
        _applied &&
        settled != null &&
        widget.suggestion.currentFocusMinutes ==
            settled.suggestedFocusMinutes &&
        widget.suggestion.currentBreakMinutes ==
            settled.suggestedBreakMinutes &&
        _hasSameEvidence(widget.suggestion, settled);
    if (!suppressAppliedContinuation && widget.suggestion != settled) {
      _settledSuggestion = null;
      _applied = false;
      _ticket = _delegation.beginReview(widget.suggestion);
    }
  }

  @override
  void dispose() {
    final ticket = _ticket;
    if (ticket != null) _delegation.cancel(ticket);
    super.dispose();
  }

  bool _hasSameEvidence(
    AdaptiveFocusSuggestion first,
    AdaptiveFocusSuggestion second,
  ) =>
      first.basis == second.basis &&
      first.evidenceStrength == second.evidenceStrength &&
      first.relevantSignalCount == second.relevantSignalCount &&
      first.usesRecoveryPattern == second.usesRecoveryPattern &&
      first.usesLatestReflection == second.usesLatestReflection &&
      first.usesRepeatedRhythm == second.usesRepeatedRhythm &&
      first.usesForecast == second.usesForecast &&
      first.possibleWindow == second.possibleWindow;

  AdaptiveFocusSuggestion? _latestSuggestion() {
    final owner = ref.read(adaptiveFocusOwnerStateProvider);
    if (!owner.canReview) return null;
    return ref.read(
      adaptiveFocusSuggestionProvider((
        currentFocusMinutes: owner.focusMinutes,
        currentBreakMinutes: owner.breakMinutes,
        preserveCurrentChoice: false,
      )),
    );
  }

  Future<void> _settle(AdaptiveFocusReviewChoice choice) async {
    final ticket = _ticket;
    if (ticket == null) return;

    final latest = _latestSuggestion();
    final AdaptiveFocusDelegationResult result;
    if (latest == null) {
      _delegation.cancel(ticket);
      result = AdaptiveFocusDelegationResult.rejected;
    } else {
      result = _delegation.settleAndApply(
        ticket: ticket,
        latestSuggestion: latest,
        choice: choice,
      );
    }

    if (!mounted) return;
    setState(() {
      _ticket = null;
      _settledSuggestion = widget.suggestion;
      _applied = result.wasApplied;
    });

    final l10n = context.l10n;
    final message = switch (result.outcome) {
      AdaptiveFocusDelegationOutcome.applied => l10n.adaptiveFocusApplied(
        result.focusMinutes!,
        result.breakMinutes!,
      ),
      AdaptiveFocusDelegationOutcome.keptCurrent => l10n.adaptiveFocusKept,
      AdaptiveFocusDelegationOutcome.rejected => l10n.adaptiveFocusChanged,
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _reason() {
    final l10n = context.l10n;
    return switch (widget.suggestion.basis) {
      AdaptiveFocusBasis.recoveryPriority => l10n.adaptiveFocusRecoveryReason,
      AdaptiveFocusBasis.latestReflection => l10n.adaptiveFocusReflectionReason,
      AdaptiveFocusBasis.repeatedRhythm => l10n.adaptiveFocusRhythmReason,
      AdaptiveFocusBasis.explicitChoice ||
      AdaptiveFocusBasis.currentBaseline => l10n.adaptiveFocusRhythmReason,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_ticket == null || _settledSuggestion == widget.suggestion) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final suggestion = widget.suggestion;
    final reason = _reason();
    final forecastContext = suggestion.usesForecast
        ? l10n.adaptiveFocusForecastContext
        : null;
    final semanticReason = forecastContext == null
        ? reason
        : '$reason $forecastContext';

    return AdaptiveFocusReviewCard(
      suggestion: suggestion,
      copy: AdaptiveFocusReviewCopy(
        eyebrow: l10n.adaptiveFocusEyebrow,
        title: switch (suggestion.direction) {
          AdaptiveFocusDirection.gentler => l10n.adaptiveFocusGentlerTitle,
          AdaptiveFocusDirection.roomToGrow => l10n.adaptiveFocusGrowthTitle,
          AdaptiveFocusDirection.keepCurrent => l10n.adaptiveFocusGentlerTitle,
        },
        currentPlan: l10n.adaptiveFocusCurrentPlan(
          suggestion.currentFocusMinutes,
          suggestion.currentBreakMinutes,
        ),
        suggestedPlan: l10n.adaptiveFocusSuggestedPlan(
          suggestion.suggestedFocusMinutes,
          suggestion.suggestedBreakMinutes,
        ),
        reason: reason,
        forecastContext: forecastContext,
        privacyBoundary: l10n.adaptiveFocusPrivacy,
        noAutomaticChange: l10n.adaptiveFocusNoAutomaticChange,
        summarySemantics: l10n.adaptiveFocusReviewSummary(
          suggestion.currentFocusMinutes,
          suggestion.currentBreakMinutes,
          suggestion.suggestedFocusMinutes,
          suggestion.suggestedBreakMinutes,
          semanticReason,
        ),
        keepCurrentAction: l10n.adaptiveFocusKeepCurrent,
        acceptAction: l10n.adaptiveFocusUseSuggestion,
      ),
      onKeepCurrent: (_) => _settle(AdaptiveFocusReviewChoice.keepCurrent),
      onAccept: (_) => _settle(AdaptiveFocusReviewChoice.acceptSuggestion),
    );
  }
}
