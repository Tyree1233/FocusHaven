import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/coaching_message.dart';

class CoachingContext {
  const CoachingContext({
    this.focusTask = '',
    this.focusProfile,
    this.todayFocusMinutes = 0,
    this.dailyGoalMinutes = 60,
    this.queueRemaining = 0,
    this.nextQueueTask,
    this.recentMood,
    this.parkedThoughtCount = 0,
    this.isTimerRunning = false,
  });

  final String focusTask;
  final String? focusProfile;
  final int todayFocusMinutes;
  final int dailyGoalMinutes;
  final int queueRemaining;
  final String? nextQueueTask;
  final String? recentMood;
  final int parkedThoughtCount;
  final bool isTimerRunning;

  Map<String, dynamic> toPromptData() => {
    if (focusTask.trim().isNotEmpty) 'focusTask': focusTask.trim(),
    if (focusProfile?.trim().isNotEmpty ?? false)
      'focusProfile': focusProfile!.trim(),
    'todayFocusMinutes': todayFocusMinutes,
    'dailyGoalMinutes': dailyGoalMinutes,
    'queueRemaining': queueRemaining,
    if (nextQueueTask?.trim().isNotEmpty ?? false)
      'nextQueueTask': nextQueueTask!.trim(),
    if (recentMood?.trim().isNotEmpty ?? false)
      'recentMood': recentMood!.trim(),
    'parkedThoughtCount': parkedThoughtCount,
    'isTimerRunning': isTimerRunning,
  };
}

abstract interface class CoachingResponder {
  Future<String> respond({
    required String message,
    required CoachingContext context,
    required List<CoachingMessage> conversation,
  });
}

class ResilientCoachingResponder implements CoachingResponder {
  const ResilientCoachingResponder({
    required this.primary,
    required this.fallback,
  });

  final CoachingResponder primary;
  final CoachingResponder fallback;

  @override
  Future<String> respond({
    required String message,
    required CoachingContext context,
    required List<CoachingMessage> conversation,
  }) async {
    try {
      final response = await primary.respond(
        message: message,
        context: context,
        conversation: conversation,
      );
      if (response.trim().isNotEmpty) return response;
    } catch (_) {
      // The private local coach remains available when a remote provider fails.
    }
    return fallback.respond(
      message: message,
      context: context,
      conversation: conversation,
    );
  }
}

class LocalCoachingResponder implements CoachingResponder {
  const LocalCoachingResponder();

  static const _safetySignals = <String>[
    'kill myself',
    'hurt myself',
    'end my life',
    'self harm',
    'self-harm',
    'suicide',
    'want to die',
    'wish i was dead',
    'wish i were dead',
    'better off dead',
    'no reason to live',
    'take my life',
    'taking my life',
    "don't want to live",
    'do not want to live',
  ];

  static bool isSafetyConcern(String message) =>
      _containsAny(message.toLowerCase(), _safetySignals);

  @override
  Future<String> respond({
    required String message,
    required CoachingContext context,
    required List<CoachingMessage> conversation,
  }) async {
    final normalized = message.toLowerCase();
    if (isSafetyConcern(normalized)) {
      return "I'm really glad you told me. Your safety matters more than "
          'productivity. If you might act on this or you are in immediate '
          'danger, contact local emergency services now and reach out to '
          'someone you trust who can stay with you. You deserve real human '
          'support; a focus coach is not a substitute for crisis care.';
    }
    if (_containsAny(normalized, const [
      'still stuck',
      'that did not work',
      "that didn't work",
      'i tried',
      'messed up',
      'fell behind',
      'failed again',
    ])) {
      return _setbackReply(context);
    }
    if (_containsAny(normalized, const [
      'i am lazy',
      "i'm lazy",
      'i am useless',
      "i'm useless",
      'hate myself',
      'what is wrong with me',
    ])) {
      return _selfCriticismReply(context);
    }
    if (_containsAny(normalized, const [
      'perfect',
      'perfection',
      'not good enough',
      'afraid it will be bad',
      "afraid it'll be bad",
      'fear of failing',
    ])) {
      return _perfectionismReply(context);
    }
    if (_containsAny(normalized, const [
      "can't decide",
      'cannot decide',
      'too many options',
      'which one',
      'choose between',
    ])) {
      return _decisionReply(context);
    }
    if (_containsAny(normalized, const [
      'running out of time',
      'behind schedule',
      'not enough time',
      'deadline',
      'only have',
    ])) {
      return _timePressureReply(context);
    }
    if (_containsAny(normalized, const [
      'overwhelmed',
      'anxious',
      'stressed',
      'too much',
      "can't handle",
      'cannot handle',
    ])) {
      return _overwhelmReply(context);
    }
    if (_containsAny(normalized, const [
      'stuck',
      'procrastinat',
      "can't start",
      'cannot start',
      'avoiding',
      'unmotivated',
    ])) {
      return _startingReply(context);
    }
    if (_containsAny(normalized, const [
      'distracted',
      "can't focus",
      'cannot focus',
      'mind keeps',
      'wandering',
    ])) {
      return _distractionReply(context);
    }
    if (_containsAny(normalized, const [
      'tired',
      'exhausted',
      'burned out',
      'burnt out',
      'no energy',
    ])) {
      return _energyReply(context);
    }
    if (_containsAny(normalized, const [
      'what should i do',
      'what next',
      'help me plan',
      'prioritize',
      'where do i start',
    ])) {
      return _planningReply(context);
    }
    if (_containsAny(normalized, const [
      'i did it',
      "i'm done",
      'i am done',
      'finished',
      'proud',
      'small win',
    ])) {
      return _celebrationReply(context);
    }
    if (_containsAny(normalized, const [
      'break it down',
      'smaller steps',
      'what are the steps',
      'yes please',
      'please do',
    ])) {
      return _followUpReply(context, conversation);
    }
    return _generalReply(context, conversation);
  }

  static bool _containsAny(String source, List<String> signals) =>
      signals.any(source.contains);

  static String _currentTask(CoachingContext context) {
    final focusTask = context.focusTask.trim();
    if (focusTask.isNotEmpty) return focusTask;
    final nextQueueTask = context.nextQueueTask?.trim() ?? '';
    if (nextQueueTask.isNotEmpty) return nextQueueTask;
    return 'the task in front of you';
  }

  static String _overwhelmReply(CoachingContext context) {
    final task = _currentTask(context);
    return 'That sounds like a lot to hold at once. Let’s make the next move '
        'smaller: open “$task” and spend two minutes identifying the first '
        'visible action. You do not need to finish it—just make it easier to '
        'begin. Want to break it into three tiny steps together?';
  }

  static String _startingReply(CoachingContext context) {
    final task = _currentTask(context);
    return 'Let’s lower the stakes. For the next five minutes, your only job '
        'is to begin “$task.” You may stop after five minutes if you want; '
        'starting is the win. What is the smallest physical action—open the '
        'file, write one line, or gather one item?';
  }

  static String _setbackReply(CoachingContext context) {
    final task = _currentTask(context);
    return 'That’s frustrating, especially because you already made an effort. '
        'This is information, not proof that you failed. For “$task,” choose '
        'one reset: make the next step half as small, take a real five-minute '
        'break, or switch approaches. Which reset feels most honest right now?';
  }

  static String _selfCriticismReply(CoachingContext context) {
    return 'I hear how hard you’re being on yourself. Struggling with '
        '“${_currentTask(context)}” is a moment you’re having—not your '
        'identity. Let’s replace the verdict with one useful fact: what exactly '
        'is making the next step difficult—clarity, energy, or fear?';
  }

  static String _perfectionismReply(CoachingContext context) {
    return 'It sounds like the standard has become so high that starting feels '
        'unsafe. Give yourself permission to make a rough version of '
        '“${_currentTask(context)}” for ten minutes—something useful, not '
        'impressive. What would “good enough for this session” look like?';
  }

  static String _decisionReply(CoachingContext context) {
    final queueNote = context.queueRemaining > 1
        ? 'You have ${context.queueRemaining} items waiting, but only one needs '
              'your attention now.'
        : 'You only need to choose the next move, not the whole path.';
    return 'Too many reasonable options can freeze a decision. $queueNote '
        'Choose “${_currentTask(context)}” for one short trial round. A '
        'reversible choice does not need perfect certainty.';
  }

  static String _timePressureReply(CoachingContext context) {
    return 'That time pressure is real, and panic can make the remaining time '
        'harder to use. For “${_currentTask(context)},” name the smallest '
        'acceptable outcome, remove one nonessential piece, and work only on '
        'the next ten-minute block. What can safely be left out?';
  }

  static String _followUpReply(
    CoachingContext context,
    List<CoachingMessage> conversation,
  ) {
    final task = _currentTask(context);
    final continuity = conversation.any(
      (entry) => entry.role == CoachingMessageRole.coach,
    );
    final opening = continuity
        ? 'Absolutely—let’s make the step we were discussing concrete.'
        : 'Absolutely—let’s make this concrete.';
    return '$opening For “$task”: first, open or gather what you need; second, '
        'make one deliberately rough pass for five minutes; third, stop and '
        'name the next visible action. Do only the first step right now.';
  }

  static String _distractionReply(CoachingContext context) {
    final savedThoughts = context.parkedThoughtCount;
    final parkingNote = savedThoughts == 0
        ? 'If the thought can wait, park it in FocusHaven so your brain does '
              'not have to keep rehearsing it.'
        : 'You already have $savedThoughts parked '
              '${savedThoughts == 1 ? 'thought' : 'thoughts'}; let those stay '
              'safe while you return.';
    return 'No judgment—attention wanders. $parkingNote Then take one slow '
        'breath, look only at “${_currentTask(context)},” and choose the next '
        'action that takes under two minutes.';
  }

  static String _energyReply(CoachingContext context) {
    if (context.todayFocusMinutes >= context.dailyGoalMinutes) {
      return 'You have already met today’s focus goal. Rest is not falling '
          'behind; it is part of protecting tomorrow’s attention. Consider '
          'ending on purpose, drinking some water, and choosing one gentle '
          'thing that helps you recover.';
    }
    return 'Low energy deserves a smaller plan, not harsher self-talk. Try a '
        'short break first. When you return, give “${_currentTask(context)}” '
        'one ten-minute round and reassess honestly after that.';
  }

  static String _planningReply(CoachingContext context) {
    final task = _currentTask(context);
    final queueNote = context.queueRemaining > 1
        ? 'Ignore the other ${context.queueRemaining - 1} queued items for now.'
        : 'Keep the rest out of view for now.';
    return 'Start with “$task.” $queueNote Define what “done for this session” '
        'means in one sentence, then choose a first action you can complete '
        'without making another decision.';
  }

  static String _celebrationReply(CoachingContext context) {
    final progress = context.todayFocusMinutes > 0
        ? ' You have protected ${context.todayFocusMinutes} minutes of focus '
              'today.'
        : '';
    return 'That counts. Take a second to let the win register instead of '
        'rushing past it.$progress What helped this time that you want to '
        'repeat in your next session?';
  }

  static String _generalReply(
    CoachingContext context,
    List<CoachingMessage> conversation,
  ) {
    final task = _currentTask(context);
    final mood = context.recentMood?.trim();
    final profile = context.focusProfile?.trim();
    final personalNote = mood?.isNotEmpty == true
        ? 'Your recent reflections have often felt $mood, so let’s work with '
              'that rather than against it.'
        : profile?.isNotEmpty == true
        ? 'We can shape this for your $profile focus style.'
        : 'We can keep this gentle and practical.';
    final continuity = conversation.length > 2
        ? ' I’m still with the thread we’ve been working through.'
        : '';
    return '$personalNote$continuity For “$task,” what feels hardest right '
        'now: knowing what to do, getting started, or staying with it?';
  }
}

class CoachingService extends ChangeNotifier {
  factory CoachingService({
    CoachingResponder? responder,
    CoachingResponder? enhancedResponder,
  }) => CoachingService._(
    responder: responder,
    enhancedResponder: enhancedResponder,
  );

  CoachingService._({CoachingResponder? responder, this._enhancedResponder})
    : _localResponder = responder ?? const LocalCoachingResponder() {
    initialized = _load();
  }

  static const _storageKey = 'coachingConversation';
  static const _enhancedCoachingKey = 'enhancedCoachingEnabled';
  static const _maximumMessages = 40;
  static const _maximumMessageLength = 800;

  final CoachingResponder _localResponder;
  final CoachingResponder? _enhancedResponder;
  List<CoachingMessage> _messages = [];
  int _conversationRevision = 0;
  bool _isResponding = false;
  bool _enhancedCoachingEnabled = false;
  bool _isDisposed = false;
  String? _errorMessage;

  late final Future<void> initialized;

  List<CoachingMessage> get messages => List.unmodifiable(_messages);
  int get conversationRevision => _conversationRevision;
  bool get isResponding => _isResponding;
  bool get enhancedCoachingAvailable => _enhancedResponder != null;
  bool get enhancedCoachingEnabled => _enhancedCoachingEnabled;
  String? get errorMessage => _errorMessage;

  Future<bool> send(String message, CoachingContext context) async {
    final cleanedMessage = _cleanText(message);
    if (cleanedMessage == null) return false;
    await initialized;
    if (_isDisposed || _isResponding) return false;

    _isResponding = true;
    _errorMessage = null;
    final userMessage = CoachingMessage(
      id: _nextMessageId(),
      role: CoachingMessageRole.user,
      text: cleanedMessage,
      createdAt: DateTime.now(),
    );
    _messages = _bounded([..._messages, userMessage]);
    _notifyConversationChanged();

    try {
      await _save(_messages);
      final responder = LocalCoachingResponder.isSafetyConcern(cleanedMessage)
          ? _localResponder
          : _enhancedCoachingEnabled && _enhancedResponder != null
          ? _enhancedResponder
          : _localResponder;
      final response = await responder.respond(
        message: cleanedMessage,
        context: context,
        conversation: List.unmodifiable(_messages),
      );
      final cleanedResponse = _cleanText(response);
      if (cleanedResponse == null) {
        throw StateError('The coach returned an empty response.');
      }
      final coachMessage = CoachingMessage(
        id: _nextMessageId(),
        role: CoachingMessageRole.coach,
        text: cleanedResponse,
        createdAt: DateTime.now(),
      );
      final updatedMessages = _bounded([..._messages, coachMessage]);
      await _save(updatedMessages);
      if (_isDisposed) return false;

      _messages = updatedMessages;
      _isResponding = false;
      _notifyConversationChanged();
      return true;
    } catch (error) {
      if (_isDisposed) return false;
      _isResponding = false;
      _errorMessage = 'Your coach could not respond right now. Please retry.';
      debugPrint('Focus coach response failed: $error');
      _notifyConversationChanged();
      return false;
    }
  }

  Future<bool> setEnhancedCoachingEnabled(bool enabled) async {
    await initialized;
    if (_isDisposed || _isResponding || _enhancedResponder == null) {
      return false;
    }
    if (_enhancedCoachingEnabled == enabled) return false;

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enhancedCoachingKey, enabled);
    if (_isDisposed) return false;

    _enhancedCoachingEnabled = enabled;
    notifyListeners();
    return true;
  }

  Future<void> clearConversation() =>
      _clearLocalData(includeEnhancedPreference: false);

  Future<void> clearLocalData() =>
      _clearLocalData(includeEnhancedPreference: true);

  Future<void> _clearLocalData({
    required bool includeEnhancedPreference,
  }) async {
    await initialized;
    if (_isDisposed || _isResponding) return;

    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
    if (includeEnhancedPreference) {
      await preferences.remove(_enhancedCoachingKey);
    }
    if (_isDisposed) return;

    final conversationChanged = _messages.isNotEmpty || _errorMessage != null;
    final settingChanged =
        includeEnhancedPreference && _enhancedCoachingEnabled;
    if (!conversationChanged && !settingChanged) return;
    _messages = [];
    _errorMessage = null;
    if (includeEnhancedPreference) _enhancedCoachingEnabled = false;
    if (conversationChanged) {
      _notifyConversationChanged();
    } else {
      notifyListeners();
    }
  }

  Future<void> _load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (_isDisposed) return;
      final savedEnhancedPreference = preferences.get(_enhancedCoachingKey);
      if (savedEnhancedPreference is bool) {
        _enhancedCoachingEnabled =
            _enhancedResponder != null && savedEnhancedPreference;
        if (_enhancedCoachingEnabled) notifyListeners();
      } else if (savedEnhancedPreference != null) {
        await preferences.remove(_enhancedCoachingKey);
      }
      final savedValue = preferences.get(_storageKey);
      if (savedValue == null) return;
      if (savedValue is! String) {
        await preferences.remove(_storageKey);
        return;
      }

      final decoded = jsonDecode(savedValue);
      if (decoded is! List) {
        await preferences.remove(_storageKey);
        return;
      }
      final loadedMessages = <CoachingMessage>[];
      final loadedIds = <String>{};
      for (final value in decoded.whereType<Map>()) {
        try {
          final message = CoachingMessage.fromJson(
            Map<String, dynamic>.from(value),
          );
          final cleanedText = _cleanText(message.text);
          if (cleanedText == null || !loadedIds.add(message.id)) continue;
          loadedMessages.add(
            CoachingMessage(
              id: message.id,
              role: message.role,
              text: cleanedText,
              createdAt: message.createdAt,
            ),
          );
        } on FormatException {
          // Ignore one damaged message without losing the full conversation.
        } on TypeError {
          // Ignore unexpected persisted shapes.
        }
      }
      if (_isDisposed) return;

      _messages = _bounded(loadedMessages);
      final normalizedStorage = jsonEncode(
        _messages.map((message) => message.toJson()).toList(),
      );
      if (_messages.isEmpty) {
        await preferences.remove(_storageKey);
      } else if (normalizedStorage != savedValue) {
        await preferences.setString(_storageKey, normalizedStorage);
      }
      if (_isDisposed || _messages.isEmpty) return;
      _notifyConversationChanged();
    } on FormatException {
      await _removeCorruptedStorage();
    } on TypeError {
      await _removeCorruptedStorage();
    } catch (error) {
      debugPrint('Focus coach conversation could not be loaded: $error');
    }
  }

  Future<void> _save(List<CoachingMessage> messages) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(messages.map((message) => message.toJson()).toList()),
    );
  }

  Future<void> _removeCorruptedStorage() async {
    if (_isDisposed) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_storageKey);
    } catch (error) {
      debugPrint('Corrupted coach storage could not be removed: $error');
    }
  }

  void _notifyConversationChanged() {
    if (_isDisposed) return;
    _conversationRevision++;
    notifyListeners();
  }

  String _nextMessageId() {
    var candidate = DateTime.now().microsecondsSinceEpoch;
    while (_messages.any((message) => message.id == candidate.toString())) {
      candidate++;
    }
    return candidate.toString();
  }

  static List<CoachingMessage> _bounded(List<CoachingMessage> messages) {
    if (messages.length <= _maximumMessages) return messages;
    return messages.sublist(messages.length - _maximumMessages);
  }

  static String? _cleanText(String text) {
    final cleaned = text.trim().replaceAll(RegExp(r'[ \t]+'), ' ');
    if (cleaned.isEmpty) return null;
    return cleaned.length > _maximumMessageLength
        ? cleaned.substring(0, _maximumMessageLength)
        : cleaned;
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
