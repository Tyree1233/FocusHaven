# Haven AI and Action Architecture

Status: Phase 210 typed runtime and Phase 213 safe voice runtime implemented

The Haven Action Engine is the single policy boundary between a human
request and an existing FocusHaven service. It exists so typed input, reviewed
voice transcripts, local coaching, optional enhanced coaching, widgets,
watches, and system assistants cannot invent different authorization rules.

Its governing sequence is:

> **Understand -> Propose -> Explain -> Confirm -> Execute**

Understanding never grants execution authority. Remote AI may help draft or
interpret a proposal, but it cannot call a timer, queue, calendar, account,
purchase, permission, Firebase, or deployment API directly.

## Boundary and ownership

```text
Typed input / editable voice transcript
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

## Phase 210 and Phase 213 runtime boundary

The typed Phase 210 implementation lives in separate, testable layers:

- `lib/models/haven_action.dart` defines versioned proposals, typed arguments,
  state preconditions, exact confirmations, and text-free receipts;
- `lib/services/haven_action_interpreter.dart` recognizes the initial bounded
  grammar locally and rejects ambiguous, unsupported, protected, or oversized
  input without creating a proposal;
- `lib/services/haven_action_policy.dart` independently rechecks freshness,
  current state, availability, argument bounds, and confirmation policy;
- `lib/services/haven_action_engine.dart` prevents proposal replay and delegates
  accepted operations to `TimerService` or `FocusQueueService`;
- `lib/widgets/haven_action_sheet.dart` provides a visible and accessible
  review announcement, an explicit **Change request** path, keyboard review,
  an informed tap-to-talk transcript path, and an exact confirmation step for
  saved queue edits.

The timer screen exposes the surface as **Haven actions**. Typed requests remain
fully available. After the person accepts the voice disclosure, the same
bounded transcription service used by Voice-to-Coach can fill an editable
draft. Speech creates neither a proposal nor an execution: the person must stop
or finish listening, tap **Review action**, inspect the proposal, and then use
the visual **Run reviewed action** or **Confirm exact action** control. No
remote model is called. Opening Queue, Haven Plan, Smart Reset, local Coach, or
settings goes through the existing screens. Protected actions remain
unavailable from this engine.

Phase 213 safe voice runtime implemented the `voiceTranscript` provenance
without expanding the allowlist. The interpreter and policy accept only
`typed` and `voiceTranscript` sources. `localCoach` and `systemIntent` remain
model values for future design work but are rejected as proposal authority.
Editing a voice draft does not erase its voice provenance, and discarding voice
restores the exact pre-listening typed draft.

## Proposal contract

A `HavenActionProposal` is versioned and contains only the minimum
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

## Current typed-and-voice allowlist

The shared engine stays deliberately small:

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

## Phase 210 typed acceptance contract

Phase 210 is complete only when:

- typed input exercises the engine without a microphone or remote model;
- proposal parsing, policy, confirmation, and execution are separate testable
  components;
- all mutations route through existing services;
- unsupported and ambiguous requests make no state change;
- stale and replayed proposals are rejected;
- the review surface announces the exact interpretation, effect, risk, and
  available choices as one live region;
- changing a request preserves the typed text, mutates nothing, and returns
  keyboard focus to the input;
- every execution attempt settles the visible proposal, including a stale
  rejection, so a consumed proposal cannot remain available for another tap;
- widget, watch, and native-surface command authorization remains unchanged;
- the current store privacy boundary remains accurate.

The repository implementation and focused tests satisfy these criteria.

## Phase 213 safe voice acceptance contract

Phase 213 is complete in source only when:

- an informed tap is required before the shared recognizer starts;
- the transcript remains editable and creates no proposal while listening;
- **Review action** is a distinct user action after transcription;
- a reviewed voice proposal displays its source and still requires the existing
  visual run or exact-confirmation control;
- typed and voice proposals share the same grammar, state token, expiry,
  argument bounds, protected-action rejection, and replay policy;
- local Coach output and system-intent text cannot create proposals;
- discarding restores the exact typed draft and closing or backgrounding ends
  listening through the shared transcription lifecycle;
- no remote AI, raw-audio persistence, backend call, new permission, or direct
  service path is introduced.

The Phase 213 source and focused tests now satisfy these criteria. Fresh native
builds, real-device voice-command acceptance, accessibility checks, and final
store disclosures remain release work; this source milestone is not a claim
that the feature is present in an already validated store candidate.

## Phase 214A local planner foundation

Phase 214A introduces a planner proposal, not an autonomous agent. The
deterministic `HavenPlannerService` receives only the goal, available minutes,
and preferred focus size the person explicitly enters. It makes no network
request, persists no goal or proposal, reads no calendar, and changes no timer
or queue state while drafting. Its versioned proposal discloses:

- the exact normalized inputs;
- bounded assumptions and an explicit uncertainty level and explanation;
- the local data that could be affected;
- possible Focus Queue tasks;
- one informational session-size suggestion; and
- one informational, calendar-free free-time suggestion.

The `HavenPlannerSheet` requires every item to be settled independently with
**Accept**, **Edit** where supported, or **Reject**. Accepting an informational
suggestion records no state change. Accepted or edited queue tasks are shown
again as one exact list before the person confirms. `HavenPlannerActionService`
then creates one fresh `HavenActionProposal` per reviewed task because each
successful queue insertion changes the queue revision. Every proposal still
passes through `HavenActionInterpreter`, `HavenActionPolicy`, exact
`HavenActionConfirmation`, `HavenActionEngine`, and the owning
`FocusQueueService`. The planner never writes queue storage directly and gains
no timer, calendar, account, purchase, permission, deployment, or store
authority.

The local foundation is intentionally useful without an account, network,
subscription, remote model, new permission, or backend change. A future remote
planner may draft richer possibilities only after a separate disclosure and
opt-in; its output must return to this same item-by-item local review and action
boundary. It cannot convert generated text into automatic execution.

## Phase 215A local Plan-to-Focus loop

Phase 215A connects one reviewed active Focus Queue item to one Focus session
without creating a second task store or an autonomous workflow. The
`HavenLoopService` persists only `havenLoopSelectedQueueItemId`. Task text,
ordering, and completion remain owned by `FocusQueueService`; session type,
intention, countdown, and completion remain owned by `TimerService`.

Selection is explicit. A queue item chosen directly, or an accepted planner
task chosen by its exact ID, may become the current Focus intention. A manual
intention edit deliberately clears that identity link. A rename, removal,
prior completion, session change, or title mismatch also invalidates the link
without altering either owner. This makes stale state fail closed rather than
guessing which work the person meant.

A completed linked Focus session is not proof that the task itself is done.
The timer screen therefore exposes exactly two visible outcomes and withholds
the next-session control until one is chosen:

- **Mark task complete** delegates the exact item ID to the existing queue
  toggle, then consumes the link.
- **Keep for later** leaves the queue item active and consumes the link.

Both outcomes clear only the timer intention after the explicit decision. The
link cannot complete a task on elapsed time, replay a consumed decision, or
operate on a changed item. It stores no goal, task text, transcript,
reflection, coaching content, calendar data, or raw session history and adds no
network call, remote AI, permission, account requirement, backend, or
deployment. Restoration also fails closed: a completed timer withholds its
next-session control until the saved-link check finishes, so a cold-start race
cannot bypass a pending task decision. Later Phase 215 connections must remain
independently reviewable and preserve these service-ownership and fail-closed
rules.

## Phase 215B task-decision-to-reflection connection

Phase 215B adds one bounded connection after Phase 215A without creating a new
task store, reflection store, or autonomous workflow. When a completed Focus
session still owns an exact linked queue-item decision, the timer screen shows
only **Mark task complete** and **Keep for later**. The existing text-free
reflection remains hidden, and the next-session control remains withheld,
until that queue decision settles through `HavenLoopService`.

After either exact outcome succeeds, `FocusSessionReflectionCard` offers the
existing optional session-fit choices. The person may instead take the break;
that explicit skip stores no reflection value. `TimerService` remains the sole
owner of focus-event history and is the only service that may attach the
bounded fit signal. `HavenLoopService` never receives or stores reflection
state, and `FocusQueueService` never receives it either.

Each visible reflection callback closes over an immutable
`FocusCompletionIdentity` derived from the exact completed event. Before a fit
can be written, `TimerService` requires that identity to match the current
completed Focus event. A stale callback, replay after the next session, or
callback from an earlier completion therefore fails closed instead of
rewriting later history. Repeating the same accepted fit is idempotent and does
not create another event revision.

This connection copies no task text or reflection content and adds no new
permission, dependency, account requirement, network call, remote AI, backend,
deployment, calendar access, or coaching authority. Rhythm, Forecast, Smart
Reset, Journey, and coaching remain separate later Phase 215 connections.

## Phase 215C reflection-to-Rhythm connection

Phase 215C adds one advisory connection from a saved text-free fit to the
existing local Haven Rhythm engine. `HavenRhythmService` accepts the exact
current `FocusCompletionIdentity` and bounded `FocusEvent` history, then fails
closed unless that identity belongs to the newest event, appears exactly once,
and already owns a session-fit reflection.

The resulting `HavenRhythmReflectionConnection` is ephemeral. It explains one
of three honest states: one reflection is not yet a pattern, repeated
reflections contribute to the current local Rhythm observation, or recent
recovery signals still carry more weight. The timer screen renders this
explanation directly below the existing reflection controls only while the
exact completed Focus session remains current.

The connection persists no second reflection, task text, derived insight,
score, or raw content. It has no button and no execution authority. It never
changes a timer duration, selects a break, accepts a suggested pace, schedules
work, or contacts local or remote coaching. The visible boundary says
**Nothing changed automatically** and keeps the next session as an explicit
user choice. Forecast, Smart Reset, Journey, and coaching remain separate later
Phase 215 connections.

## Phase 215D reflection-to-Forecast connection

Phase 215D adds a second, independent advisory connection from the exact saved
text-free fit to the existing local Focus Forecast. `FocusForecastService`
accepts the exact current `FocusCompletionIdentity` and bounded `FocusEvent`
history, then fails closed unless that identity belongs to the newest event,
appears exactly once, and already owns a session-fit reflection.

The service first rebuilds the ordinary `FocusForecast` without changing any
forecast rule. The resulting ephemeral
`FocusForecastReflectionConnection` explains one of four honest states: one
reflection cannot create a timing pattern, the completion sits inside a
possible window, it sits outside that possible window, or timing remains
flexible. A saved fit adds context to a completion; it is never treated as
proof that a time is good, bad, productive, or guaranteed.

The timer screen renders this explanation after the existing reflection and
Rhythm connection only while the exact completed Focus boundary remains
current. The card has no button and no execution authority. It cannot change
Forecast's minimum evidence or dominance rules, rank a best time, schedule
work, start or adapt a timer, select a break, create a notification, contact
coaching, or read a calendar. It persists no second reflection, task text,
forecast, connection, score, or raw content. The visible boundary says
**Nothing changed automatically** and **A possible window is not a rule**;
current energy, recovery needs, and real-life availability continue to lead.

Smart Reset, Journey, and coaching remain separate later Phase 215
connections.

## Phase 215E linked Smart Reset continuity

Phase 215E connects one interrupted Plan-to-Focus link to the existing Smart
Reset surface without giving recovery any task authority. After the timer
pauses for the existing review sheet, `HavenLoopService` may issue one opaque,
ephemeral `HavenLoopRecoveryTicket`. A ticket exists only when the exact active
queue-item ID still owns the current Focus intention and the timer can offer
Smart Reset. It stores no task title, goal, reflection, transcript, coaching
content, timing history, or second copy of queue state.

The sheet receives only a boolean continuity disclosure, never the queue item
or its text. It explains that the selected item stays linked only while it
remains active and unchanged and that Smart Reset receives no task text. The
person still chooses **Restart smaller**, **Reset without restarting**, or
**Keep this session**. `TimerService` remains the sole owner of those timer
transitions; only the existing explicit restart choice starts a smaller timer.

After the choice, the opaque ticket is consumed exactly once and
`HavenLoopService` rechecks the saved ID against both owners. Rename, removal,
completion, manual intention change, session change, supersession, replay, or
any mismatch returns false and gains no queue mutation authority. A failed
continuity check is disclosed without exposing the task. Ordinary unlinked
Smart Reset remains available. Recovery never completes, reorders, renames, or
removes queue work and adds no persistence key, network call, remote AI,
permission, dependency, backend, deployment, calendar access, or reflection
copy. Journey and coaching remain separate later Phase 215 connections.
