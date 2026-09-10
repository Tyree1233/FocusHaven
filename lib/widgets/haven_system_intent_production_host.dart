import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/focus_haven_localizations.dart';
import '../models/haven_action.dart';
import '../providers/app_providers.dart';
import '../services/focus_queue_service.dart';
import '../services/haven_action_engine.dart';
import '../services/haven_system_intent_inbox.dart';
import '../services/haven_system_intent_review_service.dart';
import '../services/haven_system_intent_service.dart';
import '../services/timer_service.dart';
import 'completed_tasks_sheet.dart';
import 'focus_queue_sheet.dart';
import 'haven_system_intent_review_card.dart';
import 'text_entry_dialog.dart';

/// App-level, localized host for one short-lived system-assistant review.
///
/// The host sits above the current route, but receives only text-free requests
/// from [HavenSystemIntentInbox]. It owns no native listener. Every request is
/// prepared by [HavenSystemIntentService], bound to fresh owner state by
/// [HavenSystemIntentReviewService], and settled only through the existing
/// [HavenActionEngine].
final class HavenSystemIntentProductionHost extends ConsumerStatefulWidget {
  const HavenSystemIntentProductionHost({
    required this.navigatorKey,
    required this.child,
    super.key,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  ConsumerState<HavenSystemIntentProductionHost> createState() =>
      _HavenSystemIntentProductionHostState();
}

final class _HavenSystemIntentProductionHostState
    extends ConsumerState<HavenSystemIntentProductionHost> {
  final HavenSystemIntentService _intentService = HavenSystemIntentService();
  late final HavenSystemIntentInbox _inbox;
  late final TimerService _timerService;
  late final FocusQueueService _focusQueueService;
  late final HavenSystemIntentReviewService _reviewService;
  HavenSystemIntentReview? _review;
  Timer? _expiryTimer;
  bool _drainScheduled = false;

  @override
  void initState() {
    super.initState();
    _inbox = ref.read(havenSystemIntentInboxProvider);
    _timerService = ref.read(timerServiceProvider);
    _focusQueueService = ref.read(focusQueueServiceProvider);
    _reviewService = HavenSystemIntentReviewService(
      engine: HavenActionEngine(
        executor: HavenActionExecutor(
          timer: _timerService,
          focusQueue: _focusQueueService,
          openSurface: _openSurface,
        ),
      ),
    );
    _inbox.addListener(_scheduleDrain);
    _timerService.addListener(_ownerStateChanged);
    _focusQueueService.addListener(_ownerStateChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleDrain();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _inbox.removeListener(_scheduleDrain);
    _timerService.removeListener(_ownerStateChanged);
    _focusQueueService.removeListener(_ownerStateChanged);
    final review = _review;
    if (review != null) _reviewService.dismiss(review);
    super.dispose();
  }

  void _scheduleDrain() {
    if (_drainScheduled || !mounted) return;
    _drainScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _drainScheduled = false;
      if (mounted) _drainInbox();
    });
  }

  void _drainInbox() {
    final request = _inbox.takePendingRequest();
    if (request == null) return;

    final prepared = _intentService.prepare(request);
    final draft = prepared.draft;
    if (draft == null) return;

    final result = _reviewService.prepareReview(
      draft,
      localizations: context.l10n,
    );
    final review = result.review;
    _expiryTimer?.cancel();
    if (review == null) {
      if (_review != null) setState(() => _review = null);
      return;
    }

    setState(() => _review = review);
    final remaining = review.expiresAtUtc.difference(DateTime.now().toUtc());
    if (remaining <= Duration.zero) {
      _invalidateReview();
    } else {
      _expiryTimer = Timer(remaining, _invalidateReview);
    }
  }

  void _ownerStateChanged() {
    final review = _review;
    if (review == null || !mounted) return;
    if (!_reviewService.isCurrent(review, localizations: context.l10n)) {
      _invalidateReview();
    }
  }

  void _invalidateReview() {
    final review = _review;
    if (review == null || !mounted) return;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _reviewService.dismiss(review);
    setState(() => _review = null);
  }

  Future<void> _dismiss(HavenSystemIntentReview review) async {
    if (!identical(_review, review)) return;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _reviewService.dismiss(review);
    if (mounted) setState(() => _review = null);
  }

  Future<void> _confirm(HavenSystemIntentReview review) async {
    if (!identical(_review, review)) return;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    final result = await _reviewService.confirm(
      review,
      localizations: context.l10n,
    );
    if (!mounted) return;
    setState(() => _review = null);
    final message = result.actionResult?.message;
    if (message != null && message.trim().isNotEmpty) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _dateLabel(BuildContext context, DateTime date) {
    final localDate = date.toLocal();
    final now = DateTime.now().toLocal();
    if (DateUtils.isSameDay(localDate, now)) return context.l10n.dateToday;
    if (DateUtils.isSameDay(localDate, now.subtract(const Duration(days: 1)))) {
      return context.l10n.dateYesterday;
    }
    return MaterialLocalizations.of(context).formatShortDate(localDate);
  }

  Future<void> _editQueueTask(BuildContext context, FocusQueueItem item) async {
    final updated = await TextEntryDialog.show(
      context,
      title: context.l10n.focusQueueEditTitle,
      confirmLabel: context.l10n.focusQueueEditSave,
      initialValue: item.title,
      hintText: context.l10n.focusQueueTaskHint,
      maxLength: 100,
      hideCounter: true,
    );
    if (updated != null) await _focusQueueService.rename(item.id, updated);
  }

  Future<void> _showCompletedTasks(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => CompletedTasksSheet(
        dateLabel: (date) => _dateLabel(sheetContext, date),
      ),
    );
  }

  Future<bool> _openSurface(HavenActionSurface surface) async {
    if (surface != HavenActionSurface.focusQueue) return false;
    final navigatorContext = widget.navigatorKey.currentContext;
    if (!mounted || navigatorContext == null) return false;
    await showModalBottomSheet<void>(
      context: navigatorContext,
      backgroundColor: Theme.of(navigatorContext).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => FocusQueueSheet(
        onTaskSelected: ref.read(havenLoopServiceProvider).selectQueueItem,
        onEditTask: (item) => _editQueueTask(sheetContext, item),
        onShowCompleted: () => _showCompletedTasks(sheetContext),
      ),
    );
    return true;
  }

  HavenSystemIntentReviewCopy _copyFor(HavenSystemIntentReview review) {
    final l10n = context.l10n;
    final risk = switch (review.risk) {
      HavenActionRisk.informational =>
        l10n.systemAssistantReviewInformationalRisk,
      HavenActionRisk.reversibleControl =>
        l10n.systemAssistantReviewReversibleRisk,
      HavenActionRisk.statefulEdit => throw StateError(
        'System-assistant reviews cannot carry stateful-edit risk.',
      ),
    };
    return HavenSystemIntentReviewCopy(
      eyebrow: l10n.systemAssistantReviewEyebrow,
      title: l10n.systemAssistantReviewTitle,
      sourceBoundary: l10n.systemAssistantReviewSource,
      privacyBoundary: l10n.systemAssistantReviewPrivacy,
      freshnessBoundary: l10n.systemAssistantReviewFreshness,
      confirmationBoundary: l10n.systemAssistantReviewConfirmation,
      riskLabel: risk,
      summarySemantics: l10n.systemAssistantReviewSummary(
        review.interpretation,
        review.effect,
        risk,
      ),
      dismissAction: l10n.systemAssistantReviewDismiss,
      confirmAction: l10n.systemAssistantReviewConfirm,
    );
  }

  @override
  Widget build(BuildContext context) {
    final review = _review;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (review != null)
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            bottom: 12,
            child: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: SingleChildScrollView(
                    child: HavenSystemIntentReviewCard(
                      review: review,
                      copy: _copyFor(review),
                      onDismiss: _dismiss,
                      onConfirm: _confirm,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
