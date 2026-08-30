enum HavenActionSource { typed, voiceTranscript, localCoach, systemIntent }

enum HavenActionKind {
  readTimerStatus,
  startTimer,
  pauseTimer,
  resumeTimer,
  addTime,
  openSurface,
  draftQueueItem,
}

enum HavenActionSurface {
  focusQueue,
  havenPlan,
  smartReset,
  localCoach,
  settings,
}

enum HavenActionRisk { informational, reversibleControl, statefulEdit }

enum HavenSessionKind { focus, shortBreak, longBreak }

enum HavenTimerActivity { ready, running, paused, pendingResume, completed }

enum HavenActionInterpretationStatus { proposed, empty, ambiguous, unsupported }

enum HavenActionOutcome { executed, rejected, failed }

enum HavenActionReason {
  none,
  emptyInput,
  ambiguousInput,
  unsupportedInput,
  invalidProposal,
  unavailableInCurrentState,
  staleProposal,
  expiredProposal,
  duplicateProposal,
  confirmationRequired,
  confirmationMismatch,
  serviceRejected,
  serviceFailure,
}

class HavenActionArguments {
  const HavenActionArguments._({
    this.session,
    this.durationSeconds,
    this.surface,
    this.queueTitle,
  });

  const HavenActionArguments.none() : this._();

  const HavenActionArguments.start(HavenSessionKind session)
    : this._(session: session);

  const HavenActionArguments.addTime(int durationSeconds)
    : this._(durationSeconds: durationSeconds);

  const HavenActionArguments.open(HavenActionSurface surface)
    : this._(surface: surface);

  const HavenActionArguments.queueItem(String queueTitle)
    : this._(queueTitle: queueTitle);

  final HavenSessionKind? session;
  final int? durationSeconds;
  final HavenActionSurface? surface;
  final String? queueTitle;

  String get fingerprint => <Object?>[
    session?.name,
    durationSeconds,
    surface?.name,
    queueTitle,
  ].join('|');
}

class HavenActionState {
  const HavenActionState({
    required this.session,
    required this.activity,
    required this.secondsRemaining,
    required this.totalSessionSeconds,
    required this.queueRevision,
    required this.canStartHavenPlan,
    required this.canOfferSmartReset,
  });

  final HavenSessionKind session;
  final HavenTimerActivity activity;
  final int secondsRemaining;
  final int totalSessionSeconds;
  final int queueRevision;
  final bool canStartHavenPlan;
  final bool canOfferSmartReset;

  /// A control-state token. The live countdown is intentionally excluded so a
  /// reviewed proposal does not become stale merely because one second passed.
  String get token => <Object>[
    session.name,
    activity.name,
    totalSessionSeconds,
    queueRevision,
    canStartHavenPlan,
    canOfferSmartReset,
  ].join('|');
}

class HavenActionProposal {
  const HavenActionProposal({
    required this.schemaVersion,
    required this.id,
    required this.source,
    required this.kind,
    required this.arguments,
    required this.interpretation,
    required this.effect,
    required this.stateToken,
    required this.createdAtUtc,
    required this.expiresAtUtc,
    required this.risk,
    required this.confirmationRequired,
    required this.safeUndoAvailable,
  });

  final int schemaVersion;
  final String id;
  final HavenActionSource source;
  final HavenActionKind kind;
  final HavenActionArguments arguments;
  final String interpretation;
  final String effect;
  final String stateToken;
  final DateTime createdAtUtc;
  final DateTime expiresAtUtc;
  final HavenActionRisk risk;
  final bool confirmationRequired;
  final bool safeUndoAvailable;

  String get confirmationFingerprint => <Object>[
    schemaVersion,
    id,
    source.name,
    kind.name,
    arguments.fingerprint,
    interpretation,
    effect,
    stateToken,
    createdAtUtc.toIso8601String(),
    expiresAtUtc.toIso8601String(),
    risk.name,
    confirmationRequired,
    safeUndoAvailable,
  ].join('~');
}

class HavenActionConfirmation {
  const HavenActionConfirmation({
    required this.proposalId,
    required this.proposalFingerprint,
    required this.confirmedAtUtc,
  });

  factory HavenActionConfirmation.forProposal(
    HavenActionProposal proposal, {
    DateTime? confirmedAtUtc,
  }) => HavenActionConfirmation(
    proposalId: proposal.id,
    proposalFingerprint: proposal.confirmationFingerprint,
    confirmedAtUtc: (confirmedAtUtc ?? DateTime.now()).toUtc(),
  );

  final String proposalId;
  final String proposalFingerprint;
  final DateTime confirmedAtUtc;
}

class HavenActionInterpretation {
  const HavenActionInterpretation._({
    required this.status,
    required this.message,
    this.proposal,
  });

  const HavenActionInterpretation.proposed(HavenActionProposal proposal)
    : this._(
        status: HavenActionInterpretationStatus.proposed,
        message: '',
        proposal: proposal,
      );

  const HavenActionInterpretation.rejected(
    HavenActionInterpretationStatus status,
    String message,
  ) : this._(status: status, message: message);

  final HavenActionInterpretationStatus status;
  final String message;
  final HavenActionProposal? proposal;

  bool get hasProposal => proposal != null;
}

class HavenActionReceipt {
  const HavenActionReceipt({
    required this.proposalId,
    required this.kind,
    required this.outcome,
    required this.reason,
    required this.occurredAtUtc,
    required this.resultingStateToken,
  });

  final String proposalId;
  final HavenActionKind kind;
  final HavenActionOutcome outcome;
  final HavenActionReason reason;
  final DateTime occurredAtUtc;
  final String resultingStateToken;
}

class HavenActionResult {
  const HavenActionResult({required this.receipt, required this.message});

  final HavenActionReceipt receipt;
  final String message;

  bool get executed => receipt.outcome == HavenActionOutcome.executed;
}
