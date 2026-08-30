import 'package:flutter/material.dart';

import '../models/haven_action.dart';
import '../services/focus_queue_service.dart';
import '../services/haven_action_engine.dart';
import '../services/haven_action_interpreter.dart';
import '../services/timer_service.dart';

class HavenActionSheet extends StatefulWidget {
  const HavenActionSheet({
    required this.timerService,
    required this.focusQueueService,
    required this.onOpenSurface,
    this.interpreter,
    super.key,
  });

  final TimerService timerService;
  final FocusQueueService focusQueueService;
  final Future<void> Function(HavenActionSurface surface) onOpenSurface;
  final HavenActionInterpreter? interpreter;

  @override
  State<HavenActionSheet> createState() => _HavenActionSheetState();
}

class _HavenActionSheetState extends State<HavenActionSheet> {
  final TextEditingController _controller = TextEditingController();
  late final HavenActionInterpreter _interpreter;
  late final HavenActionExecutor _executor;
  late final HavenActionEngine _engine;
  HavenActionProposal? _proposal;
  String? _message;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _interpreter = widget.interpreter ?? HavenActionInterpreter();
    _executor = HavenActionExecutor(
      timer: widget.timerService,
      focusQueue: widget.focusQueueService,
      openSurface: _openSurface,
    );
    _engine = HavenActionEngine(executor: _executor);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _openSurface(HavenActionSurface surface) async {
    if (!mounted) return false;
    final openSurface = widget.onOpenSurface;
    final closed = await Navigator.of(context).maybePop();
    if (!closed) return false;
    await Future<void>.delayed(Duration.zero);
    await openSurface(surface);
    return true;
  }

  void _review() {
    if (_busy) return;
    final interpretation = _interpreter.interpret(
      _controller.text,
      _executor.snapshot(),
    );
    final proposal = interpretation.proposal;
    if (proposal == null) {
      setState(() {
        _proposal = null;
        _message = interpretation.message;
      });
      return;
    }
    final decision = _engine.evaluate(proposal);
    setState(() {
      _proposal = decision.allowed ? proposal : null;
      _message = decision.allowed ? null : decision.message;
    });
  }

  Future<void> _execute() async {
    final proposal = _proposal;
    if (_busy || proposal == null) return;
    setState(() => _busy = true);
    final confirmation = proposal.confirmationRequired
        ? HavenActionConfirmation.forProposal(proposal)
        : null;
    final result = await _engine.execute(proposal, confirmation: confirmation);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = result.message;
      if (result.executed) _proposal = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final proposal = _proposal;
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
                Icon(Icons.bolt_outlined, color: colors.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Haven actions',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Close Haven actions',
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Text(
              'Type one local action. Haven will show what it understood before anything runs.',
              style: TextStyle(height: 1.35),
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.privacy_tip_outlined, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Typed locally • no microphone • no remote AI',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('havenActionInput'),
              controller: _controller,
              enabled: !_busy,
              maxLength: HavenActionInterpreter.maxInputLength,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _review(),
              onChanged: (_) {
                if (_proposal != null || _message != null) {
                  setState(() {
                    _proposal = null;
                    _message = null;
                  });
                }
              },
              decoration: const InputDecoration(
                labelText: 'What should Haven do?',
                hintText: 'Example: add 5 minutes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const ValueKey('reviewHavenAction'),
              onPressed: _busy ? null : _review,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Review action'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 14),
              Semantics(
                liveRegion: true,
                child: Text(
                  _message!,
                  key: const ValueKey('havenActionMessage'),
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
            ],
            if (proposal != null) ...[
              const SizedBox(height: 18),
              Card(
                key: const ValueKey('havenActionProposal'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        proposal.interpretation,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        proposal.effect,
                        style: const TextStyle(height: 1.35),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _riskLabel(proposal.risk),
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                key: const ValueKey('executeHavenAction'),
                onPressed: _busy ? null : _execute,
                child: Text(
                  _busy
                      ? 'Working…'
                      : proposal.confirmationRequired
                      ? 'Confirm exact action'
                      : 'Run reviewed action',
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Try: “timer status,” “start focus,” “pause,” “resume,” “add 5 minutes,” “open Focus Queue,” or “add task: Review notes.”',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _riskLabel(HavenActionRisk risk) => switch (risk) {
    HavenActionRisk.informational => 'Informational • no saved-data change',
    HavenActionRisk.reversibleControl => 'Reversible timer control',
    HavenActionRisk.statefulEdit => 'Saved local edit • confirmation required',
  };
}
