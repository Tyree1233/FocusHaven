import 'dart:math';

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

  HavenActionInterpretation interpret(String input, HavenActionState state) {
    final normalized = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      return const HavenActionInterpretation.rejected(
        HavenActionInterpretationStatus.empty,
        'Type one request for Haven to review.',
      );
    }
    if (normalized.length > maxInputLength) {
      return const HavenActionInterpretation.rejected(
        HavenActionInterpretationStatus.unsupported,
        'Keep a Haven action request under 240 characters.',
      );
    }

    final lower = normalized.toLowerCase();
    if (_containsProtectedRequest(lower)) {
      return const HavenActionInterpretation.rejected(
        HavenActionInterpretationStatus.unsupported,
        'That action stays in its protected screen and cannot be run here.',
      );
    }
    if (_queueCandidate(normalized) == null &&
        _containsMultipleActionIntents(lower)) {
      return const HavenActionInterpretation.rejected(
        HavenActionInterpretationStatus.ambiguous,
        'I found more than one action. Please ask for one change at a time.',
      );
    }

    final candidates = <_Candidate>[];
    void add(_Candidate? candidate) {
      if (candidate != null) candidates.add(candidate);
    }

    add(_timerStatusCandidate(lower, state));
    add(_startCandidate(lower));
    add(_simpleCandidate(lower, 'pause', HavenActionKind.pauseTimer));
    add(_simpleCandidate(lower, 'resume', HavenActionKind.resumeTimer));
    add(_addTimeCandidate(lower));
    add(_openCandidate(lower));
    add(_queueCandidate(normalized));

    if (candidates.length > 1) {
      return const HavenActionInterpretation.rejected(
        HavenActionInterpretationStatus.ambiguous,
        'I found more than one action. Please ask for one change at a time.',
      );
    }
    if (candidates.isEmpty) {
      return const HavenActionInterpretation.rejected(
        HavenActionInterpretationStatus.unsupported,
        'I could not match that to a safe local Haven action.',
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
        source: HavenActionSource.typed,
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

  _Candidate? _timerStatusCandidate(String lower, HavenActionState state) {
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
      interpretation: 'Read the current timer status',
      effect: _statusText(state),
      risk: HavenActionRisk.informational,
      confirmationRequired: false,
      safeUndoAvailable: true,
    );
  }

  _Candidate? _startCandidate(String lower) {
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
    final label = _sessionLabel(session);
    return _Candidate(
      kind: HavenActionKind.startTimer,
      arguments: HavenActionArguments.start(session),
      interpretation: 'Start a $label timer',
      effect: 'Select $label and start it if the timer is ready.',
      risk: HavenActionRisk.reversibleControl,
      confirmationRequired: false,
      safeUndoAvailable: true,
    );
  }

  _Candidate? _simpleCandidate(
    String lower,
    String verb,
    HavenActionKind kind,
  ) {
    if (!RegExp(
      '^(?:please\\s+)?$verb(?:\\s+(?:the\\s+)?timer)?\$',
    ).hasMatch(lower)) {
      return null;
    }
    final title = '${verb[0].toUpperCase()}${verb.substring(1)} the timer';
    return _Candidate(
      kind: kind,
      arguments: const HavenActionArguments.none(),
      interpretation: title,
      effect: '$title using the private timer service.',
      risk: HavenActionRisk.reversibleControl,
      confirmationRequired: false,
      safeUndoAvailable: true,
    );
  }

  _Candidate? _addTimeCandidate(String lower) {
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
        'Say how many minutes to add, from 1 to 60.',
      );
    }
    final minutes = int.parse(match.group(1)!);
    if (minutes < 1 || minutes > maxAddedMinutes) {
      return _Candidate.rejected(
        HavenActionKind.addTime,
        'Added time must be from 1 to 60 minutes. Nothing was changed.',
      );
    }
    return _Candidate(
      kind: HavenActionKind.addTime,
      arguments: HavenActionArguments.addTime(minutes * 60),
      interpretation: 'Add $minutes ${minutes == 1 ? 'minute' : 'minutes'}',
      effect: 'Extend only the current active or paused timer.',
      risk: HavenActionRisk.reversibleControl,
      confirmationRequired: false,
      safeUndoAvailable: true,
    );
  }

  _Candidate? _openCandidate(String lower) {
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
    final label = _surfaceLabel(surface);
    return _Candidate(
      kind: HavenActionKind.openSurface,
      arguments: HavenActionArguments.open(surface),
      interpretation: 'Open $label',
      effect: 'Navigate to the existing $label screen without changing data.',
      risk: HavenActionRisk.informational,
      confirmationRequired: false,
      safeUndoAvailable: true,
    );
  }

  _Candidate? _queueCandidate(String original) {
    final match = RegExp(
      r'^(?:please\s+)?(?:add|draft)\s+(?:a\s+)?(?:task|queue item)(?:\s+(?:called|named))?\s*[:\-]?\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(original);
    if (match == null) return null;
    final title = match.group(1)!.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (title.isEmpty || title.length > maxQueueTitleLength) {
      return _Candidate.rejected(
        HavenActionKind.draftQueueItem,
        'A queue item must be between 1 and 100 characters.',
      );
    }
    return _Candidate(
      kind: HavenActionKind.draftQueueItem,
      arguments: HavenActionArguments.queueItem(title),
      interpretation: 'Draft one Focus Queue item',
      effect: 'Add “$title” to the private Focus Queue after confirmation.',
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

  static String _statusText(HavenActionState state) {
    final minutes = state.secondsRemaining ~/ 60;
    final seconds = state.secondsRemaining % 60;
    final time = '$minutes:${seconds.toString().padLeft(2, '0')}';
    return '${_sessionLabel(state.session)} is ${state.activity.name} with $time remaining.';
  }

  static String _sessionLabel(HavenSessionKind session) => switch (session) {
    HavenSessionKind.focus => 'Focus',
    HavenSessionKind.shortBreak => 'Short break',
    HavenSessionKind.longBreak => 'Long break',
  };

  static String _surfaceLabel(HavenActionSurface surface) => switch (surface) {
    HavenActionSurface.focusQueue => 'Focus Queue',
    HavenActionSurface.havenPlan => 'Haven Plan',
    HavenActionSurface.smartReset => 'Smart Reset',
    HavenActionSurface.localCoach => 'local Focus Coach',
    HavenActionSurface.settings => 'settings',
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
