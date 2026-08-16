import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/coaching_message.dart';
import '../providers/app_providers.dart';
import '../services/coaching_service.dart';
import 'confirmation_dialog.dart';

typedef CoachingContextBuilder = CoachingContext Function();

class CoachingSheet extends ConsumerStatefulWidget {
  const CoachingSheet({required this.contextBuilder, super.key});

  final CoachingContextBuilder contextBuilder;

  @override
  ConsumerState<CoachingSheet> createState() => _CoachingSheetState();
}

class _CoachingSheetState extends ConsumerState<CoachingSheet> {
  static const _starterPrompts = <String>[
    'I’m stuck—help me start',
    'I’m feeling overwhelmed',
    'What should I do next?',
    'Help me think this through',
    'Be gentle with me',
    'Please just listen',
    'Hold me accountable',
  ];

  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isSubmitting = false;
  bool _isManagingHistory = false;
  int _lastConversationRevision = -1;

  static List<String> _quickRepliesFor(List<CoachingMessage> messages) {
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
      return const [
        'Please just listen',
        'Be gentle with me',
        'Hold me accountable',
      ];
    }

    if (LocalCoachingResponder.isReflectiveConversation(messages)) {
      return const [];
    }

    final coachReply = messages.last.text.toLowerCase();
    if (coachReply.contains('take a real five-minute break') ||
        coachReply.contains('let recovery count')) {
      return const ['I’m back after a break'];
    }
    if (coachReply.contains('listen without trying to fix')) {
      return const [
        'What should I do next?',
        'Be gentle with me',
        'Hold me accountable',
      ];
    }
    if (coachReply.startsWith('direct version') ||
        coachReply.startsWith('you asked me to stay direct')) {
      return const [
        'I did the first step',
        'I’m still stuck',
        'I need a break',
        'Be gentle with me',
      ];
    }
    if (coachReply.contains('i’ll keep this gentle') ||
        coachReply.startsWith(
          'i remember that you wanted a gentler approach',
        ) ||
        coachReply.startsWith('we can approach this gently')) {
      return const ['Break it down', 'Please just listen', 'I need a break'];
    }
    if (coachReply.startsWith('welcome back')) {
      return const ['I did the first step', 'I’m still stuck'];
    }
    if (coachReply.startsWith('that counts') ||
        coachReply.startsWith('that is real progress')) {
      return const ['What should I do next?', 'I need a break'];
    }
    return const ['Break it down', 'I’m still stuck', 'Please just listen'];
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refreshDraftState);
  }

  void _refreshDraftState() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refreshDraftState)
      ..dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _send([String? suggestedMessage]) async {
    if (_isSubmitting || _isManagingHistory) return;
    final message = (suggestedMessage ?? _controller.text).trim();
    if (message.isEmpty) return;

    setState(() => _isSubmitting = true);
    if (suggestedMessage == null) _controller.clear();
    try {
      await ref
          .read(coachingServiceProvider)
          .send(message, widget.contextBuilder());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Your coach could not respond. Please try again.'),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _clearConversation() async {
    if (_isManagingHistory || _isSubmitting) return;
    setState(() => _isManagingHistory = true);
    try {
      final confirmed = await ConfirmationDialog.show(
        context,
        title: 'Clear coaching conversation?',
        message:
            'This permanently removes the coaching conversation saved on this device.',
        cancelLabel: 'Keep conversation',
        confirmLabel: 'Clear conversation',
        isDestructive: true,
      );
      if (!confirmed || !mounted) return;
      await ref.read(coachingServiceProvider).clearConversation();
    } finally {
      if (mounted) setState(() => _isManagingHistory = false);
    }
  }

  Future<void> _setEnhancedCoachingEnabled(bool enabled) async {
    if (_isManagingHistory || _isSubmitting) return;
    setState(() => _isManagingHistory = true);
    try {
      if (enabled) {
        final confirmed = await ConfirmationDialog.show(
          context,
          title: 'Use enhanced AI coaching?',
          message:
              'When enabled, your message, up to 12 recent coaching messages, and relevant FocusHaven context are sent securely through Firebase to OpenAI to generate a response. OpenAI does not use API data for training unless the API account opts in, but may retain content for abuse monitoring for up to 30 days by default. Your conversation remains saved on this device. You can turn this off anytime.',
          cancelLabel: 'Keep coaching local',
          confirmLabel: 'Enable AI coaching',
        );
        if (!confirmed || !mounted) return;
      }
      await ref
          .read(coachingServiceProvider)
          .setEnhancedCoachingEnabled(enabled);
    } finally {
      if (mounted) setState(() => _isManagingHistory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coachingState = ref.watch(coachingStateProvider);
    if (coachingState.conversationRevision != _lastConversationRevision) {
      _lastConversationRevision = coachingState.conversationRevision;
      if (coachingState.messages.isNotEmpty || coachingState.isResponding) {
        _scheduleScrollToLatest();
      }
    }

    final isBusy =
        coachingState.isResponding || _isSubmitting || _isManagingHistory;
    final canSend = !isBusy && _controller.text.trim().isNotEmpty;
    final quickReplies = !isBusy && coachingState.errorMessage == null
        ? _quickRepliesFor(coachingState.messages)
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
                            'Focus Coach',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            coachingState.enhancedCoachingEnabled
                                ? 'Enhanced AI · conversation saved on this device'
                                : 'Private guidance saved on this device',
                            style: const TextStyle(color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const ValueKey<String>('coach-clear-history'),
                      tooltip: 'Clear coaching conversation',
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
                      tooltip: 'Close Focus Coach',
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
                  title: const Text('Enhanced AI coaching'),
                  subtitle: Text(
                    coachingState.enhancedCoachingEnabled
                        ? 'Messages use secure cloud AI with an automatic local fallback.'
                        : 'Off · coaching stays on this device.',
                  ),
                ),
                const Divider(height: 1),
              ],
              Expanded(
                child: _ConversationBody(
                  messages: coachingState.messages,
                  isResponding: coachingState.isResponding,
                  starterPrompts: _starterPrompts,
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
                        enabled: !isBusy,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 800,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.send,
                        onSubmitted: canSend ? (_) => _send() : null,
                        decoration: const InputDecoration(
                          hintText: 'What’s on your mind?',
                          counterText: '',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      key: const ValueKey<String>('coach-send-message'),
                      tooltip: 'Send message',
                      onPressed: canSend ? _send : null,
                      icon: isBusy
                          ? const SizedBox.square(
                              dimension: 19,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_upward),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Text(
                  'Focus Coach supports wellbeing and productivity, but it is not professional or crisis care.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 11),
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
            'You don’t have to figure out the next step alone.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose what you need right now: listening without fixing, a gentle next step, or direct accountability.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, height: 1.4),
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
      label: 'Suggested follow-up replies',
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
                  isUser ? 'You' : 'Focus Coach',
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
      label: 'Focus Coach is thinking',
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
                const Text(
                  'Thinking…',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
