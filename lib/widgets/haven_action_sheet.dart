import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/focus_haven_localizations.dart';
import '../l10n/voice_transcription_localizations.dart';
import '../models/haven_action.dart';
import '../services/focus_queue_service.dart';
import '../services/haven_action_engine.dart';
import '../services/haven_action_interpreter.dart';
import '../services/timer_service.dart';
import '../services/voice_transcription_service.dart';
import 'confirmation_dialog.dart';

class HavenActionSheet extends StatefulWidget {
  const HavenActionSheet({
    required this.timerService,
    required this.focusQueueService,
    required this.voiceTranscriptionService,
    required this.onOpenSurface,
    this.interpreter,
    super.key,
  });

  final TimerService timerService;
  final FocusQueueService focusQueueService;
  final VoiceTranscriptionService voiceTranscriptionService;
  final Future<void> Function(HavenActionSurface surface) onOpenSurface;
  final HavenActionInterpreter? interpreter;

  @override
  State<HavenActionSheet> createState() => _HavenActionSheetState();
}

class _HavenActionSheetState extends State<HavenActionSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  late final HavenActionInterpreter _interpreter;
  late final HavenActionExecutor _executor;
  late final HavenActionEngine _engine;
  late final VoiceTranscriptionService _voiceTranscription;
  HavenActionProposal? _proposal;
  String? _message;
  String _draftBeforeVoice = '';
  String _draftPrefix = '';
  String _lastVoiceTranscript = '';
  HavenActionSource _inputSource = HavenActionSource.typed;
  bool _voiceSessionActive = false;
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
    _voiceTranscription = widget.voiceTranscriptionService
      ..addListener(_syncVoiceTranscript);
  }

  @override
  void dispose() {
    _voiceTranscription.removeListener(_syncVoiceTranscript);
    if (_voiceSessionActive ||
        _voiceTranscription.isListening ||
        _voiceTranscription.isBusy) {
      unawaited(_voiceTranscription.cancel());
    }
    _controller.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _syncVoiceTranscript() {
    if (!mounted) return;
    final transcript = _voiceTranscription.transcript;
    if (_voiceSessionActive && transcript != _lastVoiceTranscript) {
      _lastVoiceTranscript = transcript;
      final separator = _draftPrefix.isEmpty || transcript.isEmpty ? '' : ' ';
      final draft = '$_draftPrefix$separator$transcript';
      _controller.value = TextEditingValue(
        text: draft,
        selection: TextSelection.collapsed(offset: draft.length),
      );
    }
    setState(() {});
  }

  Future<void> _startVoiceTranscription() async {
    if (_busy ||
        _proposal != null ||
        _voiceTranscription.isListening ||
        _voiceTranscription.isBusy) {
      return;
    }

    if (!_voiceTranscription.disclosureAcknowledgedFor(
      VoiceTranscriptionPurpose.havenAction,
    )) {
      final confirmed = await ConfirmationDialog.show(
        context,
        title: context.l10n.havenActionVoiceDisclosureTitle,
        message: context.l10n.havenActionVoiceDisclosureMessage,
        cancelLabel: context.l10n.voiceKeepTyping,
        confirmLabel: context.l10n.voiceContinueToMicrophone,
      );
      if (!confirmed || !mounted) return;
      _voiceTranscription.acknowledgeDisclosure(
        VoiceTranscriptionPurpose.havenAction,
      );
    }

    _draftBeforeVoice = _controller.text;
    _draftPrefix = _controller.text.trimRight();
    _lastVoiceTranscript = '';
    _inputSource = HavenActionSource.voiceTranscript;
    _voiceSessionActive = true;
    setState(() {
      _proposal = null;
      _message = null;
    });
    final started = await _voiceTranscription.start(
      purpose: VoiceTranscriptionPurpose.havenAction,
    );
    if (!started && mounted) {
      _voiceSessionActive = false;
      _inputSource = HavenActionSource.typed;
      setState(() {});
      _inputFocusNode.requestFocus();
    }
  }

  Future<void> _stopVoiceTranscription() async {
    await _voiceTranscription.stop();
    if (!mounted) return;
    setState(() {});
    _inputFocusNode.requestFocus();
  }

  Future<void> _discardVoiceTranscription() async {
    await _voiceTranscription.cancel();
    if (!mounted) return;
    _voiceSessionActive = false;
    _lastVoiceTranscript = '';
    _draftPrefix = '';
    _inputSource = HavenActionSource.typed;
    _controller.value = TextEditingValue(
      text: _draftBeforeVoice,
      selection: TextSelection.collapsed(offset: _draftBeforeVoice.length),
    );
    setState(() {
      _proposal = null;
      _message = null;
    });
    _inputFocusNode.requestFocus();
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
    if (_busy ||
        _voiceTranscription.isListening ||
        _voiceTranscription.isBusy) {
      return;
    }
    _voiceSessionActive = false;
    final interpretation = _interpreter.interpret(
      _controller.text,
      _executor.snapshot(),
      source: _inputSource,
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
    if (decision.allowed) {
      _inputFocusNode.unfocus();
    }
  }

  void _changeRequest() {
    if (_busy) return;
    setState(() {
      _proposal = null;
      _message = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocusNode.requestFocus();
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
      _proposal = null;
      if (result.executed) {
        _controller.clear();
        _inputSource = HavenActionSource.typed;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final proposal = _proposal;
    final voice = _voiceTranscription;
    final voiceBlocksReview = voice.isListening || voice.isBusy;
    final proposalSourceLabel = proposal == null
        ? null
        : proposal.source == HavenActionSource.voiceTranscript
        ? l10n.havenActionSourceVoice
        : l10n.havenActionSourceTyped;
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
                Expanded(
                  child: Text(
                    l10n.havenActionTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.havenActionCloseTooltip,
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              l10n.havenActionIntroduction,
              style: const TextStyle(height: 1.35),
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.privacy_tip_outlined, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.havenActionPrivateBoundary,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_voiceSessionActive || voice.isListening || voice.isBusy) ...[
              DecoratedBox(
                key: const ValueKey('havenActionVoiceListening'),
                decoration: BoxDecoration(
                  color: colors.secondaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.mic_outlined, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              voice.isListening
                                  ? l10n.havenActionVoiceListening
                                  : voice.isBusy
                                  ? l10n.havenActionVoicePreparing
                                  : l10n.havenActionVoiceReady,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton(
                            key: const ValueKey('discardHavenActionVoice'),
                            onPressed: voice.isBusy
                                ? null
                                : _discardVoiceTranscription,
                            child: Text(l10n.voiceDiscard),
                          ),
                          if (voice.isListening)
                            FilledButton.tonal(
                              key: const ValueKey('stopHavenActionVoice'),
                              onPressed: _stopVoiceTranscription,
                              child: Text(l10n.havenActionVoiceStop),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (voice.noticeCode != null) ...[
              Semantics(
                liveRegion: true,
                child: DecoratedBox(
                  key: const ValueKey('havenActionVoiceNotice'),
                  decoration: BoxDecoration(
                    color: colors.errorContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.mic_off_outlined, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            localizeVoiceTranscriptionNotice(
                              l10n,
                              voice.noticeCode!,
                            ),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('dismissHavenActionVoiceNotice'),
                          tooltip: l10n.voiceDismissNotice,
                          onPressed: voice.dismissNotice,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              key: const ValueKey('havenActionInput'),
              controller: _controller,
              focusNode: _inputFocusNode,
              autofocus: true,
              enabled: !_busy && !voiceBlocksReview,
              maxLength: HavenActionInterpreter.maxInputLength,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _review(),
              onChanged: (value) {
                if (value.isEmpty) {
                  _inputSource = HavenActionSource.typed;
                  _voiceSessionActive = false;
                }
                if (_proposal != null || _message != null) {
                  setState(() {
                    _proposal = null;
                    _message = null;
                  });
                }
              },
              decoration: InputDecoration(
                labelText: l10n.havenActionInputLabel,
                hintText: l10n.havenActionInputHint,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  key: const ValueKey('havenActionVoiceInput'),
                  tooltip: voice.isListening
                      ? l10n.havenActionVoiceStopTooltip
                      : l10n.havenActionVoiceDictateTooltip,
                  onPressed: _busy || voice.isBusy || proposal != null
                      ? null
                      : voice.isListening
                      ? _stopVoiceTranscription
                      : _startVoiceTranscription,
                  icon: Icon(
                    voice.isListening ? Icons.stop_circle : Icons.mic_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const ValueKey('reviewHavenAction'),
              onPressed: _busy || voiceBlocksReview ? null : _review,
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(l10n.havenActionReview),
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
              Semantics(
                container: true,
                liveRegion: true,
                label: _proposalSemanticsLabel(l10n, proposal),
                child: ExcludeSemantics(
                  child: Card(
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
                          const SizedBox(height: 6),
                          Text(
                            proposalSourceLabel!,
                            key: const ValueKey('havenActionProposalSource'),
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            proposal.effect,
                            style: const TextStyle(height: 1.35),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _riskLabel(l10n, proposal.risk),
                            style: TextStyle(
                              color: colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const ValueKey('changeHavenAction'),
                onPressed: _busy ? null : _changeRequest,
                icon: const Icon(Icons.edit_outlined),
                label: Text(l10n.havenActionChangeRequest),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const ValueKey('executeHavenAction'),
                onPressed: _busy ? null : _execute,
                child: Text(
                  _busy
                      ? l10n.havenActionWorking
                      : proposal.confirmationRequired
                      ? l10n.havenActionConfirmExact
                      : l10n.havenActionRunReviewed,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              l10n.havenActionExamples,
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

  String _proposalSemanticsLabel(
    AppLocalizations l10n,
    HavenActionProposal proposal,
  ) {
    final source = proposal.source == HavenActionSource.voiceTranscript
        ? l10n.havenActionSemanticsSourceVoice
        : l10n.havenActionSemanticsSourceTyped;
    final nextStep = proposal.confirmationRequired
        ? l10n.havenActionSemanticsNextConfirm
        : l10n.havenActionSemanticsNextRun;
    return l10n.havenActionProposalSemantics(
      source,
      proposal.interpretation,
      proposal.effect,
      _riskLabel(l10n, proposal.risk),
      nextStep,
    );
  }

  String _riskLabel(AppLocalizations l10n, HavenActionRisk risk) =>
      switch (risk) {
        HavenActionRisk.informational => l10n.havenActionRiskInformational,
        HavenActionRisk.reversibleControl => l10n.havenActionRiskReversible,
        HavenActionRisk.statefulEdit => l10n.havenActionRiskStateful,
      };
}
