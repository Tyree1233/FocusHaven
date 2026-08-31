import 'package:flutter/material.dart';

import '../models/haven_planner_proposal.dart';
import '../services/focus_queue_service.dart';
import '../services/haven_action_engine.dart';
import '../services/haven_action_interpreter.dart';
import '../services/haven_planner_action_service.dart';
import '../services/haven_planner_service.dart';
import '../services/timer_service.dart';
import 'confirmation_dialog.dart';

class HavenPlannerSheet extends StatefulWidget {
  const HavenPlannerSheet({
    required this.timerService,
    required this.focusQueueService,
    required this.plannerService,
    this.interpreter,
    this.actionClock,
    super.key,
  });

  final TimerService timerService;
  final FocusQueueService focusQueueService;
  final HavenPlannerService plannerService;
  final HavenActionInterpreter? interpreter;
  final DateTime Function()? actionClock;

  @override
  State<HavenPlannerSheet> createState() => _HavenPlannerSheetState();
}

class _HavenPlannerSheetState extends State<HavenPlannerSheet> {
  final TextEditingController _goalController = TextEditingController();
  final Map<String, TextEditingController> _itemControllers = {};
  final Map<String, HavenPlannerReviewChoice> _choices = {};
  late final HavenActionExecutor _executor;
  late final HavenActionEngine _engine;
  late final HavenPlannerActionService _actionService;
  HavenPlannerProposal? _proposal;
  int _availableMinutes = 60;
  int _focusMinutes = 25;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _executor = HavenActionExecutor(
      timer: widget.timerService,
      focusQueue: widget.focusQueueService,
      openSurface: (_) async => false,
    );
    _engine = HavenActionEngine(
      executor: _executor,
      clock: widget.actionClock,
    );
    _actionService = HavenPlannerActionService(
      interpreter: widget.interpreter ?? HavenActionInterpreter(),
      engine: _engine,
      executor: _executor,
      clock: widget.actionClock,
    );
  }

  @override
  void dispose() {
    _goalController.dispose();
    for (final controller in _itemControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _createDraft() {
    if (_busy) return;
    try {
      final proposal = widget.plannerService.createProposal(
        goal: _goalController.text,
        availableMinutes: _availableMinutes,
        preferredFocusMinutes: _focusMinutes,
      );
      for (final controller in _itemControllers.values) {
        controller.dispose();
      }
      _itemControllers.clear();
      _choices.clear();
      for (final item in proposal.items) {
        _choices[item.id] = HavenPlannerReviewChoice.pending;
        if (item.canEdit) {
          _itemControllers[item.id] = TextEditingController(text: item.title);
        }
      }
      setState(() {
        _proposal = proposal;
        _message = null;
      });
    } on ArgumentError catch (error) {
      setState(() {
        _proposal = null;
        _message = error.message?.toString() ?? 'Enter one goal to plan.';
      });
    }
  }

  void _settle(HavenPlannerItem item, HavenPlannerReviewChoice choice) {
    if (_busy) return;
    setState(() {
      _choices[item.id] = choice;
      _message = null;
    });
  }

  bool get _allItemsSettled =>
      _proposal != null &&
      _proposal!.items.every(
        (item) => _choices[item.id] != HavenPlannerReviewChoice.pending,
      );

  List<String>? _acceptedQueueTitles() {
    final proposal = _proposal;
    if (proposal == null) return null;
    final titles = <String>[];
    for (final item in proposal.items) {
      final choice = _choices[item.id];
      if (item.kind != HavenPlannerItemKind.queueTask ||
          (choice != HavenPlannerReviewChoice.accepted &&
              choice != HavenPlannerReviewChoice.edited)) {
        continue;
      }
      final title = _itemControllers[item.id]!.text.trim().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
      if (title.isEmpty || title.length > 100) return null;
      titles.add(title);
    }
    return titles;
  }

  Future<void> _applyReview() async {
    if (_busy || !_allItemsSettled) return;
    final titles = _acceptedQueueTitles();
    if (titles == null) {
      setState(() {
        _message = 'Each accepted queue item must be 1–100 characters.';
      });
      return;
    }
    if (titles.isEmpty) {
      setState(() {
        _proposal = null;
        _message = 'Review complete. Nothing was changed.';
      });
      return;
    }

    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Add reviewed tasks?',
      message:
          'Add only these ${titles.length} reviewed ${titles.length == 1 ? 'item' : 'items'} to Focus Queue?\n\n• ${titles.join('\n• ')}\n\nThe timer will not start or change, and no calendar event will be created.',
      cancelLabel: 'Keep reviewing',
      confirmLabel: 'Add to Focus Queue',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    final results = await _actionService.addReviewedQueueItems(titles);
    if (!mounted) return;
    final added = results.where((result) => result.added).length;
    final failed = results.length - added;
    setState(() {
      _busy = false;
      _proposal = null;
      _message = failed == 0
          ? '$added reviewed ${added == 1 ? 'task was' : 'tasks were'} added to Focus Queue. The timer and calendar were unchanged.'
          : '$added tasks were added; $failed could not be added. The timer and calendar were unchanged.';
    });
  }

  void _startOver() {
    if (_busy) return;
    setState(() {
      _proposal = null;
      _message = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final proposal = _proposal;
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.route_outlined, color: colors.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Plan a goal',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Local planner foundation • no remote AI',
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Haven drafts possibilities from only what you enter. Nothing is saved or changed until you review every item and confirm the exact queue additions.',
            ),
            const SizedBox(height: 18),
            if (proposal == null) ...[
              TextField(
                key: const ValueKey('havenPlannerGoal'),
                controller: _goalController,
                enabled: !_busy,
                maxLength: HavenPlannerService.maxGoalLength,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'What do you want to make progress on?',
                  hintText: 'Example: Prepare the first FocusHaven launch',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              const Text('Time available'),
              Wrap(
                spacing: 8,
                children: [
                  for (final minutes in const [30, 60, 90, 120])
                    ChoiceChip(
                      key: ValueKey('havenPlannerAvailable$minutes'),
                      label: Text('$minutes min'),
                      selected: _availableMinutes == minutes,
                      onSelected: _busy
                          ? null
                          : (_) => setState(() => _availableMinutes = minutes),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              const Text('Preferred focus block'),
              Wrap(
                spacing: 8,
                children: [
                  for (final minutes in const [10, 15, 25, 45, 60])
                    ChoiceChip(
                      key: ValueKey('havenPlannerFocus$minutes'),
                      label: Text('$minutes min'),
                      selected: _focusMinutes == minutes,
                      onSelected: _busy
                          ? null
                          : (_) => setState(() => _focusMinutes = minutes),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const ValueKey('createHavenPlannerDraft'),
                onPressed: _busy ? null : _createDraft,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Create local draft'),
              ),
            ] else ...[
              _ProposalContext(proposal: proposal),
              const SizedBox(height: 14),
              Semantics(
                liveRegion: true,
                label:
                    'Planner draft created with ${proposal.items.length} independently reviewable items. Nothing has changed.',
                child: const Text(
                  'Review each item',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              for (final item in proposal.items) ...[
                _PlannerItemCard(
                  item: item,
                  choice: _choices[item.id] ?? HavenPlannerReviewChoice.pending,
                  controller: _itemControllers[item.id],
                  enabled: !_busy,
                  onChoice: (choice) => _settle(item, choice),
                ),
                const SizedBox(height: 10),
              ],
              FilledButton(
                key: const ValueKey('applyHavenPlannerReview'),
                onPressed: _busy || !_allItemsSettled ? null : _applyReview,
                child: Text(_busy ? 'Applying…' : 'Apply reviewed choices'),
              ),
              TextButton(
                key: const ValueKey('startHavenPlannerOver'),
                onPressed: _busy ? null : _startOver,
                child: const Text('Start over'),
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  _message!,
                  key: const ValueKey('havenPlannerMessage'),
                  style: TextStyle(color: colors.primary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProposalContext extends StatelessWidget {
  const _ProposalContext({required this.proposal});

  final HavenPlannerProposal proposal;

  @override
  Widget build(BuildContext context) {
    final uncertainty = proposal.uncertainty.name;
    return Card(
      key: const ValueKey('havenPlannerProposalContext'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Inputs', style: Theme.of(context).textTheme.titleSmall),
            Text('Goal: ${proposal.input.goal}'),
            Text('Available: ${proposal.input.availableMinutes} minutes'),
            Text(
              'Preferred focus block: ${proposal.input.preferredFocusMinutes} minutes',
            ),
            const SizedBox(height: 10),
            Text('Assumptions', style: Theme.of(context).textTheme.titleSmall),
            for (final assumption in proposal.assumptions)
              Text('• $assumption'),
            const SizedBox(height: 10),
            Text(
              'Uncertainty: $uncertainty',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(proposal.uncertaintyExplanation),
            const SizedBox(height: 10),
            const Text(
              'Affected local data: temporary goal draft; Focus Queue only for accepted task items. Timer and calendar: no changes.',
            ),
          ],
        ),
      ),
    );
  }
}

class _PlannerItemCard extends StatelessWidget {
  const _PlannerItemCard({
    required this.item,
    required this.choice,
    required this.controller,
    required this.enabled,
    required this.onChoice,
  });

  final HavenPlannerItem item;
  final HavenPlannerReviewChoice choice;
  final TextEditingController? controller;
  final bool enabled;
  final ValueChanged<HavenPlannerReviewChoice> onChoice;

  @override
  Widget build(BuildContext context) {
    final isEditing = choice == HavenPlannerReviewChoice.edited;
    return Card(
      key: ValueKey('havenPlannerItem-${item.id}'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _kindLabel(item.kind),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            if (isEditing)
              TextField(
                key: ValueKey('havenPlannerEdit-${item.id}'),
                controller: controller,
                enabled: enabled,
                autofocus: true,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Reviewed queue item',
                  border: OutlineInputBorder(),
                ),
              )
            else
              Text(item.title),
            const SizedBox(height: 4),
            Text(item.explanation),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton(
                  key: ValueKey('havenPlannerAccept-${item.id}'),
                  onPressed: enabled
                      ? () => onChoice(HavenPlannerReviewChoice.accepted)
                      : null,
                  child: Text(
                    choice == HavenPlannerReviewChoice.accepted
                        ? 'Accepted'
                        : 'Accept',
                  ),
                ),
                if (item.canEdit)
                  OutlinedButton(
                    key: ValueKey('havenPlannerEditChoice-${item.id}'),
                    onPressed: enabled
                        ? () => onChoice(HavenPlannerReviewChoice.edited)
                        : null,
                    child: Text(isEditing ? 'Editing' : 'Edit'),
                  ),
                OutlinedButton(
                  key: ValueKey('havenPlannerReject-${item.id}'),
                  onPressed: enabled
                      ? () => onChoice(HavenPlannerReviewChoice.rejected)
                      : null,
                  child: Text(
                    choice == HavenPlannerReviewChoice.rejected
                        ? 'Rejected'
                        : 'Reject',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _kindLabel(HavenPlannerItemKind kind) => switch (kind) {
    HavenPlannerItemKind.queueTask => 'Possible Focus Queue task',
    HavenPlannerItemKind.sessionSuggestion => 'Session-size suggestion',
    HavenPlannerItemKind.freeTimeSuggestion => 'Optional free-time suggestion',
  };
}
