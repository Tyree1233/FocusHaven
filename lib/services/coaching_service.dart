import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../l10n/service_localizations.dart';
import '../models/coaching_message.dart';
import 'privacy_safe_diagnostics.dart';

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
    this.localizations,
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
  final AppLocalizations? localizations;

  CoachingContext withLocalizations(AppLocalizations value) => CoachingContext(
    focusTask: focusTask,
    focusProfile: focusProfile,
    todayFocusMinutes: todayFocusMinutes,
    dailyGoalMinutes: dailyGoalMinutes,
    queueRemaining: queueRemaining,
    nextQueueTask: nextQueueTask,
    recentMood: recentMood,
    parkedThoughtCount: parkedThoughtCount,
    isTimerRunning: isTimerRunning,
    localizations: value,
  );

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
  String userMessage(AppLocalizations localizations) => switch (this) {
    CoachingFallbackReason.allowanceReached =>
      localizations.coachServiceFallbackAllowanceReached,
    CoachingFallbackReason.accessUnavailable =>
      localizations.coachServiceFallbackAccessUnavailable,
    CoachingFallbackReason.serviceUnavailable =>
      localizations.coachServiceFallbackServiceUnavailable,
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
    final l10n = context.localizations ?? defaultServiceLocalizations();
    final normalized = message.toLowerCase();
    if (isSafetyConcern(normalized)) {
      return l10n.coachServiceSafetyResponse;
    }
    if (isBoundaryRequest(normalized)) {
      return _boundaryReply(l10n);
    }
    if (isRepairRequest(normalized)) {
      return _repairReply(l10n);
    }
    if (isReflectionRequest(normalized)) {
      return _reflectionReply(normalized, l10n);
    }
    final rememberedSupportMode = _rememberedSupportMode(conversation);
    if (_containsAny(normalized, _listeningSignals)) {
      return _listeningReply(conversation, l10n);
    }
    if (_containsAny(normalized, _directSignals)) {
      return _accountabilityReply(context, l10n);
    }
    if (_containsAny(normalized, _gentleSignals)) {
      return _gentleReply(context, conversation, l10n);
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
      return _setbackReply(context, conversation, l10n);
    }
    if (_containsAny(normalized, const [
      'i am lazy',
      "i'm lazy",
      'i am useless',
      "i'm useless",
      'hate myself',
      'what is wrong with me',
    ])) {
      return _selfCriticismReply(context, l10n);
    }
    if (_containsAny(normalized, const [
      'perfect',
      'perfection',
      'not good enough',
      'afraid it will be bad',
      "afraid it'll be bad",
      'fear of failing',
    ])) {
      return _perfectionismReply(context, l10n);
    }
    if (_containsAny(normalized, const [
      "can't decide",
      'cannot decide',
      'too many options',
      'which one',
      'choose between',
    ])) {
      return _decisionReply(context, l10n);
    }
    if (_containsAny(normalized, const [
      'running out of time',
      'behind schedule',
      'not enough time',
      'deadline',
      'only have',
    ])) {
      return _timePressureReply(context, l10n);
    }
    if (_containsAny(normalized, const [
      'overwhelmed',
      'anxious',
      'stressed',
      'too much',
      "can't handle",
      'cannot handle',
    ])) {
      return _overwhelmReply(context, l10n);
    }
    if (_containsAny(normalized, const [
      'stuck',
      'procrastinat',
      "can't start",
      'cannot start',
      'avoiding',
      'unmotivated',
    ])) {
      return _startingReply(context, conversation, l10n);
    }
    if (_containsAny(normalized, const [
      'distracted',
      "can't focus",
      'cannot focus',
      'mind keeps',
      'wandering',
    ])) {
      return _distractionReply(context, l10n);
    }
    if (_containsAny(normalized, const [
      'tired',
      'exhausted',
      'burned out',
      'burnt out',
      'no energy',
    ])) {
      return _energyReply(context, l10n);
    }
    if (_containsAny(normalized, const [
      'need a break',
      'take a break',
      'pause for a bit',
      'pause for a while',
    ])) {
      return _breakReply(context, l10n);
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
      return _returnReply(context, conversation, l10n);
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
      return _progressReply(context, conversation, l10n);
    }
    if (_containsAny(normalized, const [
      'what should i do',
      'what next',
      'help me plan',
      'prioritize',
      'where do i start',
    ])) {
      return _planningReply(context, l10n);
    }
    if (_containsAny(normalized, const [
      'i did it',
      "i'm done",
      'i am done',
      'finished',
      'proud',
      'small win',
    ])) {
      return _celebrationReply(context, conversation, l10n);
    }
    if (_containsAny(normalized, const [
      'break it down',
      'smaller steps',
      'what are the steps',
      'yes please',
      'please do',
    ])) {
      return _followUpReply(context, conversation, l10n);
    }
    if (_containsAny(normalized, const [
      "i don't know",
      'i do not know',
      "i'm not sure",
      'i am not sure',
      'unsure',
    ])) {
      if (rememberedSupportMode == _CoachingSupportMode.reflective) {
        return _reflectiveUncertaintyReply(l10n);
      }
      return _uncertaintyReply(
        context,
        conversation,
        l10n,
        supportMode: rememberedSupportMode,
      );
    }
    if (rememberedSupportMode == _CoachingSupportMode.reflective) {
      return _reflectionFollowUpReply(conversation, l10n);
    }
    return _generalReply(
      context,
      conversation,
      l10n,
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

  static String? _recentChallenge(
    List<CoachingMessage> conversation,
    AppLocalizations l10n,
  ) {
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
        return l10n.coachServiceChallengeSelfCriticism;
      }
      if (_containsAny(message, const [
        'perfect',
        'perfection',
        'not good enough',
        'afraid it will be bad',
        "afraid it'll be bad",
        'fear of failing',
      ])) {
        return l10n.coachServiceChallengePerfectionism;
      }
      if (_containsAny(message, const [
        "can't decide",
        'cannot decide',
        'too many options',
        'which one',
        'choose between',
      ])) {
        return l10n.coachServiceChallengeTooManyChoices;
      }
      if (_containsAny(message, const [
        'running out of time',
        'behind schedule',
        'not enough time',
        'deadline',
        'only have',
      ])) {
        return l10n.coachServiceChallengeDeadlinePressure;
      }
      if (_containsAny(message, const [
        'overwhelmed',
        'anxious',
        'stressed',
        'too much',
        "can't handle",
        'cannot handle',
      ])) {
        return l10n.coachServiceChallengeOverwhelm;
      }
      if (_containsAny(message, const [
        'stuck',
        'procrastinat',
        "can't start",
        'cannot start',
        'avoiding',
        'unmotivated',
      ])) {
        return l10n.coachServiceChallengeGettingStarted;
      }
      if (_containsAny(message, const [
        'distracted',
        "can't focus",
        'cannot focus',
        'mind keeps',
        'wandering',
      ])) {
        return l10n.coachServiceChallengeDistraction;
      }
      if (_containsAny(message, const [
        'tired',
        'exhausted',
        'burned out',
        'burnt out',
        'no energy',
      ])) {
        return l10n.coachServiceChallengeLowEnergy;
      }
    }
    return null;
  }

  static String _currentTask(CoachingContext context, AppLocalizations l10n) {
    final focusTask = context.focusTask.trim();
    if (focusTask.isNotEmpty) return focusTask;
    final nextQueueTask = context.nextQueueTask?.trim() ?? '';
    if (nextQueueTask.isNotEmpty) return nextQueueTask;
    return l10n.coachServiceDefaultTask;
  }

  static String _boundaryReply(AppLocalizations l10n) =>
      l10n.coachServiceBoundaryResponse;

  static String _repairReply(AppLocalizations l10n) =>
      l10n.coachServiceRepairResponse;

  static String _reflectionReply(String message, AppLocalizations l10n) {
    if (_containsAny(message, const [
      'conflicted',
      'torn',
      'part of me',
      'on one hand',
      'mixed feelings',
    ])) {
      return l10n.coachServiceReflectionConflictResponse;
    }
    return l10n.coachServiceReflectionDefaultResponse;
  }

  static String _reflectionFollowUpReply(
    List<CoachingMessage> conversation,
    AppLocalizations l10n,
  ) {
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
      return l10n.coachServiceReflectionFearFollowUp;
    }
    if (_containsAny(latestUserMessage, const [
      'guilty',
      'guilt',
      'disappoint',
      'let them down',
      'let everyone down',
    ])) {
      return l10n.coachServiceReflectionGuiltFollowUp;
    }
    return l10n.coachServiceReflectionDefaultFollowUp;
  }

  static String _reflectiveUncertaintyReply(AppLocalizations l10n) =>
      l10n.coachServiceReflectiveUncertaintyResponse;

  static String _listeningReply(
    List<CoachingMessage> conversation,
    AppLocalizations l10n,
  ) {
    final challenge = _recentChallenge(conversation, l10n);
    final recognition = challenge == null
        ? ''
        : l10n.coachServiceListeningRecognition(challenge);
    return l10n.coachServiceListeningResponse(recognition);
  }

  static String _gentleReply(
    CoachingContext context,
    List<CoachingMessage> conversation,
    AppLocalizations l10n,
  ) {
    final challenge = _recentChallenge(conversation, l10n);
    final recognition = challenge == null
        ? ''
        : l10n.coachServiceGentleRecognition(challenge);
    return l10n.coachServiceGentleResponse(
      recognition,
      _currentTask(context, l10n),
    );
  }

  static String _accountabilityReply(
    CoachingContext context,
    AppLocalizations l10n,
  ) {
    if (context.dailyGoalMinutes > 0 &&
        context.todayFocusMinutes >= context.dailyGoalMinutes) {
      return l10n.coachServiceAccountabilityGoalMet;
    }
    final task = _currentTask(context, l10n);
    final timerDirection = context.isTimerRunning
        ? l10n.coachServiceAccountabilityTimerRunning
        : l10n.coachServiceAccountabilityTimerStart;
    final queueDirection = context.queueRemaining > 1
        ? l10n.coachServiceAccountabilityQueueMultiple(
            context.queueRemaining - 1,
          )
        : l10n.coachServiceAccountabilityQueueSingle;
    return l10n.coachServiceAccountabilityResponse(
      task,
      queueDirection,
      timerDirection,
    );
  }

  static String _uncertaintyReply(
    CoachingContext context,
    List<CoachingMessage> conversation,
    AppLocalizations l10n, {
    _CoachingSupportMode? supportMode,
  }) {
    final task = _currentTask(context, l10n);
    final challenge = _recentChallenge(conversation, l10n);
    if (supportMode == _CoachingSupportMode.listening) {
      return l10n.coachServiceUncertaintyListeningResponse;
    }
    if (supportMode == _CoachingSupportMode.direct) {
      return l10n.coachServiceUncertaintyDirectResponse(task);
    }
    final gentleOpening = supportMode == _CoachingSupportMode.gentle
        ? l10n.coachServiceGentleOpening
        : '';
    if (challenge != null) {
      return l10n.coachServiceUncertaintyChallengeResponse(
        gentleOpening,
        challenge,
        task,
      );
    }
    return l10n.coachServiceUncertaintyDefaultResponse(gentleOpening, task);
  }

  static String _overwhelmReply(
    CoachingContext context,
    AppLocalizations l10n,
  ) {
    return l10n.coachServiceOverwhelmResponse(_currentTask(context, l10n));
  }

  static String _startingReply(
    CoachingContext context,
    List<CoachingMessage> conversation,
    AppLocalizations l10n,
  ) {
    final task = _currentTask(context, l10n);
    final alreadySuggestedStartingRound = conversation.any(
      (entry) =>
          entry.role == CoachingMessageRole.coach &&
          (entry.text.contains('next five minutes') ||
              entry.text.contains('starting is the win')),
    );
    if (alreadySuggestedStartingRound) {
      return l10n.coachServiceStartingRetryResponse(task);
    }
    return l10n.coachServiceStartingFirstResponse(task);
  }

  static String _setbackReply(
    CoachingContext context,
    List<CoachingMessage> conversation,
    AppLocalizations l10n,
  ) {
    final task = _currentTask(context, l10n);
    final challenge = _recentChallenge(conversation, l10n);
    final memory = challenge == null
        ? ''
        : l10n.coachServiceSetbackMemory(challenge);
    return l10n.coachServiceSetbackResponse(memory, task);
  }

  static String _selfCriticismReply(
    CoachingContext context,
    AppLocalizations l10n,
  ) => l10n.coachServiceSelfCriticismResponse(_currentTask(context, l10n));

  static String _perfectionismReply(
    CoachingContext context,
    AppLocalizations l10n,
  ) => l10n.coachServicePerfectionismResponse(_currentTask(context, l10n));

  static String _decisionReply(CoachingContext context, AppLocalizations l10n) {
    final queueNote = context.queueRemaining > 1
        ? l10n.coachServiceDecisionQueueMultiple(context.queueRemaining)
        : l10n.coachServiceDecisionQueueSingle;
    return l10n.coachServiceDecisionResponse(
      queueNote,
      _currentTask(context, l10n),
    );
  }

  static String _timePressureReply(
    CoachingContext context,
    AppLocalizations l10n,
  ) => l10n.coachServiceTimePressureResponse(_currentTask(context, l10n));

  static String _followUpReply(
    CoachingContext context,
    List<CoachingMessage> conversation,
    AppLocalizations l10n,
  ) {
    final task = _currentTask(context, l10n);
    final continuity = conversation.any(
      (entry) => entry.role == CoachingMessageRole.coach,
    );
    final challenge = _recentChallenge(conversation, l10n);
    final opening = continuity
        ? l10n.coachServiceFollowUpContinuingOpening
        : l10n.coachServiceFollowUpNewOpening;
    final memory = challenge == null
        ? ''
        : l10n.coachServiceFollowUpMemory(challenge);
    return l10n.coachServiceFollowUpResponse(opening, memory, task);
  }

  static String _distractionReply(
    CoachingContext context,
    AppLocalizations l10n,
  ) {
    final savedThoughts = context.parkedThoughtCount;
    final parkingNote = savedThoughts == 0
        ? l10n.coachServiceDistractionParkingEmpty
        : l10n.coachServiceDistractionParkingSaved(savedThoughts);
    return l10n.coachServiceDistractionResponse(
      parkingNote,
      _currentTask(context, l10n),
    );
  }

  static String _energyReply(CoachingContext context, AppLocalizations l10n) {
    if (context.todayFocusMinutes >= context.dailyGoalMinutes) {
      return l10n.coachServiceEnergyGoalMet;
    }
    return l10n.coachServiceEnergyLowResponse(_currentTask(context, l10n));
  }

  static String _breakReply(CoachingContext context, AppLocalizations l10n) {
    if (context.dailyGoalMinutes > 0 &&
        context.todayFocusMinutes >= context.dailyGoalMinutes) {
      return l10n.coachServiceBreakGoalMet;
    }
    final timerNote = context.isTimerRunning
        ? l10n.coachServiceBreakTimerRunning
        : '';
    return l10n.coachServiceBreakResponse(
      timerNote,
      _currentTask(context, l10n),
    );
  }

  static String _returnReply(
    CoachingContext context,
    List<CoachingMessage> conversation,
    AppLocalizations l10n,
  ) {
    final task = _currentTask(context, l10n);
    final challenge = _recentChallenge(conversation, l10n);
    final memory = challenge == null
        ? ''
        : l10n.coachServiceReturnMemory(challenge);
    final timerNote = context.isTimerRunning
        ? l10n.coachServiceReturnTimerRunning
        : '';
    return l10n.coachServiceReturnResponse(memory, timerNote, task);
  }

  static String _progressReply(
    CoachingContext context,
    List<CoachingMessage> conversation,
    AppLocalizations l10n,
  ) {
    final task = _currentTask(context, l10n);
    final challenge = _recentChallenge(conversation, l10n);
    final memory = challenge == null
        ? ''
        : l10n.coachServiceProgressMemory(challenge);
    final pace = context.isTimerRunning
        ? l10n.coachServiceProgressPaceRunning
        : l10n.coachServiceProgressPaceStopped;
    return l10n.coachServiceProgressResponse(memory, pace, task);
  }

  static String _planningReply(CoachingContext context, AppLocalizations l10n) {
    final task = _currentTask(context, l10n);
    final queueNote = context.queueRemaining > 1
        ? l10n.coachServicePlanningQueueMultiple(context.queueRemaining - 1)
        : l10n.coachServicePlanningQueueSingle;
    return l10n.coachServicePlanningResponse(task, queueNote);
  }

  static String _celebrationReply(
    CoachingContext context,
    List<CoachingMessage> conversation,
    AppLocalizations l10n,
  ) {
    final progress = context.todayFocusMinutes > 0
        ? l10n.coachServiceCelebrationProgress(context.todayFocusMinutes)
        : '';
    final challenge = _recentChallenge(conversation, l10n);
    final memory = challenge == null
        ? ''
        : l10n.coachServiceCelebrationMemory(challenge);
    return l10n.coachServiceCelebrationResponse(progress, memory);
  }

  static String _generalReply(
    CoachingContext context,
    List<CoachingMessage> conversation,
    AppLocalizations l10n, {
    _CoachingSupportMode? supportMode,
  }) {
    final task = _currentTask(context, l10n);
    if (supportMode == _CoachingSupportMode.listening) {
      return _listeningReply(conversation, l10n);
    }
    if (supportMode == _CoachingSupportMode.direct) {
      final timerDirection = context.isTimerRunning
          ? l10n.coachServiceGeneralDirectTimerRunning
          : l10n.coachServiceGeneralDirectTimerStart;
      return l10n.coachServiceGeneralDirectResponse(task, timerDirection);
    }
    final gentleOpening = supportMode == _CoachingSupportMode.gentle
        ? l10n.coachServiceGeneralGentleOpening
        : '';
    final mood = context.recentMood?.trim();
    final profile = context.focusProfile?.trim();
    final personalNote = mood?.isNotEmpty == true
        ? l10n.coachServiceGeneralMoodNote(mood!)
        : profile?.isNotEmpty == true
        ? l10n.coachServiceGeneralProfileNote(profile!)
        : l10n.coachServiceGeneralDefaultNote;
    final challenge = _recentChallenge(conversation, l10n);
    if (challenge != null) {
      return l10n.coachServiceGeneralChallengeResponse(
        gentleOpening,
        personalNote,
        challenge,
        task,
      );
    }
    final continuity = conversation.length > 2
        ? l10n.coachServiceGeneralContinuity
        : '';
    return l10n.coachServiceGeneralResponse(
      gentleOpening,
      personalNote,
      continuity,
      task,
    );
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
  bool _isManagingPrivateData = false;
  bool _enhancedCoachingEnabled = false;
  bool _isDisposed = false;
  String? _errorMessage;
  String? _noticeMessage;

  late final Future<void> initialized;

  List<CoachingMessage> get messages => List.unmodifiable(_messages);
  int get conversationRevision => _conversationRevision;
  bool get isResponding => _isResponding;
  bool get isManagingPrivateData => _isManagingPrivateData;
  bool get canRetryResponse =>
      !_isDisposed &&
      !_isResponding &&
      !_isManagingPrivateData &&
      _messages.isNotEmpty &&
      _messages.last.role == CoachingMessageRole.user;
  bool get enhancedCoachingAvailable => _enhancedResponder != null;
  bool get enhancedCoachingEnabled => _enhancedCoachingEnabled;
  String? get errorMessage => _errorMessage;
  String? get noticeMessage => _noticeMessage;

  Future<bool> send(
    String message,
    CoachingContext context, {
    AppLocalizations? localizations,
  }) async {
    final l10n = localizations ?? defaultServiceLocalizations();
    final cleanedMessage = _cleanText(message);
    if (cleanedMessage == null) return false;
    await initialized;
    if (_isDisposed ||
        _isResponding ||
        _isManagingPrivateData ||
        canRetryResponse) {
      return false;
    }

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
      if (_isDisposed) return false;
      userMessageCommitted = true;
      return await _completeResponse(cleanedMessage, context, l10n);
    } catch (error) {
      if (_isDisposed) return false;
      if (!userMessageCommitted) _messages = previousMessages;
      _isResponding = false;
      _errorMessage = l10n.coachServiceResponseError;
      PrivacySafeDiagnostics.report(
        FocusHavenDiagnosticEvent.coachResponse,
        error: error,
      );
      _notifyConversationChanged();
      return false;
    }
  }

  Future<bool> retryLastResponse(
    CoachingContext context, {
    AppLocalizations? localizations,
  }) async {
    final l10n = localizations ?? defaultServiceLocalizations();
    await initialized;
    if (!canRetryResponse) return false;

    final message = _messages.last.text;
    _isResponding = true;
    _errorMessage = null;
    _noticeMessage = null;
    _notifyConversationChanged();
    try {
      return await _completeResponse(message, context, l10n);
    } catch (error) {
      if (_isDisposed) return false;
      _isResponding = false;
      _errorMessage = l10n.coachServiceResponseError;
      PrivacySafeDiagnostics.report(
        FocusHavenDiagnosticEvent.coachResponseRetry,
        error: error,
      );
      _notifyConversationChanged();
      return false;
    }
  }

  Future<bool> _completeResponse(
    String message,
    CoachingContext context,
    AppLocalizations l10n,
  ) async {
    final requiresLocalResponse =
        LocalCoachingResponder.isSafetyConcern(message) ||
        LocalCoachingResponder.isBoundaryRequest(message) ||
        LocalCoachingResponder.isRepairRequest(message) ||
        LocalCoachingResponder.isReflectiveConversation(_messages);
    final responder = requiresLocalResponse
        ? _localResponder
        : _enhancedCoachingEnabled && _enhancedResponder != null
        ? _enhancedResponder
        : _localResponder;
    final response = await responder.respond(
      message: message,
      context: context.withLocalizations(l10n),
      conversation: List.unmodifiable(_messages),
    );
    if (_isDisposed) return false;
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
    _noticeMessage = fallbackReason?.userMessage(l10n);
    _isResponding = false;
    _notifyConversationChanged();
    return true;
  }

  Future<bool> setEnhancedCoachingEnabled(
    bool enabled, {
    AppLocalizations? localizations,
  }) async {
    final l10n = localizations ?? defaultServiceLocalizations();
    await initialized;
    if (_isDisposed ||
        _isResponding ||
        _isManagingPrivateData ||
        _enhancedResponder == null) {
      return false;
    }
    if (_enhancedCoachingEnabled == enabled) return false;

    _setManagingPrivateData(true);
    try {
      late final bool saved;
      try {
        final preferences = await SharedPreferences.getInstance();
        saved = await _saveEnhancedPreference(preferences, enabled);
      } catch (error) {
        if (_isDisposed) return false;
        _reportEnhancedPreferenceSaveFailure(l10n);
        PrivacySafeDiagnostics.report(
          FocusHavenDiagnosticEvent.coachEnhancedPreferenceSave,
          error: error,
        );
        return false;
      }
      if (_isDisposed) return false;
      if (!saved) {
        _reportEnhancedPreferenceSaveFailure(l10n);
        return false;
      }

      _enhancedCoachingEnabled = enabled;
      _errorMessage = null;
      _noticeMessage = null;
      notifyListeners();
      return true;
    } finally {
      _setManagingPrivateData(false);
    }
  }

  Future<bool> clearConversation({AppLocalizations? localizations}) =>
      _clearLocalData(
        includeEnhancedPreference: false,
        localizations: localizations,
      );

  Future<bool> clearLocalData({AppLocalizations? localizations}) =>
      _clearLocalData(
        includeEnhancedPreference: true,
        localizations: localizations,
      );

  Future<bool> _clearLocalData({
    required bool includeEnhancedPreference,
    AppLocalizations? localizations,
  }) async {
    final l10n = localizations ?? defaultServiceLocalizations();
    await initialized;
    if (_isDisposed || _isResponding || _isManagingPrivateData) return false;

    _setManagingPrivateData(true);
    try {
      return await _performClearLocalData(
        includeEnhancedPreference: includeEnhancedPreference,
        localizations: l10n,
      );
    } catch (error) {
      if (_isDisposed) return false;
      _errorMessage = l10n.coachServicePrivateClearError;
      PrivacySafeDiagnostics.report(
        FocusHavenDiagnosticEvent.coachPrivateCleanup,
        error: error,
      );
      notifyListeners();
      return false;
    } finally {
      _setManagingPrivateData(false);
    }
  }

  Future<bool> _performClearLocalData({
    required bool includeEnhancedPreference,
    required AppLocalizations localizations,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final conversationCleared = await _removePrivateValue(
      preferences,
      _storageKey,
    );
    final enhancedPreferenceCleared =
        !includeEnhancedPreference ||
        await _removePrivateValue(preferences, _enhancedCoachingKey);
    if (_isDisposed) return false;

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
        : localizations.coachServicePrivateClearError;

    if (conversationChanged) {
      _notifyConversationChanged();
    } else if (settingChanged || !clearCompleted) {
      notifyListeners();
    }
    return clearCompleted;
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
        await _removeInvalidStoredValue(preferences, _enhancedCoachingKey);
      }
      final savedValue = preferences.get(_storageKey);
      if (savedValue == null) return;
      if (savedValue is! String) {
        await _removeInvalidStoredValue(preferences, _storageKey);
        return;
      }

      final decoded = jsonDecode(savedValue);
      if (decoded is! List) {
        await _removeInvalidStoredValue(preferences, _storageKey);
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
        await _removeInvalidStoredValue(preferences, _storageKey);
      } else if (normalizedStorage != savedValue) {
        final repaired = await _saveConversation(preferences, _messages);
        if (!repaired) {
          _reportStorageRepairFailure();
        }
      }
      if (_isDisposed || _messages.isEmpty) return;
      _notifyConversationChanged();
    } on FormatException {
      await _removeCorruptedStorage();
    } on TypeError {
      await _removeCorruptedStorage();
    } catch (error) {
      PrivacySafeDiagnostics.report(
        FocusHavenDiagnosticEvent.coachConversationLoad,
        error: error,
      );
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
      await _removeInvalidStoredValue(preferences, _storageKey);
    } catch (error) {
      PrivacySafeDiagnostics.report(
        FocusHavenDiagnosticEvent.coachCorruptCleanup,
        error: error,
      );
      _reportStorageRepairFailure();
    }
  }

  Future<void> _removeInvalidStoredValue(
    SharedPreferences preferences,
    String key,
  ) async {
    final removed = await _removePrivateValue(preferences, key);
    if (!removed) _reportStorageRepairFailure();
  }

  Future<bool> _removePrivateValue(
    SharedPreferences preferences,
    String key,
  ) async {
    try {
      return await _removePreference(preferences, key);
    } catch (error) {
      PrivacySafeDiagnostics.report(
        FocusHavenDiagnosticEvent.coachPreferenceCleanup,
        error: error,
      );
      return false;
    }
  }

  void _reportStorageRepairFailure([AppLocalizations? localizations]) {
    if (_isDisposed) return;
    final l10n = localizations ?? defaultServiceLocalizations();
    _errorMessage = l10n.coachServiceStorageRepairError;
    PrivacySafeDiagnostics.report(FocusHavenDiagnosticEvent.coachStorageRepair);
    notifyListeners();
  }

  void _reportEnhancedPreferenceSaveFailure(AppLocalizations localizations) {
    if (_isDisposed) return;
    _errorMessage = localizations.coachServiceEnhancedPreferenceError;
    _noticeMessage = null;
    notifyListeners();
  }

  void _setManagingPrivateData(bool value) {
    if (_isManagingPrivateData == value) return;
    _isManagingPrivateData = value;
    if (!_isDisposed) notifyListeners();
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
