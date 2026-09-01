import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../l10n/focus_haven_localizations.dart';
import '../l10n/voice_transcription_localizations.dart';
import '../models/coaching_message.dart';
import '../providers/app_providers.dart';
import '../services/coaching_service.dart';
import '../services/voice_transcription_service.dart';
import 'confirmation_dialog.dart';

typedef CoachingContextBuilder = CoachingContext Function();

class CoachingSheet extends ConsumerStatefulWidget {
  const CoachingSheet({required this.contextBuilder, super.key});

  final CoachingContextBuilder contextBuilder;

  @override
  ConsumerState<CoachingSheet> createState() => _CoachingSheetState();
}

class _CoachingSheetState extends ConsumerState<CoachingSheet> {
  static List<String> _starterPrompts(AppLocalizations l10n) => <String>[
    l10n.coachPromptHelpMeStart,
    l10n.coachPromptOverwhelmed,
    l10n.coachPromptWhatNext,
    l10n.coachPromptThinkThrough,
    l10n.coachPromptGentle,
    l10n.coachPromptListen,
    l10n.coachPromptAccountability,
  ];

  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isSubmitting = false;
  bool _isManagingHistory = false;
  late final VoiceTranscriptionService _voiceTranscription;
  String _draftBeforeVoice = '';
  String _draftPrefix = '';
  String _lastVoiceTranscript = '';
  int _lastConversationRevision = -1;

  static List<String> _quickRepliesFor(
    List<CoachingMessage> messages,
    AppLocalizations l10n,
  ) {
    if (messages.isEmpty || messages.last.role != CoachingMessageRole.coach) {
      return const [];
    }
    CoachingMessage? latestUserMessage;
    for (final message in messages.reversed) {
      if (message.role == CoachingMessageRole.user) {
        latestUserMessage = message;
        break;
      }
    }
    if (latestUserMessage == null ||
        LocalCoachingResponder.isSafetyConcern(latestUserMessage.text) ||
        LocalCoachingResponder.isBoundaryRequest(latestUserMessage.text)) {
      return const [];
    }

    if (LocalCoachingResponder.isRepairRequest(latestUserMessage.text)) {
      return <String>[
        l10n.coachPromptListen,
        l10n.coachPromptGentle,
        l10n.coachPromptAccountability,
      ];
    }

    if (LocalCoachingResponder.isReflectiveConversation(messages)) {
      return const [];
    }

    final coachReply = messages.last.text.toLowerCase();
    if (coachReply.contains('take a real five-minute break') ||
        coachReply.contains('let recovery count')) {
      return <String>[l10n.coachReplyBackAfterBreak];
    }
    if (coachReply.contains('listen without trying to fix')) {
      return <String>[
        l10n.coachPromptWhatNext,
        l10n.coachPromptGentle,
        l10n.coachPromptAccountability,
      ];
    }
    if (coachReply.startsWith('direct version') ||
        coachReply.startsWith('you asked me to stay direct')) {
      return <String>[
        l10n.coachReplyDidFirstStep,
        l10n.coachReplyStillStuck,
        l10n.coachReplyNeedBreak,
        l10n.coachPromptGentle,
      ];
    }
    if (coachReply.contains('i’ll keep this gentle') ||
        coachReply.startsWith(
          'i remember that you wanted a gentler approach',
        ) ||
        coachReply.startsWith('we can approach this gently')) {
      return <String>[
        l10n.coachReplyBreakItDown,
        l10n.coachPromptListen,
        l10n.coachReplyNeedBreak,
      ];
    }
    if (coachReply.startsWith('welcome back')) {
      return <String>[l10n.coachReplyDidFirstStep, l10n.coachReplyStillStuck];
    }
    if (coachReply.startsWith('that counts') ||
        coachReply.startsWith('that is real progress')) {
      return <String>[l10n.coachPromptWhatNext, l10n.coachReplyNeedBreak];
    }
    return <String>[
      l10n.coachReplyBreakItDown,
      l10n.coachReplyStillStuck,
      l10n.coachPromptListen,
    ];
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refreshDraftState);
    _voiceTranscription = ref.read(voiceTranscriptionServiceProvider)
      ..addListener(_syncVoiceTranscript);
  }

  void _refreshDraftState() {
    if (mounted) setState(() {});
  }

  void _syncVoiceTranscript() {
    if (!mounted) return;
    final transcript = _voiceTranscription.transcript;
    if (transcript == _lastVoiceTranscript) return;
    _lastVoiceTranscript = transcript;
    final separator = _draftPrefix.isEmpty || transcript.isEmpty ? '' : ' ';
    final draft = '$_draftPrefix$separator$transcript';
    _controller.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
  }

  @override
  void dispose() {
    _voiceTranscription.removeListener(_syncVoiceTranscript);
    if (_voiceTranscription.isListening || _voiceTranscription.isBusy) {
      unawaited(_voiceTranscription.cancel());
    }
    _controller
      ..removeListener(_refreshDraftState)
      ..dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startVoiceTranscription() async {
    if (_isSubmitting ||
        _isManagingHistory ||
        _voiceTranscription.isListening ||
        _voiceTranscription.isBusy) {
      return;
    }

    if (!_voiceTranscription.disclosureAcknowledged) {
      final confirmed = await ConfirmationDialog.show(
        context,
        title: context.l10n.coachVoiceDisclosureTitle,
        message: context.l10n.coachVoiceDisclosureMessage,
        cancelLabel: context.l10n.voiceKeepTyping,
        confirmLabel: context.l10n.voiceContinueToMicrophone,
      );
      if (!confirmed || !mounted) return;
      _voiceTranscription.acknowledgeDisclosure();
    }

    _draftBeforeVoice = _controller.text;
    _draftPrefix = _controller.text.trimRight();
    _lastVoiceTranscript = '';
    final started = await _voiceTranscription.start();
    if (!started && mounted) _inputFocusNode.requestFocus();
  }

  Future<void> _stopVoiceTranscription() async {
    await _voiceTranscription.stop();
    if (mounted) _inputFocusNode.requestFocus();
  }

  Future<void> _discardVoiceTranscription() async {
    await _voiceTranscription.cancel();
    if (!mounted) return;
    _lastVoiceTranscript = '';
    _draftPrefix = '';
    _controller.value = TextEditingValue(
      text: _draftBeforeVoice,
      selection: TextSelection.collapsed(offset: _draftBeforeVoice.length),
    );
    _inputFocusNode.requestFocus();
  }

  void _scheduleScrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  static bool _hasSameMessageIds(
    List<String> previousIds,
    List<CoachingMessage> currentMessages,
  ) {
    if (previousIds.length != currentMessages.length) return false;
    for (var index = 0; index < previousIds.length; index++) {
      if (previousIds[index] != currentMessages[index].id) return false;
    }
    return true;
  }

  Future<void> _send([String? suggestedMessage]) async {
    if (_isSubmitting ||
        _isManagingHistory ||
        _voiceTranscription.isListening ||
        _voiceTranscription.isBusy) {
      return;
    }
    final message = (suggestedMessage ?? _controller.text).trim();
    if (message.isEmpty) return;

    setState(() => _isSubmitting = true);
    if (suggestedMessage == null) _controller.clear();
    final coach = ref.read(coachingServiceProvider);
    final previousMessageIds = coach.messages
        .map((entry) => entry.id)
        .toList(growable: false);
    var sendCompleted = false;
    try {
      sendCompleted = await coach.send(
        message,
        widget.contextBuilder(),
        localizations: context.l10n,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(context.l10n.coachResponseFailed)),
          );
      }
    } finally {
      if (!sendCompleted &&
          mounted &&
          _controller.text.trim().isEmpty &&
          _hasSameMessageIds(previousMessageIds, coach.messages)) {
        _controller.value = TextEditingValue(
          text: message,
          selection: TextSelection.collapsed(offset: message.length),
        );
        _inputFocusNode.requestFocus();
      }
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _retryResponse() async {
    if (_isSubmitting ||
        _isManagingHistory ||
        _voiceTranscription.isListening ||
        _voiceTranscription.isBusy) {
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(coachingServiceProvider)
          .retryLastResponse(
            widget.contextBuilder(),
            localizations: context.l10n,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(context.l10n.coachResponseFailed)),
          );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _clearConversation() async {
    if (_isManagingHistory ||
        _isSubmitting ||
        _voiceTranscription.isListening ||
        _voiceTranscription.isBusy) {
      return;
    }
    setState(() => _isManagingHistory = true);
    try {
      final confirmed = await ConfirmationDialog.show(
        context,
        title: context.l10n.coachClearConversationTitle,
        message: context.l10n.coachClearConversationMessage,
        cancelLabel: context.l10n.coachKeepConversation,
        confirmLabel: context.l10n.coachClearConversation,
        isDestructive: true,
      );
      if (!confirmed || !mounted) return;
      await ref
          .read(coachingServiceProvider)
          .clearConversation(localizations: context.l10n);
    } finally {
      if (mounted) setState(() => _isManagingHistory = false);
    }
  }

  Future<void> _setEnhancedCoachingEnabled(bool enabled) async {
    if (_isManagingHistory ||
        _isSubmitting ||
        _voiceTranscription.isListening ||
        _voiceTranscription.isBusy) {
      return;
    }
    setState(() => _isManagingHistory = true);
    try {
      if (enabled) {
        final confirmed = await ConfirmationDialog.show(
          context,
          title: context.l10n.coachEnhancedDisclosureTitle,
          message: context.l10n.coachEnhancedDisclosureMessage,
          cancelLabel: context.l10n.coachEnhancedKeepLocal,
          confirmLabel: context.l10n.coachEnhancedEnable,
        );
        if (!confirmed || !mounted) return;
      }
      await ref
          .read(coachingServiceProvider)
          .setEnhancedCoachingEnabled(enabled, localizations: context.l10n);
    } finally {
      if (mounted) setState(() => _isManagingHistory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final coachingState = ref.watch(coachingStateProvider);
    final voiceState = ref.watch(voiceTranscriptionServiceProvider);
    if (coachingState.conversationRevision != _lastConversationRevision) {
      _lastConversationRevision = coachingState.conversationRevision;
      if (coachingState.messages.isNotEmpty || coachingState.isResponding) {
        _scheduleScrollToLatest();
      }
    }

    final isCoachBusy =
        coachingState.isResponding ||
        coachingState.isManagingPrivateData ||
        _isSubmitting ||
        _isManagingHistory;
    final voiceBlocksSubmission = voiceState.isListening || voiceState.isBusy;
    final isBusy = isCoachBusy || voiceBlocksSubmission;
    final isAwaitingResponseRetry = coachingState.canRetryResponse;
    final canSend =
        !isBusy &&
        !isAwaitingResponseRetry &&
        _controller.text.trim().isNotEmpty;
    final quickReplies =
        !isBusy &&
            !isAwaitingResponseRetry &&
            coachingState.errorMessage == null
        ? _quickRepliesFor(coachingState.messages, l10n)
        : const <String>[];
    final primaryColor = Theme.of(context).colorScheme.primary;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.88,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: primaryColor.withValues(alpha: 0.16),
                      foregroundColor: primaryColor,
                      child: const Icon(Icons.auto_awesome_outlined),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.coachTitle,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            coachingState.enhancedCoachingEnabled
                                ? l10n.coachSubtitleEnhanced
                                : l10n.coachSubtitlePrivate,
                            style: const TextStyle(color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const ValueKey<String>('coach-clear-history'),
                      tooltip: l10n.coachClearConversationTooltip,
                      onPressed: coachingState.messages.isEmpty || isBusy
                          ? null
                          : _clearConversation,
                      icon: _isManagingHistory
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline),
                    ),
                    IconButton(
                      tooltip: l10n.coachCloseTooltip,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (coachingState.enhancedCoachingAvailable) ...[
                SwitchListTile.adaptive(
                  key: const ValueKey<String>('coach-enhanced-ai-toggle'),
                  value: coachingState.enhancedCoachingEnabled,
                  onChanged: isBusy ? null : _setEnhancedCoachingEnabled,
                  secondary: const Icon(Icons.cloud_outlined),
                  title: Text(l10n.coachEnhancedTitle),
                  subtitle: Text(
                    coachingState.enhancedCoachingEnabled
                        ? l10n.coachEnhancedOnDescription
                        : l10n.coachEnhancedOffDescription,
                  ),
                ),
                const Divider(height: 1),
              ],
              Expanded(
                child: _ConversationBody(
                  messages: coachingState.messages,
                  isResponding: coachingState.isResponding,
                  starterPrompts: _starterPrompts(l10n),
                  primaryColor: primaryColor,
                  scrollController: _scrollController,
                  quickReplies: quickReplies,
                  promptsEnabled: !isBusy,
                  onPromptSelected: _send,
                ),
              ),
              if (coachingState.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.errorContainer.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(coachingState.errorMessage!)),
                        ],
                      ),
                    ),
                  ),
                ),
              if (coachingState.noticeMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: DecoratedBox(
                    key: const ValueKey<String>('coach-fallback-notice'),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 18,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(coachingState.noticeMessage!)),
                        ],
                      ),
                    ),
                  ),
                ),
              if (coachingState.canRetryResponse)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const ValueKey<String>('coach-retry-response'),
                      onPressed: isBusy ? null : _retryResponse,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.coachRetryResponse),
                    ),
                  ),
                ),
              if (voiceState.isListening || voiceState.isBusy)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Semantics(
                    liveRegion: true,
                    child: DecoratedBox(
                      key: const ValueKey<String>('coach-voice-listening'),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.mic, color: primaryColor, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    voiceState.isListening
                                        ? l10n.coachVoiceListening
                                        : l10n.coachVoicePreparing,
                                  ),
                                ),
                              ],
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 4,
                                children: [
                                  TextButton(
                                    key: const ValueKey<String>(
                                      'coach-discard-voice',
                                    ),
                                    onPressed: voiceState.isBusy
                                        ? null
                                        : _discardVoiceTranscription,
                                    child: Text(l10n.voiceDiscard),
                                  ),
                                  if (voiceState.isListening)
                                    FilledButton.tonal(
                                      key: const ValueKey<String>(
                                        'coach-stop-voice',
                                      ),
                                      onPressed: _stopVoiceTranscription,
                                      child: Text(l10n.coachVoiceStop),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (voiceState.noticeCode != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Semantics(
                    liveRegion: true,
                    child: DecoratedBox(
                      key: const ValueKey<String>('coach-voice-notice'),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.errorContainer.withValues(alpha: 0.45),
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
                                  voiceState.noticeCode!,
                                ),
                              ),
                            ),
                            IconButton(
                              key: const ValueKey<String>(
                                'coach-dismiss-voice-notice',
                              ),
                              tooltip: l10n.voiceDismissNotice,
                              onPressed: voiceState.dismissNotice,
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey<String>('coach-message-input'),
                        controller: _controller,
                        focusNode: _inputFocusNode,
                        enabled: !isCoachBusy && !voiceBlocksSubmission,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 800,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.send,
                        onSubmitted: canSend ? (_) => _send() : null,
                        decoration: InputDecoration(
                          hintText: l10n.coachInputHint,
                          counterText: '',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.outlined(
                      key: const ValueKey<String>('coach-voice-input'),
                      tooltip: voiceState.isListening
                          ? l10n.coachVoiceStopTooltip
                          : l10n.coachVoiceDictateTooltip,
                      onPressed: isCoachBusy || voiceState.isBusy
                          ? null
                          : voiceState.isListening
                          ? _stopVoiceTranscription
                          : _startVoiceTranscription,
                      icon: voiceState.isBusy
                          ? const SizedBox.square(
                              dimension: 19,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              voiceState.isListening ? Icons.stop : Icons.mic,
                            ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      key: const ValueKey<String>('coach-send-message'),
                      tooltip: l10n.coachSendTooltip,
                      onPressed: canSend ? _send : null,
                      icon: isCoachBusy
                          ? const SizedBox.square(
                              dimension: 19,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_upward),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Text(
                  l10n.coachCareBoundary,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationBody extends StatelessWidget {
  const _ConversationBody({
    required this.messages,
    required this.isResponding,
    required this.starterPrompts,
    required this.primaryColor,
    required this.scrollController,
    required this.quickReplies,
    required this.promptsEnabled,
    required this.onPromptSelected,
  });

  final List<CoachingMessage> messages;
  final bool isResponding;
  final List<String> starterPrompts;
  final Color primaryColor;
  final ScrollController scrollController;
  final List<String> quickReplies;
  final bool promptsEnabled;
  final ValueChanged<String> onPromptSelected;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty && !isResponding) {
      return ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
        children: [
          Icon(Icons.chat_bubble_outline, color: primaryColor, size: 34),
          const SizedBox(height: 12),
          Text(
            context.l10n.coachEmptyHeadline,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.coachEmptyDescription,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 18),
          ...starterPrompts.map(
            (prompt) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ActionChip(
                key: ValueKey<String>('coach-prompt-$prompt'),
                avatar: const Icon(Icons.arrow_forward, size: 17),
                label: SizedBox(width: double.infinity, child: Text(prompt)),
                onPressed: promptsEnabled
                    ? () => onPromptSelected(prompt)
                    : null,
              ),
            ),
          ),
        ],
      );
    }

    final hasQuickReplies = !isResponding && quickReplies.isNotEmpty;
    final hasTrailingItem = isResponding || hasQuickReplies;
    final itemCount = messages.length + (hasTrailingItem ? 1 : 0);
    return ListView.separated(
      key: const ValueKey<String>('coach-conversation-list'),
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == messages.length) {
          if (isResponding) {
            return _ThinkingBubble(primaryColor: primaryColor);
          }
          return _QuickReplyBar(
            replies: quickReplies,
            enabled: promptsEnabled,
            onSelected: onPromptSelected,
          );
        }
        return _MessageBubble(
          message: messages[index],
          primaryColor: primaryColor,
        );
      },
    );
  }
}

class _QuickReplyBar extends StatelessWidget {
  const _QuickReplyBar({
    required this.replies,
    required this.enabled,
    required this.onSelected,
  });

  final List<String> replies;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: context.l10n.coachSuggestedRepliesSemantics,
      child: SingleChildScrollView(
        key: const ValueKey<String>('coach-quick-replies'),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final reply in replies)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  key: ValueKey<String>('coach-quick-reply-$reply'),
                  label: Text(reply),
                  onPressed: enabled ? () => onSelected(reply) : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.primaryColor});

  final CoachingMessage message;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == CoachingMessageRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isUser
                ? primaryColor.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUser
                      ? context.l10n.coachUserLabel
                      : context.l10n.coachTitle,
                  style: TextStyle(
                    color: isUser ? primaryColor : Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(message.text),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble({required this.primaryColor});

  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.coachThinkingSemantics,
      child: Align(
        alignment: Alignment.centerLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomRight: Radius.circular(18),
              bottomLeft: Radius.circular(4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 15,
                  child: CircularProgressIndicator(
                    color: primaryColor,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  context.l10n.coachThinking,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
