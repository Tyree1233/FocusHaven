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

/// Persists one bounded private coaching conversation as a verified commit.
typedef CoachingConversationSave =
    Future<bool> Function(
      SharedPreferences preferences,
      List<CoachingMessage> messages,
    );

/// Persists the user's enhanced-coaching consent as a verified commit.
typedef CoachingEnhancedPreferenceSave =
    Future<bool> Function(SharedPreferences preferences, bool enabled);

/// Removes one private coaching value and verifies that it is gone.
typedef CoachingPreferenceRemove =
    Future<bool> Function(SharedPreferences preferences, String key);

enum CoachingFallbackReason {
  allowanceReached,
  accessUnavailable,
  serviceUnavailable,
}

extension CoachingFallbackReasonMessage on CoachingFallbackReason {
  String get userMessage => switch (this) {
    CoachingFallbackReason.allowanceReached =>
      'Your enhanced AI allowance has been reached for this month. '
          'Your private local coach answered instead.',
    CoachingFallbackReason.accessUnavailable =>
      'Enhanced AI is not available for this account right now. '
          'Your private local coach answered instead.',
    CoachingFallbackReason.serviceUnavailable =>
      'Enhanced AI is temporarily unavailable. '
          'Your private local coach answered instead.',
  };
}

final class CoachingFallbackException implements Exception {
  const CoachingFallbackException(this.reason);

  final CoachingFallbackReason reason;
}

abstract interface class CoachingFallbackNoticeSource {
  CoachingFallbackReason? takeFallbackReason();
}

enum _CoachingSupportMode { gentle, listening, direct, reflective }

class ResilientCoachingResponder
    implements CoachingResponder, CoachingFallbackNoticeSource {
  ResilientCoachingResponder({required this.primary, required this.fallback});

  final CoachingResponder primary;
  final CoachingResponder fallback;
  CoachingFallbackReason? _fallbackReason;

  @override
  CoachingFallbackReason? takeFallbackReason() {
    final reason = _fallbackReason;
    _fallbackReason = null;
    return reason;
  }

  @override
  Future<String> respond({
    required String message,
    required CoachingContext context,
    required List<CoachingMessage> conversation,
  }) async {
    _fallbackReason = null;
    try {
      final response = await primary.respond(
        message: message,
        context: context,
        conversation: conversation,
      );
      if (response.trim().isNotEmpty) return response;
      _fallbackReason = CoachingFallbackReason.serviceUnavailable;
    } on CoachingFallbackException catch (error) {
      _fallbackReason = error.reason;
    } catch (_) {
      _fallbackReason = CoachingFallbackReason.serviceUnavailable;
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
  static const _boundarySignals = <String>[
    'stop coaching',
    'pause coaching',
    'not right now',
    'not now',
    'leave me alone',
    'give me space',
    'i need space',
    'need some space',
    "don't push me",
    'do not push me',
    'no more advice',
  ];
  static const _repairSignals = <String>[
    "that's not what i meant",
    'that’s not what i meant',
    'that is not what i meant',
    'you misunderstood',
    'you misunderstood me',
    'you got me wrong',
    "that's not what i need",
    'that’s not what i need',
    'that is not what i need',
    "that doesn't help",
    'that doesn’t help',
    'that does not help',
    'you are not listening',
    "you aren't listening",
    'you aren’t listening',
  ];
  static const _reflectionSignals = <String>[
    'help me think this through',
    'think this through with me',
    'can we think this through',
    'help me process this',
    'i need to process this',
    'talk this through with me',
    'help me sort this out',
    'i feel conflicted',
    'i feel torn',
  ];
  static const _listeningSignals = <String>[
    'need to vent',
    'can i vent',
    'just listen',
    'listen to me',
    "don't give me advice",
    'do not give me advice',
    'not looking for advice',
    'no advice',
  ];
  static const _directSignals = <String>[
    'hold me accountable',
    'need accountability',
    'be direct',
    'give it to me straight',
    'push me',
    'stop making excuses',
  ];
  static const _gentleSignals = <String>[
    'be gentle',
    'gentle with me',
    'go easy on me',
    'need encouragement',
    'need reassurance',
    'encourage me',
  ];

  static bool isSafetyConcern(String message) =>
      _containsAny(message.toLowerCase(), _safetySignals);
  static bool isBoundaryRequest(String message) =>
      _containsAny(message.toLowerCase(), _boundarySignals);
  static bool isRepairRequest(String message) =>
      _containsAny(message.toLowerCase(), _repairSignals);
  static bool isReflectionRequest(String message) =>
      _containsAny(message.toLowerCase(), _reflectionSignals);
  static bool isReflectiveConversation(List<CoachingMessage> conversation) =>
      _rememberedSupportMode(conversation) == _CoachingSupportMode.reflective;

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
    if (isBoundaryRequest(normalized)) {
      return _boundaryReply();
    }
    if (isRepairRequest(normalized)) {
      return _repairReply();
    }
    if (isReflectionRequest(normalized)) {
      return _reflectionReply(normalized);
    }
    final rememberedSupportMode = _rememberedSupportMode(conversation);
    if (_containsAny(normalized, _listeningSignals)) {
      return _listeningReply(conversation);
    }
    if (_containsAny(normalized, _directSignals)) {
      return _accountabilityReply(context);
    }
    if (_containsAny(normalized, _gentleSignals)) {
      return _gentleReply(context, conversation);
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
      return _setbackReply(context, conversation);
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
      return _startingReply(context, conversation);
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
      'need a break',
      'take a break',
      'pause for a bit',
      'pause for a while',
    ])) {
      return _breakReply(context);
    }
    if (_containsAny(normalized, const [
      "i'm back",
      'i’m back',
      'i am back',
      'back from my break',
      'back after a break',
      'ready to continue',
      'ready to get back',
      'took a break',
    ])) {
      return _returnReply(context, conversation);
    }
    if (_containsAny(normalized, const [
      'i started',
      "i've started",
      'i have started',
      'got started',
      'made a start',
      'made progress',
      'did the first step',
      'finished the first',
      'finished one',
      'completed the first',
      'completed one',
      'one part done',
    ])) {
      return _progressReply(context, conversation);
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
      return _celebrationReply(context, conversation);
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
    if (_containsAny(normalized, const [
      "i don't know",
      'i do not know',
      "i'm not sure",
      'i am not sure',
      'unsure',
    ])) {
      if (rememberedSupportMode == _CoachingSupportMode.reflective) {
        return _reflectiveUncertaintyReply();
      }
      return _uncertaintyReply(
        context,
        conversation,
        supportMode: rememberedSupportMode,
      );
    }
    if (rememberedSupportMode == _CoachingSupportMode.reflective) {
      return _reflectionFollowUpReply(conversation);
    }
    return _generalReply(
      context,
      conversation,
      supportMode: rememberedSupportMode,
    );
  }

  static bool _containsAny(String source, List<String> signals) =>
      signals.any(source.contains);

  static _CoachingSupportMode? _rememberedSupportMode(
    List<CoachingMessage> conversation,
  ) {
    for (final entry in conversation.reversed) {
      if (entry.role != CoachingMessageRole.user) continue;
      final message = entry.text.toLowerCase();
      if (isSafetyConcern(message)) continue;
      if (isReflectionRequest(message)) {
        return _CoachingSupportMode.reflective;
      }
      if (_containsAny(message, _listeningSignals)) {
        return _CoachingSupportMode.listening;
      }
      if (_containsAny(message, _directSignals)) {
        return _CoachingSupportMode.direct;
      }
      if (_containsAny(message, _gentleSignals)) {
        return _CoachingSupportMode.gentle;
      }
    }
    return null;
  }

  static String? _recentChallenge(List<CoachingMessage> conversation) {
    for (final entry in conversation.reversed) {
      if (entry.role != CoachingMessageRole.user) continue;
      final message = entry.text.toLowerCase();
      if (isSafetyConcern(message)) continue;
      if (_containsAny(message, const [
        'i am lazy',
        "i'm lazy",
        'i am useless',
        "i'm useless",
        'hate myself',
        'what is wrong with me',
      ])) {
        return 'self-criticism';
      }
      if (_containsAny(message, const [
        'perfect',
        'perfection',
        'not good enough',
        'afraid it will be bad',
        "afraid it'll be bad",
        'fear of failing',
      ])) {
        return 'perfectionism';
      }
      if (_containsAny(message, const [
        "can't decide",
        'cannot decide',
        'too many options',
        'which one',
        'choose between',
      ])) {
        return 'too many choices';
      }
      if (_containsAny(message, const [
        'running out of time',
        'behind schedule',
        'not enough time',
        'deadline',
        'only have',
      ])) {
        return 'deadline pressure';
      }
      if (_containsAny(message, const [
        'overwhelmed',
        'anxious',
        'stressed',
        'too much',
        "can't handle",
        'cannot handle',
      ])) {
        return 'overwhelm';
      }
      if (_containsAny(message, const [
        'stuck',
        'procrastinat',
        "can't start",
        'cannot start',
        'avoiding',
        'unmotivated',
      ])) {
        return 'getting started';
      }
      if (_containsAny(message, const [
        'distracted',
        "can't focus",
        'cannot focus',
        'mind keeps',
        'wandering',
      ])) {
        return 'distraction';
      }
      if (_containsAny(message, const [
        'tired',
        'exhausted',
        'burned out',
        'burnt out',
        'no energy',
      ])) {
        return 'low energy';
      }
    }
    return null;
  }

  static String _currentTask(CoachingContext context) {
    final focusTask = context.focusTask.trim();
    if (focusTask.isNotEmpty) return focusTask;
    final nextQueueTask = context.nextQueueTask?.trim() ?? '';
    if (nextQueueTask.isNotEmpty) return nextQueueTask;
    return 'the task in front of you';
  }

  static String _boundaryReply() {
    return 'Okay. I’ll stop here and give you space. No next step, no '
        'check-in, and nothing to prove. You can close Focus Coach now or '
        'come back whenever you choose.';
  }

  static String _repairReply() {
    return 'Thank you for correcting me. I misunderstood what you needed, '
        'and I’m sorry. Let’s reset without making you repeat everything. '
        'What would fit better right now: listening without advice, gentle '
        'support, or a direct next step?';
  }

  static String _reflectionReply(String message) {
    if (_containsAny(message, const [
      'conflicted',
      'torn',
      'part of me',
      'on one hand',
      'mixed feelings',
    ])) {
      return 'It sounds like two honest needs are pulling in different '
          'directions. Neither one has to be argued away yet. Which side '
          'feels harder to disappoint?';
    }
    return 'Let’s slow this down. You do not need to turn it into a decision '
        'or an action plan yet. What part of this feels most important to '
        'understand first?';
  }

  static String _reflectionFollowUpReply(List<CoachingMessage> conversation) {
    var latestUserMessage = '';
    for (final entry in conversation.reversed) {
      if (entry.role != CoachingMessageRole.user) continue;
      latestUserMessage = entry.text.toLowerCase();
      break;
    }
    if (_containsAny(latestUserMessage, const [
      'afraid',
      'fear',
      'scared',
      'worried',
    ])) {
      return 'That fear sounds like it is carrying a lot of weight, even if '
          'another part of you knows what it wants. What is the fear trying '
          'to protect you from?';
    }
    if (_containsAny(latestUserMessage, const [
      'guilty',
      'guilt',
      'disappoint',
      'let them down',
      'let everyone down',
    ])) {
      return 'You seem to be holding your own needs alongside concern for '
          'someone else. What would honoring yourself without dismissing '
          'them look like?';
    }
    return 'There is something important in that, and we do not have to '
        'force it into a plan. Which part feels most true now that you have '
        'said it out loud?';
  }

  static String _reflectiveUncertaintyReply() {
    return 'Not knowing can be part of understanding this, rather than a '
        'problem to solve immediately. What feels uncertain underneath the '
        'decision itself?';
  }

  static String _listeningReply(List<CoachingMessage> conversation) {
    final challenge = _recentChallenge(conversation);
    final recognition = challenge == null
        ? ''
        : ' It makes sense that $challenge has been wearing on you.';
    return 'Absolutely. You do not have to turn this into a plan or perform '
        'being okay for me.$recognition Say as much or as little as you need. '
        'I’ll stay with you and listen without trying to fix it.';
  }

  static String _gentleReply(
    CoachingContext context,
    List<CoachingMessage> conversation,
  ) {
    final challenge = _recentChallenge(conversation);
    final recognition = challenge == null
        ? ''
        : ' I remember that $challenge has been making this harder.';
    return 'Absolutely. I’ll keep this gentle.$recognition You do not have to '
        'prove anything or solve “${_currentTask(context)}” all at once. What '
        'would feel supportive right now: encouragement, a very small next '
        'step, or a moment to breathe?';
  }

  static String _accountabilityReply(CoachingContext context) {
    if (context.dailyGoalMinutes > 0 &&
        context.todayFocusMinutes >= context.dailyGoalMinutes) {
      return 'Direct answer: you have already met today’s focus goal. The '
          'accountable choice may be to stop intentionally instead of turning '
          'rest into something you must earn twice. Close the session and '
          'protect tomorrow’s attention.';
    }
    final task = _currentTask(context);
    final timerDirection = context.isTimerRunning
        ? 'Your timer is running, so return to it now.'
        : 'Start one ten-minute focus round now.';
    final queueDirection = context.queueRemaining > 1
        ? 'Ignore the other ${context.queueRemaining - 1} queued items.'
        : 'Keep everything else out of view.';
    return 'Direct version, without shame: commit to “$task” for ten minutes. '
        '$queueDirection $timerDirection Do not negotiate with the whole '
        'project—do the next visible action, then check back honestly.';
  }

  static String _uncertaintyReply(
    CoachingContext context,
    List<CoachingMessage> conversation, {
    _CoachingSupportMode? supportMode,
  }) {
    final task = _currentTask(context);
    final challenge = _recentChallenge(conversation);
    if (supportMode == _CoachingSupportMode.listening) {
      return 'You do not need to find the answer yet. I remember that you '
          'wanted listening without advice, so we can stay with the uncertainty. '
          'What feels most present when you say “I don’t know”?';
    }
    if (supportMode == _CoachingSupportMode.direct) {
      return 'You asked me to stay direct: do not solve the whole uncertainty. '
          'Choose one two-minute action on “$task,” do it now, and use what '
          'happens as the next piece of information.';
    }
    final gentleOpening = supportMode == _CoachingSupportMode.gentle
        ? 'We can approach this gently. '
        : '';
    if (challenge != null) {
      return '${gentleOpening}Not knowing is allowed. Since $challenge has been the obstacle, '
          'you do not need a perfect answer. Choose one: a real five-minute '
          'reset, or one two-minute action on “$task.” Which feels more '
          'possible right now?';
    }
    return '${gentleOpening}Not knowing is enough information to make the question smaller. '
        'For “$task,” which is closest: I need clarity, I need energy, or I’m '
        'afraid to begin? Pick the nearest answer—not the perfect one.';
  }

  static String _overwhelmReply(CoachingContext context) {
    final task = _currentTask(context);
    return 'That sounds like a lot to hold at once. Let’s make the next move '
        'smaller: open “$task” and spend two minutes identifying the first '
        'visible action. You do not need to finish it—just make it easier to '
        'begin. Want to break it into three tiny steps together?';
  }

  static String _startingReply(
    CoachingContext context,
    List<CoachingMessage> conversation,
  ) {
    final task = _currentTask(context);
    final alreadySuggestedStartingRound = conversation.any(
      (entry) =>
          entry.role == CoachingMessageRole.coach &&
          (entry.text.contains('next five minutes') ||
              entry.text.contains('starting is the win')),
    );
    if (alreadySuggestedStartingRound) {
      return 'You’re still here, so let’s change the experiment instead of '
          'repeating the same advice. For “$task,” spend sixty seconds only '
          'setting up—open it, put the needed item in front of you, and stop. '
          'Then choose: continue for two minutes, or tell me what blocked you.';
    }
    return 'Let’s lower the stakes. For the next five minutes, your only job '
        'is to begin “$task.” You may stop after five minutes if you want; '
        'starting is the win. What is the smallest physical action—open the '
        'file, write one line, or gather one item?';
  }

  static String _setbackReply(
    CoachingContext context,
    List<CoachingMessage> conversation,
  ) {
    final task = _currentTask(context);
    final challenge = _recentChallenge(conversation);
    final memory = challenge == null
        ? ''
        : 'We were already working with $challenge, so this calls for a '
              'different experiment. ';
    return 'That’s frustrating, especially because you already made an effort. '
        'This is information, not proof that you failed. $memory'
        'For “$task,” choose '
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
    final challenge = _recentChallenge(conversation);
    final opening = continuity
        ? 'Absolutely—let’s make the step we were discussing concrete.'
        : 'Absolutely—let’s make this concrete.';
    final memory = challenge == null
        ? ''
        : ' Since $challenge was the sticking point, we’ll keep each step '
              'deliberately small.';
    return '$opening$memory For “$task”: first, open or gather what you need; second, '
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

  static String _breakReply(CoachingContext context) {
    if (context.dailyGoalMinutes > 0 &&
        context.todayFocusMinutes >= context.dailyGoalMinutes) {
      return 'Yes—take the break. You have already met today’s focus goal, so '
          'you do not need to promise another round before you rest. End the '
          'session intentionally and let recovery count.';
    }
    final timerNote = context.isTimerRunning
        ? ' Pause the timer so the break feels real.'
        : '';
    return 'Yes—take a real five-minute break.$timerNote Leave “${_currentTask(context)}” '
        'open to the exact place you stopped, move your body, and get water if '
        'you need it. When you return, say “I’m back,” and we’ll choose only '
        'the next visible action.';
  }

  static String _returnReply(
    CoachingContext context,
    List<CoachingMessage> conversation,
  ) {
    final task = _currentTask(context);
    final challenge = _recentChallenge(conversation);
    final memory = challenge == null
        ? ''
        : ' Since $challenge was part of the earlier struggle, re-enter '
              'gently.';
    final timerNote = context.isTimerRunning
        ? ' Your timer is already running, so there is nothing else to set up.'
        : '';
    return 'Welcome back. You do not need to recreate all your motivation.'
        '$memory$timerNote Look at “$task,” recover the last visible action, '
        'and do only that for two minutes before deciding what comes next.';
  }

  static String _progressReply(
    CoachingContext context,
    List<CoachingMessage> conversation,
  ) {
    final task = _currentTask(context);
    final challenge = _recentChallenge(conversation);
    final memory = challenge == null
        ? ''
        : ' That matters even more after $challenge was getting in the way.';
    final pace = context.isTimerRunning
        ? 'Stay with the current session without speeding up.'
        : 'Take one breath and let the progress register before continuing.';
    return 'That is real progress—not a trivial prelude to the “real” work.'
        '$memory $pace For “$task,” name what you completed, then choose one '
        'next action no larger than the one you just did.';
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

  static String _celebrationReply(
    CoachingContext context,
    List<CoachingMessage> conversation,
  ) {
    final progress = context.todayFocusMinutes > 0
        ? ' You have protected ${context.todayFocusMinutes} minutes of focus '
              'today.'
        : '';
    final challenge = _recentChallenge(conversation);
    final memory = challenge == null
        ? ''
        : ' You reached this point while working through $challenge.';
    return 'That counts. Take a second to let the win register instead of '
        'rushing past it.$progress$memory What helped this time that you want to '
        'repeat in your next session?';
  }

  static String _generalReply(
    CoachingContext context,
    List<CoachingMessage> conversation, {
    _CoachingSupportMode? supportMode,
  }) {
    final task = _currentTask(context);
    if (supportMode == _CoachingSupportMode.listening) {
      return _listeningReply(conversation);
    }
    if (supportMode == _CoachingSupportMode.direct) {
      final timerDirection = context.isTimerRunning
          ? 'Return to the running timer now.'
          : 'Start one ten-minute focus round now.';
      return 'You asked me to stay direct: put everything except “$task” out '
          'of view. $timerDirection Do the next visible action, then report '
          'what actually happened.';
    }
    final gentleOpening = supportMode == _CoachingSupportMode.gentle
        ? 'I remember that you wanted a gentler approach. '
        : '';
    final mood = context.recentMood?.trim();
    final profile = context.focusProfile?.trim();
    final personalNote = mood?.isNotEmpty == true
        ? 'Your recent reflections have often felt $mood, so let’s work with '
              'that rather than against it.'
        : profile?.isNotEmpty == true
        ? 'We can shape this for your $profile focus style.'
        : 'We can keep this gentle and practical.';
    final challenge = _recentChallenge(conversation);
    if (challenge != null) {
      return '$gentleOpening$personalNote Earlier, you were dealing with $challenge. Is that '
          'still the main obstacle with “$task,” or has something changed?';
    }
    final continuity = conversation.length > 2
        ? ' I’m still with the thread we’ve been working through.'
        : '';
    return '$gentleOpening$personalNote$continuity For “$task,” what feels hardest right '
        'now: knowing what to do, getting started, or staying with it?';
  }
}

class CoachingService extends ChangeNotifier {
  factory CoachingService({
    CoachingResponder? responder,
    CoachingResponder? enhancedResponder,
    CoachingConversationSave? saveConversation,
    CoachingEnhancedPreferenceSave? saveEnhancedPreference,
    CoachingPreferenceRemove? removePreference,
  }) => CoachingService._(
    responder: responder,
    enhancedResponder: enhancedResponder,
    saveConversation: saveConversation,
    saveEnhancedPreference: saveEnhancedPreference,
    removePreference: removePreference,
  );

  CoachingService._({
    CoachingResponder? responder,
    this._enhancedResponder,
    CoachingConversationSave? saveConversation,
    CoachingEnhancedPreferenceSave? saveEnhancedPreference,
    CoachingPreferenceRemove? removePreference,
  }) : _localResponder = responder ?? const LocalCoachingResponder(),
       _saveConversation = saveConversation ?? _saveToPreferences,
       _saveEnhancedPreference =
           saveEnhancedPreference ?? _saveEnhancedPreferenceToPreferences,
       _removePreference =
           removePreference ?? _removePreferenceFromPreferences {
    initialized = _load();
  }

  static const _storageKey = 'coachingConversation';
  static const _enhancedCoachingKey = 'enhancedCoachingEnabled';
  static const _maximumMessages = 40;
  static const _maximumMessageLength = 800;

  final CoachingResponder _localResponder;
  final CoachingResponder? _enhancedResponder;
  final CoachingConversationSave _saveConversation;
  final CoachingEnhancedPreferenceSave _saveEnhancedPreference;
  final CoachingPreferenceRemove _removePreference;
  List<CoachingMessage> _messages = [];
  int _conversationRevision = 0;
  bool _isResponding = false;
  bool _enhancedCoachingEnabled = false;
  bool _isDisposed = false;
  String? _errorMessage;
  String? _noticeMessage;

  late final Future<void> initialized;

  List<CoachingMessage> get messages => List.unmodifiable(_messages);
  int get conversationRevision => _conversationRevision;
  bool get isResponding => _isResponding;
  bool get enhancedCoachingAvailable => _enhancedResponder != null;
  bool get enhancedCoachingEnabled => _enhancedCoachingEnabled;
  String? get errorMessage => _errorMessage;
  String? get noticeMessage => _noticeMessage;

  Future<bool> send(String message, CoachingContext context) async {
    final cleanedMessage = _cleanText(message);
    if (cleanedMessage == null) return false;
    await initialized;
    if (_isDisposed || _isResponding) return false;

    final previousMessages = _messages;
    var userMessageCommitted = false;
    _isResponding = true;
    _errorMessage = null;
    _noticeMessage = null;
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
      userMessageCommitted = true;
      final requiresLocalResponse =
          LocalCoachingResponder.isSafetyConcern(cleanedMessage) ||
          LocalCoachingResponder.isBoundaryRequest(cleanedMessage) ||
          LocalCoachingResponder.isRepairRequest(cleanedMessage) ||
          LocalCoachingResponder.isReflectiveConversation(_messages);
      final responder = requiresLocalResponse
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
      final fallbackReason = responder is CoachingFallbackNoticeSource
          ? (responder as CoachingFallbackNoticeSource).takeFallbackReason()
          : null;
      _noticeMessage = fallbackReason?.userMessage;
      _isResponding = false;
      _notifyConversationChanged();
      return true;
    } catch (error) {
      if (_isDisposed) return false;
      if (!userMessageCommitted) _messages = previousMessages;
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
    final saved = await _saveEnhancedPreference(preferences, enabled);
    if (_isDisposed) return false;
    if (!saved) {
      _errorMessage =
          'Your enhanced coaching preference could not be saved. Please retry.';
      _noticeMessage = null;
      notifyListeners();
      return false;
    }

    _enhancedCoachingEnabled = enabled;
    _errorMessage = null;
    _noticeMessage = null;
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
    final conversationCleared = await _removePrivateValue(
      preferences,
      _storageKey,
      'conversation',
    );
    final enhancedPreferenceCleared =
        !includeEnhancedPreference ||
        await _removePrivateValue(
          preferences,
          _enhancedCoachingKey,
          'enhanced coaching preference',
        );
    if (_isDisposed) return;

    final conversationChanged =
        conversationCleared &&
        (_messages.isNotEmpty ||
            _errorMessage != null ||
            _noticeMessage != null);
    final settingChanged =
        includeEnhancedPreference &&
        enhancedPreferenceCleared &&
        _enhancedCoachingEnabled;
    final clearCompleted = conversationCleared && enhancedPreferenceCleared;

    if (conversationCleared) {
      _messages = [];
      _noticeMessage = null;
    }
    if (includeEnhancedPreference && enhancedPreferenceCleared) {
      _enhancedCoachingEnabled = false;
    }
    _errorMessage = clearCompleted
        ? null
        : 'Your private coaching data could not be completely cleared. '
              'Please retry.';

    if (conversationChanged) {
      _notifyConversationChanged();
    } else if (settingChanged || !clearCompleted) {
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
        await _removeInvalidStoredValue(
          preferences,
          _enhancedCoachingKey,
          'enhanced coaching preference',
        );
      }
      final savedValue = preferences.get(_storageKey);
      if (savedValue == null) return;
      if (savedValue is! String) {
        await _removeInvalidStoredValue(
          preferences,
          _storageKey,
          'conversation',
        );
        return;
      }

      final decoded = jsonDecode(savedValue);
      if (decoded is! List) {
        await _removeInvalidStoredValue(
          preferences,
          _storageKey,
          'conversation',
        );
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
        await _removeInvalidStoredValue(
          preferences,
          _storageKey,
          'conversation',
        );
      } else if (normalizedStorage != savedValue) {
        final repaired = await _saveConversation(preferences, _messages);
        if (!repaired) {
          _reportStorageRepairFailure('conversation');
        }
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
    final saved = await _saveConversation(preferences, messages);
    if (!saved) {
      throw StateError('Focus coach conversation was not saved.');
    }
  }

  static Future<bool> _saveToPreferences(
    SharedPreferences preferences,
    List<CoachingMessage> messages,
  ) async {
    final encoded = jsonEncode(
      messages.map((message) => message.toJson()).toList(),
    );
    final saved = await preferences.setString(_storageKey, encoded);
    return saved && preferences.getString(_storageKey) == encoded;
  }

  static Future<bool> _saveEnhancedPreferenceToPreferences(
    SharedPreferences preferences,
    bool enabled,
  ) async {
    final saved = await preferences.setBool(_enhancedCoachingKey, enabled);
    return saved && preferences.getBool(_enhancedCoachingKey) == enabled;
  }

  static Future<bool> _removePreferenceFromPreferences(
    SharedPreferences preferences,
    String key,
  ) async {
    await preferences.remove(key);
    return !preferences.containsKey(key);
  }

  Future<void> _removeCorruptedStorage() async {
    if (_isDisposed) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      await _removeInvalidStoredValue(preferences, _storageKey, 'conversation');
    } catch (error) {
      debugPrint('Corrupted coach storage could not be removed: $error');
      _reportStorageRepairFailure('conversation');
    }
  }

  Future<void> _removeInvalidStoredValue(
    SharedPreferences preferences,
    String key,
    String description,
  ) async {
    final removed = await _removePrivateValue(preferences, key, description);
    if (!removed) _reportStorageRepairFailure(description);
  }

  Future<bool> _removePrivateValue(
    SharedPreferences preferences,
    String key,
    String description,
  ) async {
    try {
      return await _removePreference(preferences, key);
    } catch (error) {
      debugPrint('Private coach $description could not be removed: $error');
      return false;
    }
  }

  void _reportStorageRepairFailure(String description) {
    if (_isDisposed) return;
    _errorMessage =
        'Your private coaching data could not be completely repaired. '
        'Please clear it and retry.';
    debugPrint('Private coach $description repair was not committed.');
    notifyListeners();
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
