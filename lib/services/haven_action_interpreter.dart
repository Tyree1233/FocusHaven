import 'dart:math';

import '../l10n/app_localizations.dart';
import '../l10n/service_localizations.dart';
import '../models/haven_action.dart';

typedef HavenActionClock = DateTime Function();
typedef HavenActionIdGenerator = String Function();

class HavenActionInterpreter {
  HavenActionInterpreter({
    HavenActionClock? clock,
    HavenActionIdGenerator? idGenerator,
  }) : _clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? _secureId;

  static const maxInputLength = 240;
  static const maxQueueTitleLength = 100;
  static const maxAddedMinutes = 60;
  static const proposalLifetime = Duration(minutes: 2);

  final HavenActionClock _clock;
  final HavenActionIdGenerator _idGenerator;

  HavenActionInterpretation interpret(
    String input,
    HavenActionState state, {
    HavenActionSource source = HavenActionSource.typed,
    AppLocalizations? localizations,
  }) {
    final l10n = localizations ?? defaultServiceLocalizations();
    if (source != HavenActionSource.typed &&
        source != HavenActionSource.voiceTranscript) {
      return HavenActionInterpretation.rejected(
        HavenActionInterpretationStatus.unsupported,
        l10n.havenActionServiceUnsupportedSource,
      );
    }
    final normalized = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      return HavenActionInterpretation.rejected(
        HavenActionInterpretationStatus.empty,
        l10n.havenActionServiceEmptyRequest,
      );
    }
    if (normalized.length > maxInputLength) {
      return HavenActionInterpretation.rejected(
        HavenActionInterpretationStatus.unsupported,
        l10n.havenActionServiceRequestTooLong,
      );
    }

    final lower = normalized.toLowerCase();
    if (_containsProtectedRequest(lower)) {
      return HavenActionInterpretation.rejected(
        HavenActionInterpretationStatus.unsupported,
        l10n.havenActionServiceProtectedAction,
      );
    }
    if (_queueCandidate(normalized, l10n) == null &&
        _containsMultipleActionIntents(lower)) {
      return HavenActionInterpretation.rejected(
        HavenActionInterpretationStatus.ambiguous,
        l10n.havenActionServiceMultipleActions,
      );
    }

    final candidates = <_Candidate>[];
    void add(_Candidate? candidate) {
      if (candidate != null) candidates.add(candidate);
    }

    add(_timerStatusCandidate(lower, state, l10n));
    add(_startCandidate(lower, l10n));
    add(_simpleCandidate(lower, 'pause', HavenActionKind.pauseTimer, l10n));
    add(_simpleCandidate(lower, 'resume', HavenActionKind.resumeTimer, l10n));
    add(_addTimeCandidate(lower, l10n));
    add(_openCandidate(lower, l10n));
    add(_queueCandidate(normalized, l10n));

    if (candidates.length > 1) {
      return HavenActionInterpretation.rejected(
        HavenActionInterpretationStatus.ambiguous,
        l10n.havenActionServiceMultipleActions,
      );
    }
    if (candidates.isEmpty) {
      return HavenActionInterpretation.rejected(
        HavenActionInterpretationStatus.unsupported,
        l10n.havenActionServiceUnsupportedAction,
      );
    }

    final candidate = candidates.single;
    if (candidate.rejection != null) {
      return HavenActionInterpretation.rejected(
        HavenActionInterpretationStatus.unsupported,
        candidate.rejection!,
      );
    }
    final now = _clock().toUtc();
    return HavenActionInterpretation.proposed(
      HavenActionProposal(
        schemaVersion: 1,
        id: _idGenerator(),
        source: source,
        kind: candidate.kind,
        arguments: candidate.arguments,
        interpretation: candidate.interpretation,
        effect: candidate.effect,
        stateToken: state.token,
        createdAtUtc: now,
        expiresAtUtc: now.add(proposalLifetime),
        risk: candidate.risk,
        confirmationRequired: candidate.confirmationRequired,
        safeUndoAvailable: candidate.safeUndoAvailable,
      ),
    );
  }

  _Candidate? _timerStatusCandidate(
    String lower,
    HavenActionState state,
    AppLocalizations l10n,
  ) {
    const phrases = <String>[
      'timer status',
      'what is my timer',
      "what's my timer",
      'how much time is left',
      'time remaining',
      'check timer',
    ];
    if (!phrases.contains(lower)) return null;
    return _Candidate(
      kind: HavenActionKind.readTimerStatus,
      arguments: const HavenActionArguments.none(),
      interpretation: l10n.havenActionServiceTimerStatusInterpretation,
      effect: _statusText(state, l10n),
      risk: HavenActionRisk.informational,
      confirmationRequired: false,
      safeUndoAvailable: true,
    );
  }

  _Candidate? _startCandidate(String lower, AppLocalizations l10n) {
    if (!RegExp(
      r'^(?:please\s+)?(?:start|begin)(?:\s+(?:the|a))?(?:\s+(?:focus|short break|long break))?(?:\s+timer|\s+session)?$',
    ).hasMatch(lower)) {
      return null;
    }
    final session = lower.contains('short break')
        ? HavenSessionKind.shortBreak
        : lower.contains('long break')
        ? HavenSessionKind.longBreak
        : HavenSessionKind.focus;
    final label = _sessionLabel(session, l10n);
    return _Candidate(
      kind: HavenActionKind.startTimer,
      arguments: HavenActionArguments.start(session),
      interpretation: l10n.havenActionServiceStartTimerInterpretation(label),
      effect: l10n.havenActionServiceStartTimerEffect(label),
      risk: HavenActionRisk.reversibleControl,
      confirmationRequired: false,
      safeUndoAvailable: true,
    );
  }

  _Candidate? _simpleCandidate(
    String lower,
    String verb,
    HavenActionKind kind,
    AppLocalizations l10n,
  ) {
    if (!RegExp(
      '^(?:please\\s+)?$verb(?:\\s+(?:the\\s+)?timer)?\$',
    ).hasMatch(lower)) {
      return null;
    }
    final title = switch (kind) {
      HavenActionKind.pauseTimer =>
        l10n.havenActionServicePauseTimerInterpretation,
      HavenActionKind.resumeTimer =>
        l10n.havenActionServiceResumeTimerInterpretation,
      _ => throw StateError('Unsupported simple Haven action.'),
    };
    final effect = switch (kind) {
      HavenActionKind.pauseTimer => l10n.havenActionServicePauseTimerEffect,
      HavenActionKind.resumeTimer => l10n.havenActionServiceResumeTimerEffect,
      _ => throw StateError('Unsupported simple Haven action.'),
    };
    return _Candidate(
      kind: kind,
      arguments: const HavenActionArguments.none(),
      interpretation: title,
      effect: effect,
      risk: HavenActionRisk.reversibleControl,
      confirmationRequired: false,
      safeUndoAvailable: true,
    );
  }

  _Candidate? _addTimeCandidate(String lower, AppLocalizations l10n) {
    final hasAddTimeIntent = RegExp(
      r'^(?:please\s+)?(?:add|extend)\b.*\b(?:time|minute|minutes|min)\b',
    ).hasMatch(lower);
    if (!hasAddTimeIntent) return null;
    final match = RegExp(
      r'^(?:please\s+)?(?:add|extend)\s+(\d{1,4})\s*(?:minute|minutes|min)(?:\s+(?:to\s+)?(?:the\s+)?timer)?$',
    ).firstMatch(lower);
    if (match == null) {
      return _Candidate.rejected(
        HavenActionKind.addTime,
        l10n.havenActionServiceAddTimePrompt,
      );
    }
    final minutes = int.parse(match.group(1)!);
    if (minutes < 1 || minutes > maxAddedMinutes) {
      return _Candidate.rejected(
        HavenActionKind.addTime,
        l10n.havenActionServiceAddedTimeInvalid,
      );
    }
    return _Candidate(
      kind: HavenActionKind.addTime,
      arguments: HavenActionArguments.addTime(minutes * 60),
      interpretation: l10n.havenActionServiceAddTimeInterpretation(minutes),
      effect: l10n.havenActionServiceAddTimeEffect,
      risk: HavenActionRisk.reversibleControl,
      confirmationRequired: false,
      safeUndoAvailable: true,
    );
  }

  _Candidate? _openCandidate(String lower, AppLocalizations l10n) {
    final match = RegExp(
      r'^(?:please\s+)?(?:open|show|go to)\s+(?:the\s+)?(.+)$',
    ).firstMatch(lower);
    if (match == null) return null;
    final destination = match.group(1);
    final surface = switch (destination) {
      'focus queue' || 'queue' => HavenActionSurface.focusQueue,
      'haven plan' || 'planner' => HavenActionSurface.havenPlan,
      'smart reset' => HavenActionSurface.smartReset,
      'focus coach' ||
      'local focus coach' ||
      'coach' => HavenActionSurface.localCoach,
      'settings' || 'account' => HavenActionSurface.settings,
      _ => null,
    };
    if (surface == null) return null;
    final label = _surfaceLabel(surface, l10n);
    return _Candidate(
      kind: HavenActionKind.openSurface,
      arguments: HavenActionArguments.open(surface),
      interpretation: l10n.havenActionServiceOpenInterpretation(label),
      effect: l10n.havenActionServiceOpenEffect(label),
      risk: HavenActionRisk.informational,
      confirmationRequired: false,
      safeUndoAvailable: true,
    );
  }

  _Candidate? _queueCandidate(String original, AppLocalizations l10n) {
    final match = RegExp(
      r'^(?:please\s+)?(?:add|draft)\s+(?:a\s+)?(?:task|queue item)(?:\s+(?:called|named))?\s*[:\-]?\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(original);
    if (match == null) return null;
    final title = match.group(1)!.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (title.isEmpty || title.length > maxQueueTitleLength) {
      return _Candidate.rejected(
        HavenActionKind.draftQueueItem,
        l10n.havenActionServiceQueueItemInvalid,
      );
    }
    return _Candidate(
      kind: HavenActionKind.draftQueueItem,
      arguments: HavenActionArguments.queueItem(title),
      interpretation: l10n.havenActionServiceQueueItemInterpretation,
      effect: l10n.havenActionServiceQueueItemEffect(title),
      risk: HavenActionRisk.statefulEdit,
      confirmationRequired: true,
      safeUndoAvailable: true,
    );
  }

  static bool _containsProtectedRequest(String lower) {
    const protectedPhrases = <String>[
      'delete account',
      'delete my account',
      'clear history',
      'delete local data',
      'delete cloud',
      'sign out',
      'reset timer',
      'discard',
      'purchase',
      'subscription',
      'permission',
      'calendar',
      'deploy',
      'app check',
      'firebase',
      'testflight',
      'submit for review',
      'remote coaching',
    ];
    return protectedPhrases.any(lower.contains);
  }

  static bool _containsMultipleActionIntents(String lower) {
    final intentPatterns = <RegExp>[
      RegExp(r'\b(?:start|begin)\b'),
      RegExp(r'\bpause\b'),
      RegExp(r'\bresume\b'),
      RegExp(r'\b(?:add|extend)\b.*\b(?:time|minute|minutes|min)\b'),
      RegExp(r'\b(?:open|show|go to)\b'),
      RegExp(r'\b(?:add|draft)\b.*\b(?:task|queue item)\b'),
      RegExp(
        r'\b(?:timer status|what is my timer|what\x27s my timer|how much time is left|time remaining|check timer)\b',
      ),
    ];
    return intentPatterns.where((pattern) => pattern.hasMatch(lower)).length >
        1;
  }

  static String _statusText(HavenActionState state, AppLocalizations l10n) {
    final minutes = state.secondsRemaining ~/ 60;
    final seconds = state.secondsRemaining % 60;
    final time = '$minutes:${seconds.toString().padLeft(2, '0')}';
    return l10n.havenActionServiceTimerStatusEffect(
      _sessionLabel(state.session, l10n),
      _activityLabel(state.activity, l10n),
      time,
    );
  }

  static String _sessionLabel(
    HavenSessionKind session,
    AppLocalizations l10n,
  ) => switch (session) {
    HavenSessionKind.focus => l10n.havenActionServiceSessionFocus,
    HavenSessionKind.shortBreak => l10n.havenActionServiceSessionShortBreak,
    HavenSessionKind.longBreak => l10n.havenActionServiceSessionLongBreak,
  };

  static String _activityLabel(
    HavenTimerActivity activity,
    AppLocalizations l10n,
  ) => switch (activity) {
    HavenTimerActivity.ready => l10n.havenActionServiceActivityReady,
    HavenTimerActivity.running => l10n.havenActionServiceActivityRunning,
    HavenTimerActivity.paused => l10n.havenActionServiceActivityPaused,
    HavenTimerActivity.pendingResume =>
      l10n.havenActionServiceActivityPendingResume,
    HavenTimerActivity.completed => l10n.havenActionServiceActivityCompleted,
  };

  static String _surfaceLabel(
    HavenActionSurface surface,
    AppLocalizations l10n,
  ) => switch (surface) {
    HavenActionSurface.focusQueue => l10n.havenActionServiceSurfaceFocusQueue,
    HavenActionSurface.havenPlan => l10n.havenActionServiceSurfaceHavenPlan,
    HavenActionSurface.smartReset => l10n.havenActionServiceSurfaceSmartReset,
    HavenActionSurface.localCoach => l10n.havenActionServiceSurfaceLocalCoach,
    HavenActionSurface.settings => l10n.havenActionServiceSurfaceSettings,
  };

  static String _secureId() {
    final random = Random.secure();
    final values = List<int>.generate(4, (_) => random.nextInt(1 << 32));
    return '${DateTime.now().microsecondsSinceEpoch}-${values.map((value) => value.toRadixString(16).padLeft(8, '0')).join()}';
  }
}

class _Candidate {
  const _Candidate({
    required this.kind,
    required this.arguments,
    required this.interpretation,
    required this.effect,
    required this.risk,
    required this.confirmationRequired,
    required this.safeUndoAvailable,
  }) : rejection = null;

  const _Candidate.rejected(this.kind, this.rejection)
    : arguments = const HavenActionArguments.none(),
      interpretation = '',
      effect = '',
      risk = HavenActionRisk.informational,
      confirmationRequired = false,
      safeUndoAvailable = false;

  final HavenActionKind kind;
  final HavenActionArguments arguments;
  final String interpretation;
  final String effect;
  final HavenActionRisk risk;
  final bool confirmationRequired;
  final bool safeUndoAvailable;
  final String? rejection;
}
