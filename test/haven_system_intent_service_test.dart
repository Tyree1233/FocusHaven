import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/models/haven_action.dart';
import 'package:focushaven/models/haven_system_intent.dart';
import 'package:focushaven/services/haven_action_policy.dart';
import 'package:focushaven/services/haven_system_intent_service.dart';

void main() {
  HavenSystemIntentRequest request(
    HavenSystemIntentKind kind, {
    String invocationId = 'intent-1',
    int schemaVersion = 1,
  }) => HavenSystemIntentRequest(
    schemaVersion: schemaVersion,
    invocationId: invocationId,
    kind: kind,
  );

  test('prepares only the complete five-intent structured allowlist', () {
    final expected =
        <
          HavenSystemIntentKind,
          ({
            HavenActionKind action,
            HavenSessionKind? session,
            HavenActionSurface? surface,
          })
        >{
          HavenSystemIntentKind.readTimerStatus: (
            action: HavenActionKind.readTimerStatus,
            session: null,
            surface: null,
          ),
          HavenSystemIntentKind.startFocusTimer: (
            action: HavenActionKind.startTimer,
            session: HavenSessionKind.focus,
            surface: null,
          ),
          HavenSystemIntentKind.pauseTimer: (
            action: HavenActionKind.pauseTimer,
            session: null,
            surface: null,
          ),
          HavenSystemIntentKind.resumeTimer: (
            action: HavenActionKind.resumeTimer,
            session: null,
            surface: null,
          ),
          HavenSystemIntentKind.openFocusQueue: (
            action: HavenActionKind.openSurface,
            session: null,
            surface: HavenActionSurface.focusQueue,
          ),
        };
    expect(HavenSystemIntentKind.values, hasLength(5));

    for (final entry in expected.entries) {
      final result = HavenSystemIntentService().prepare(
        request(entry.key, invocationId: 'intent-${entry.key.name}'),
      );
      final draft = result.draft!;

      expect(result.isPrepared, isTrue);
      expect(result.rejectionReason, HavenSystemIntentRejectionReason.none);
      expect(draft.intentKind, entry.key);
      expect(draft.actionKind, entry.value.action);
      expect(draft.arguments.session, entry.value.session);
      expect(draft.arguments.surface, entry.value.surface);
      expect(draft.arguments.durationSeconds, isNull);
      expect(draft.arguments.queueTitle, isNull);
      expect(draft.source, HavenActionSource.systemIntent);
      expect(draft.requiresInAppReview, isTrue);
      expect(draft.canExecute, isFalse);
    }
  });

  test('rejects unsupported schemas and malformed opaque identifiers', () {
    final invalidRequests = <HavenSystemIntentRequest>[
      request(HavenSystemIntentKind.readTimerStatus, schemaVersion: 0),
      request(HavenSystemIntentKind.readTimerStatus, invocationId: ''),
      request(HavenSystemIntentKind.readTimerStatus, invocationId: ' space'),
      request(
        HavenSystemIntentKind.readTimerStatus,
        invocationId: 'private text',
      ),
      request(
        HavenSystemIntentKind.readTimerStatus,
        invocationId: List<String>.filled(129, 'a').join(),
      ),
    ];

    for (final invalid in invalidRequests) {
      final result = HavenSystemIntentService().prepare(invalid);
      expect(result.isPrepared, isFalse);
      expect(result.status, HavenSystemIntentPreparationStatus.invalid);
      expect(result.draft, isNull);
    }
  });

  test('one opaque invocation can prepare at most one ephemeral draft', () {
    final service = HavenSystemIntentService();
    final first = service.prepare(
      request(HavenSystemIntentKind.pauseTimer, invocationId: 'same-1'),
    );
    final replay = service.prepare(
      request(HavenSystemIntentKind.resumeTimer, invocationId: 'same-1'),
    );

    expect(first.isPrepared, isTrue);
    expect(replay.isPrepared, isFalse);
    expect(replay.status, HavenSystemIntentPreparationStatus.replayed);
    expect(
      replay.rejectionReason,
      HavenSystemIntentRejectionReason.duplicateInvocation,
    );
    expect(replay.draft, isNull);
  });

  test('bounded replay memory fails closed when capacity is reached', () {
    final service = HavenSystemIntentService();
    for (var index = 0; index < 128; index += 1) {
      expect(
        service
            .prepare(
              request(
                HavenSystemIntentKind.readTimerStatus,
                invocationId: 'bounded-$index',
              ),
            )
            .isPrepared,
        isTrue,
      );
    }

    final overflow = service.prepare(
      request(
        HavenSystemIntentKind.readTimerStatus,
        invocationId: 'bounded-overflow',
      ),
    );
    final oldestReplay = service.prepare(
      request(HavenSystemIntentKind.readTimerStatus, invocationId: 'bounded-0'),
    );

    expect(overflow.status, HavenSystemIntentPreparationStatus.unavailable);
    expect(
      overflow.rejectionReason,
      HavenSystemIntentRejectionReason.capacityReached,
    );
    expect(oldestReplay.status, HavenSystemIntentPreparationStatus.replayed);
    expect(oldestReplay.draft, isNull);
  });

  test('prepared system intent remains rejected by the action policy', () {
    final now = DateTime.utc(2026, 9, 9, 12);
    const state = HavenActionState(
      session: HavenSessionKind.focus,
      activity: HavenTimerActivity.ready,
      secondsRemaining: 1500,
      totalSessionSeconds: 1500,
      queueRevision: 0,
      canStartHavenPlan: true,
      canOfferSmartReset: false,
    );
    final proposal = HavenActionProposal(
      schemaVersion: 1,
      id: 'manually-forged-system-intent',
      source: HavenActionSource.systemIntent,
      kind: HavenActionKind.readTimerStatus,
      arguments: const HavenActionArguments.none(),
      interpretation: 'not reviewed',
      effect: 'not reviewed',
      stateToken: state.token,
      createdAtUtc: now,
      expiresAtUtc: now.add(const Duration(minutes: 2)),
      risk: HavenActionRisk.informational,
      confirmationRequired: false,
      safeUndoAvailable: true,
    );

    final decision = HavenActionPolicy().evaluate(
      proposal: proposal,
      state: state,
      nowUtc: now,
    );

    expect(decision.allowed, isFalse);
    expect(decision.reason, HavenActionReason.invalidProposal);
  });
}
