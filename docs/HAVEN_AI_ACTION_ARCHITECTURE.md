# Haven AI and Action Architecture

Status: Phase 209 design contract; not yet a runtime implementation

The Haven Action Engine will be the single policy boundary between a human
request and an existing FocusHaven service. It exists so typed input, future
voice transcripts, local coaching, optional enhanced coaching, widgets,
watches, and system assistants cannot invent different authorization rules.

Its governing sequence is:

> **Understand -> Propose -> Explain -> Confirm -> Execute**

Understanding never grants execution authority. Remote AI may help draft or
interpret a proposal, but it cannot call a timer, queue, calendar, account,
purchase, permission, Firebase, or deployment API directly.

## Boundary and ownership

```text
Typed input / future voice transcript / reviewed system intent
                              |
                              v
                    bounded input adapter
                              |
                              v
          deterministic interpreter (optional AI drafting fallback)
                              |
                              v
                 versioned HavenActionProposal
                              |
                              v
        local policy + current-state + freshness validation
                              |
                  explain / confirm / reject
                              |
                              v
             allowlisted existing service executor
                              |
                              v
                 text-free execution receipt
```

Existing FocusHaven services remain authoritative. The engine proposes a call;
it does not duplicate timer rules, write preferences directly, manufacture
widget commands, or mutate Riverpod state behind a service.

## Proposal contract

A future `HavenActionProposal` should be versioned and contain only the minimum
fields needed to review one proposed action:

- schema version and random proposal ID;
- input source (`typed`, `voiceTranscript`, `localCoach`, `systemIntent`);
- allowlisted action kind;
- bounded, typed arguments;
- short human-readable interpretation and effect;
- current-state token or equivalent precondition;
- creation and expiry boundaries;
- risk class and confirmation requirement;
- whether a safe undo or compensating action exists.

Arbitrary model output, executable code, URLs, provider tool calls, shell
commands, Firebase commands, raw audio, access tokens, and credentials are not
valid proposal fields.

## Risk classes

### Informational

Reads an already-visible local status or opens an explanatory surface. It may
execute after deterministic validation and must not reveal data unavailable to
the current signed-in state.

Examples: explain the current timer, open local coaching, show the queue, or
open Haven Plan.

### Reversible control

Changes an active local timer in a bounded and readily reversible way.
Deterministic commands may execute after the app shows what it understood.

Initial examples: start a ready timer, pause, resume, or add a bounded amount
of time within the existing timer policy.

### Stateful edit

Changes saved local organization or replaces a choice. It requires a visual
proposal and explicit confirmation unless the exact UI action already provides
an equivalent confirmation.

Examples: add a queue item, reorder or replace a queue, accept a Haven Plan,
hold a Haven Window, or change the next session duration.

### Destructive or sensitive

Cannot be completed solely from conversational or voice input. The engine may
navigate to the existing protected UI, but the person must complete its normal
verification and confirmation there.

Examples: reset or discard active work, clear history, delete local data,
delete cloud backup, delete an account, sign out, change authentication,
purchase or restore a subscription, grant a permission, write a calendar
event, or change Focus Shield configuration.

### Operationally forbidden

No in-app AI or voice path may propose or execute developer operations.

Examples: deploy a function or Hosting content, enable App Check enforcement,
modify IAM, change a provider or credential, alter remote configuration, enable
enhanced coaching, deliver a store build, create TestFlight content, or submit
an app for review.

## Initial Phase 210 allowlist

The first typed engine should stay deliberately small:

- read current timer status;
- start a ready focus or break session;
- pause or resume the current session;
- add time using the existing bounded add-time policy;
- open Focus Queue, Haven Plan, Smart Reset, local Focus Coach, or settings;
- draft one queue item for review;
- show an explanation when the request is unavailable in the current state.

Reset, discard, queue replacement, calendar actions, account actions,
permissions, purchases, remote AI enablement, and developer operations are not
part of the first allowlist.

## Interpretation rules

1. Prefer a deterministic local grammar for the initial command set.
2. Normalize synonyms to an allowlisted kind; never convert free text into a
   method name.
3. Reject multiple incompatible actions in one request until the person can
   review them separately.
4. Ask when session type, duration, target, or intent is ambiguous. Never pick
   the most consequential interpretation.
5. Clamp no value silently. Explain the permitted boundary and propose a valid
   alternative.
6. A remote model may draft planning content only after the user chooses the
   enhanced path. Its output returns through the same local parser and policy.
7. If the network, model, entitlement, quota, or attestation is unavailable,
   deterministic local commands and local coaching continue to work.

## Validation and replay safety

Each proposal is valid only for the state it was created against. Before
execution, the engine must independently recheck:

- schema and allowlist membership;
- argument types and bounds;
- current timer or feature state;
- source availability and platform support;
- proposal age and expiration;
- whether the proposal ID was already accepted or rejected;
- whether required confirmation occurred for this exact proposal;
- whether the owning service is already busy or disposed.

A stale, duplicate, unsupported, malformed, or partially confirmed proposal
fails closed and explains that no change occurred. Execution produces one
bounded receipt but never claims success before the owning service confirms it.

## Confirmation design

Confirmation is a semantic step, not a generic “yes” that can accidentally
apply to a newer request. A confirmation binds to the exact proposal ID,
action, arguments, explanation, and state precondition. A changed transcript,
expired timer state, app restart, or replacement proposal invalidates it.

Destructive and sensitive work remains inside its dedicated UI even if a user
says “yes” conversationally. Account deletion continues to require verified
reauthentication and the deployed protected callable; the Action Engine does
not weaken that path.

## Privacy and diagnostics

- Parse locally whenever the allowlisted grammar can do so.
- Do not persist raw input merely to improve the parser.
- Keep execution receipts text-free where practical.
- Never add task, reflection, mood, coaching, or account text to system-focus
  snapshots.
- Diagnostics record stable event categories, not transcripts, credentials,
  private task content, or provider responses.
- Optional enhanced interpretation is a separate, disclosed action and sends
  only the confirmed bounded text needed for that request.

## Phase 210 acceptance contract

Phase 210 is complete only when:

- typed input exercises the engine without a microphone or remote model;
- proposal parsing, policy, confirmation, and execution are separate testable
  components;
- all mutations route through existing services;
- unsupported and ambiguous requests make no state change;
- stale and replayed proposals are rejected;
- widget, watch, and native-surface command authorization remains unchanged;
- the current store privacy boundary remains accurate.
