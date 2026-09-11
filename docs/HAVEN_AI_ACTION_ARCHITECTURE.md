# Haven AI and Action Architecture

Status: Phase 210 typed runtime, Phase 213 safe voice runtime, and Phase 215H
text-free Local-Coach bridge implemented; Phases 216A and 216B add the local
adaptive preview and isolated review foundations.

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
without expanding the speech allowlist. The free-text interpreter accepts only
`typed` and `voiceTranscript` sources. `localCoach` remains rejected as
proposal authority, and an unreviewed system-intent draft is never accepted as
a proposal. Phase 217B separately permits only its exact in-app-reviewed
`systemIntent` proposal shape.
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

## Phase 215F completion-to-Journey continuity

Phase 215F adds a read-only explanation between the exact current completed
Focus attempt and the existing cumulative Haven Journey. The connection is not
a new Journey owner. `HavenJourneyService` remains responsible for deriving a
lantern, campsite, cabin, garden, or sanctuary solely from the timer's existing
cumulative completed-Focus count.

The service accepts the current `FocusCompletionIdentity`, bounded text-free
focus events, and the already-derived `HavenJourneyState`. It requires that
identity to belong to the newest event and appear exactly once. It also
re-derives the current place, headline, and detail from the supplied cumulative
count. Empty, stale, duplicate, zero-count, unresolved-loop, or inconsistent
evidence fails closed and produces no card.

For valid evidence, the service derives the immediately previous place from
`supportingSessionCount - 1`. If the place is unchanged, the card explains that
this completion is kept equally inside the current Haven. If the existing
threshold was crossed, it names only the newly current place. Both outcomes
are informational; neither adds a milestone, adapts the timer, changes a task,
or grants Journey mutation authority.

`HavenJourneyCompletionConnection` contains only the text-free completion
identity, previous and current place enums, connection kind, and explanatory
copy. It contains no task title, queue ID, reflection, transcript, authored
content, account data, score, or new persisted state. The card has no button,
network, coaching, timer, or queue surface and appears only after a pending
linked-task outcome is settled. It says **This advisory changed nothing
automatically** and that Journey remains private, cumulative, and free of
scores or streak pressure.

## Phase 215H text-free Local-Coach context

Phase 215H connects the current Haven Loop boundary to the deterministic Local
Coach without giving coaching a new data store or action path. The
`HavenLoopCoachContextService` accepts the already-derived Loop, timer,
reflection, Rhythm, Forecast, and Journey boundaries. It emits nothing until
the owners are initialized and agree on one valid Focus moment.

For a completed session, the exact newest `FocusCompletionIdentity` must appear
once in bounded text-free event history. The event's saved fit must match the
current timer fit, and any supplied Rhythm, Forecast, or Journey connection
must bind to the same completion. For a Smart Reset moment, the current linked
selection must still exist and the timer must currently offer recovery. A
stale, duplicate, mismatched, unresolved, non-Focus, or between-session input
fails closed.

The resulting `HavenLoopCoachContext` contains only:

- one allowlisted Loop-moment enum;
- whether an unchanged task link exists;
- the existing text-free completion identity when applicable;
- the bounded session-fit enum when applicable; and
- matching Rhythm, Forecast, and Journey connection-kind enums.

It contains no task title, queue identifier, journal text, mood label,
transcript, conversation, account value, explanatory strings, persistence
format, network method, or mutation method. It is rebuilt ephemerally and is
never saved. `CoachingContext.toPromptData()` deliberately omits it, its
presence forces `CoachingService` to select the deterministic local responder,
and the production timer does not attach it while enhanced coaching is
selected.

The existing explicit **Focus Coach** tap remains the entry permission. Inside
that sheet, one read-only card discloses the exact current Loop moment and the
matching bounded connections using only already-reviewed catalog messages.
The reviewed localized **What should I do next?** prompt can produce a
deterministic response for that moment in every active UI locale. The card and
response have no controls and cannot complete a task, save a reflection,
select Smart Reset, start or adapt a timer, schedule work, or create a Haven
action proposal. Every state change remains with the person and the existing
owning service.

## Phase 216A text-free adaptive preview

Phase 216A adds one deterministic `AdaptiveFocusService` behind an explicit
request boundary. It combines only the current focus and break choices supplied
by a future review surface, bounded `FocusEvent` values, the enum/count output
of Haven Rhythm, and an already-qualified Focus Forecast window. It never reads
the headline, detail, or evidence prose carried by those presentation models.

The resulting `AdaptiveFocusSuggestion` contains only bounded numbers,
booleans, enums, and an optional `FocusForecastWindow`. It contains no task or
queue value, journal or reflection text, mood, coach message, transcript,
account value, localized prose, persistence format, network method, or action
method. It is rebuilt on demand and has no timer or scheduling authority.

Precedence is deliberately conservative:

1. An explicit **keep current** choice returns the supplied focus and break
   values unchanged and does not claim to use learned pace evidence.
2. Two recovery outcomes among the newest three meaningful events lead before
   a growth signal and can only shorten or retain focus while preserving or
   increasing recovery time.
3. The newest completed **Too much** reflection can only move one bounded step
   gentler. **About right** retains the current choice.
4. One **Could do more** reflection is insufficient to lengthen a session. It
   requires at least three matching Rhythm signals and still permits only one
   bounded step.
5. A Forecast window requires the existing minimum of six completed signals.
   It adds optional timing context but cannot alter focus or break duration.

The Riverpod family requires the caller to supply the current values and the
explicit keep-current flag. There is no default adaptive command and no
production UI consumes the preview in Phase 216A. A later presentation phase
must use reviewed localized copy, disclose the contributing bounded signals,
and delegate any accepted duration to the existing `TimerService`. The engine
cannot start, pause, reset, resize, or complete a timer; schedule work; write a
calendar; create a Haven action proposal; or invoke local or remote coaching.

## Phase 216B isolated adaptive review

Phase 216B adds a presentation and settlement foundation without opening the
production timer boundary. `AdaptiveFocusReviewService.beginReview()` issues
one opaque, in-memory ticket for one exact `AdaptiveFocusSuggestion`. Beginning
a newer review supersedes the older ticket. Settlement consumes the ticket
before rechecking the complete suggestion and the current focus and break
values that the future caller reads from the timer owner. A stale, replayed,
superseded, mismatched, or owner-changed review returns no decision. An
unchanged preview cannot authorize acceptance.

An explicit **keep current** settlement returns only the reviewed current
values and no delegation authority. An explicit **accept suggestion**
settlement can return the exact reviewed suggested values, but the result is
still not an execution command. It is never persisted, and Phase 216B has no
coordinator that can pass it to `TimerService`. A later integration must
revalidate current owner state at the delegation boundary and must use a
timer-owned API instead of duplicating timer storage or mutation.

`AdaptiveFocusReviewCard` is an isolated accessible view with two vertically
stacked, one-shot actions. It accepts one complete `AdaptiveFocusReviewCopy`
from its caller and performs no localization, interpolation, or sentence
assembly itself. That contract prevents test fixture copy or a partially
translated phrase from silently becoming production UI. The summary is exposed
as one semantic container while both choices remain separate semantic buttons;
the layout is covered at narrow width and large text.

No production file consumes the card in Phase 216B, and no ARB catalog changes
are included.
The widget and settlement service import no `TimerService`, localization,
persistence, network, or AI owner. Therefore this phase cannot start, resize,
pause, reset, or complete a timer; schedule work; write a calendar; execute a
Haven action; call local or remote AI; or change any account or external state.

## Phase 216C owner-revalidated adaptive delegation

Phase 216C adds the missing local coordinator while leaving production
presentation closed. `AdaptiveFocusDelegationService.beginReview()` returns an
opaque `AdaptiveFocusOwnerReviewTicket` only when the authoritative
`TimerService` is on an untouched, stopped, incomplete Focus session with no
pending resume or active attempt. Its current Focus and short-break defaults
must be whole minutes and must exactly match the suggestion under review.

The owner ticket embeds the existing one-use review ticket and adds its own
generation. A new valid review supersedes an older one. Settlement consumes the
owner generation before rechecking the latest complete suggestion, live timer
readiness, and both live defaults. Keep-current produces a text-free
`keptCurrent` result and performs no mutation. Acceptance can proceed only for
one changed, in-range pair settled by the exact embedded review.

`TimerService.applyReviewedAdaptiveDurations()` is the sole new mutation
boundary. It independently verifies the expected Focus and short-break
defaults, the completely ready Focus state, the supported duration bounds, and
that at least one value changes. It then updates both saved defaults and the
ready Focus countdown atomically, emits one state notification, and persists
through the timer's existing private storage. It never selects a session or
starts, pauses, resets, resumes, or completes one. A stale or invalid request
changes neither duration.

The owner ticket, review decision, and delegation result remain ephemeral and
text-free. The coordinator imports no localization, persistence, network, AI,
calendar, queue, task, or Haven-action owner. No production screen consumes it
in Phase 216C, and no ARB catalog changes are included. Reviewed presentation
copy and a deliberate production placement remain required before a person can
use the adaptive review.

## Phase 216D reviewed production adapter

Phase 216D carries the complete reviewed presentation into production without
weakening the timer-owner boundary. The seventeen source messages remain locked
in `localization/proposals/app_en_adaptive_focus_review.arb` and are present in
all seventeen Flutter catalogs: English, fifteen independently reviewed
languages, and the mechanical base Portuguese fallback derived from `pt-BR`.

The proposal contains complete gentler and room-to-grow headings, current and
suggested duration lines, separate recovery/reflection/Rhythm explanations,
optional Forecast context, the local text-free privacy boundary, a no-change
and no-start disclosure, one complete semantic summary, separate keep and use
actions, and applied, kept, and stale-state outcomes. Placeholder names and
types are explicit so every language can reorder them without fragment-based
sentence assembly.

The reviewed production adapter may appear immediately after Focus Forecast
only while the authoritative timer is a fresh, stopped,
incomplete Focus session and the exact suggestion receives a new
`AdaptiveFocusOwnerReviewTicket`. Losing eligibility removes the card and
invalidates its ticket. Keep-current changes nothing; use-suggestion must still
pass the Phase 216C live-state checks and can only persist future Focus and
short-break defaults while leaving the timer stopped.

The reviewed production adapter adds no task, journal, reflection, coaching,
transcript, account, calendar, or reviewer data. It may request only the exact
reviewed future defaults from the timer owner; it grants no timer-start, queue,
calendar, Haven Action, local-AI, remote-AI, network, deployment, publication,
or external authority.

## Phase 217A closed system-intent preparation

Phase 217A reserves a platform-neutral entry contract without opening an
execution path. `HavenSystemIntentRequest` contains only schema version, one
bounded opaque invocation ID, and one of five typed requests: read timer
status, start a Focus timer, pause, resume, or open Focus Queue. It contains no
utterance, transcript, task title, coaching history, journal, reflection,
account value, localized copy, or arbitrary private parameter.

`HavenSystemIntentService` consumes a valid invocation ID once within its
bounded ephemeral lifetime and emits one `HavenSystemIntentDraft` expressed
through existing `HavenActionKind` and `HavenActionArguments` values. The draft
is not a `HavenActionProposal`. It has no current-state token, proposal
identifier, expiry, explanation, confirmation, or executor reference; it
declares that in-app review is required and that it cannot execute.

The Phase 217A service does not import the engine, timer, queue, persistence,
network, AI, or platform owners. No Siri/App Intent, Shortcut, Android App
Action, deep link, dependency, permission, manifest, provider, or production UI
is registered in Phase 217A. A reviewed bridge must bind the draft to fresh app
state, complete localized explanation, exact confirmation policy, and the
existing Haven Action Engine before any platform registration may be added.
The replay set is bounded and fails closed at capacity instead of evicting an
older invocation.

## Phase 217B reviewed system-intent proposal bridge

`HavenSystemIntentReviewService` is the only bridge from a Phase 217A draft to
the Haven Action Engine. It verifies the exact intent/action/argument pairing,
consumes the bounded opaque invocation ID once, asks the engine for a fresh
read-only owner snapshot, and builds one two-minute proposal with localized
interpretation and effect copy already present in every production catalog.
The proposal itself remains private to the bridge; presentation receives one
opaque `HavenSystemIntentReview` with only display-safe action metadata.

Every system-intent proposal requires an exact confirmation even when the
route is informational or navigational. Calling `confirm()` consumes the one
active review before `HavenActionEngine` revalidates proposal expiry, the live
timer/queue state token, engine replay, and action availability. A changed
owner state rejects the proposal, a second settlement fails, a newer review
supersedes its predecessor, dismissal is final, and an unavailable invocation
cannot be replayed after conditions change. The bridge remembers at most 128
invocations and refuses new work at capacity without reopening an older ID.

The policy accepts `HavenActionSource.systemIntent` only for the exact five
reviewed shapes: status with no arguments, Focus-only start, argument-free
pause or resume, and Focus Queue navigation. Each must carry the matching risk,
complete trimmed localized copy, safe-undo marker, exact-confirmation marker,
and the fixed two-minute lifetime. Added time, queue edits, break starts, other
surfaces, incomplete copy, missing confirmation, or extended lifetime fail
closed as invalid proposals.

The bridge holds no timer, queue, persistence, provider, network, AI, or native
platform owner. No production screen or provider consumes it in Phase 217B,
and no Siri/App Intent, Shortcut, Android App Action, permission, dependency,
deep link, manifest, or external service is added. Native registration and
production presentation remain separate review and release gates.

## Phase 217C isolated system-intent review presentation

`HavenSystemIntentReviewCard` is a localization-neutral presentation for one
opaque Phase 217B capability. It receives only the exact
`HavenSystemIntentReview`, one complete `HavenSystemIntentReviewCopy`, and
separate dismiss and confirm callbacks. The review exposes its already-
localized interpretation and effect while its underlying proposal remains
private to `HavenSystemIntentReviewService`.

The copy object requires complete source, privacy, freshness, confirmation,
risk, semantic-summary, and action strings. The widget performs no
localization, interpolation, or sentence assembly, so a later production
adapter cannot silently combine a partially translated source label with an
otherwise reviewed proposal. One live semantic summary describes the review;
dismiss and confirm remain separate semantic buttons and neither is inferred
from a gesture, timeout, system response, or spoken acknowledgement.

Both actions are one-shot. The card disables dismiss and confirm together
before passing the same opaque review to the chosen callback. A different
review identity may reset the presentation, but the widget cannot prepare,
inspect, confirm, dismiss, or execute the private proposal. Replay, expiry,
live-state revalidation, and settlement remain exclusively with the Phase 217B
bridge and Haven Action Engine.

The presentation imports no localization, engine, timer, queue, persistence,
provider, network, AI, or native platform owner. No production screen or
provider consumes it in Phase 217C, no source-specific runtime catalog copy is
added, and no Siri/App Intent, Shortcut, Android App Action, permission,
dependency, deep link, manifest, or external service is registered. Copy
review, production hosting, and native registration remain separate gates.

## Phase 217D locked system-assistant production copy

Phase 217D isolates eleven complete English messages in
`localization/proposals/app_en_system_assistant_review.arb`. The proposal
covers the source and no-action disclosure, exact text-free privacy boundary,
two-minute freshness and stale-owner warning, mandatory visual confirmation,
separate informational and reversible-control risk explanations, a complete
semantic summary, and distinct dismiss and confirm labels.

The semantic summary has exactly three string placeholders:
`interpretation`, `effect`, and `risk`. Those values already come from the
reviewed service and risk mapping. Each language may reorder them only inside
one complete reviewed message; neither the card nor a future production host
may concatenate translated sentence fragments. The visible Confirm action
label exactly matches the confirmation disclosure.

The proposal remains the immutable review source outside `lib/l10n`. It
contains no transcript, task, journal, reflection,
coaching, account, reviewer, device, or provider data. A later incremental
review must produce one complete independent approval for each of the fifteen
non-English production languages; base `pt` may be derived only from approved
`pt-BR`.

After all fifteen independent reviews pass, Phase 217D derives base `pt` only
from approved `pt-BR`, merges the eleven complete messages into all seventeen
runtime catalogs, and adds one app-level production host. Its memory-only inbox
accepts only a typed `HavenSystemIntentRequest`, rejects a second pending
request, and has no persistence or native producer. The host prepares one
opaque review, removes it on dismissal, confirmation, supersession, expiry, or
owner-state change, and delegates confirmation only to the issuing
`HavenSystemIntentReviewService` and existing Haven Action Engine.

Phase 217D adds no native adapter, Siri/App Intent, Shortcut, Android App
Action, permission, dependency, deep link, manifest, entitlement, persistence,
provider, network, or AI path. Copy approval and production hosting cannot
register a platform request or bypass exact in-app confirmation. Each native
adapter remains a separate later gate.

## Phase 217E private Apple system-assistant ingress

Phase 217E installs one Apple-only method-channel transport and lifecycle host
without registering a public system action. Swift mirrors exactly the five
Phase 217A routes and constructs only a three-field payload: schema version,
bounded opaque invocation ID, and route kind. Dart independently validates the
same exact shape before the existing memory-only inbox may acknowledge it.
Unknown fields, raw text, invalid identifiers, unsupported routes, overlapping
delivery polls, and a second pending request fail closed.

The native pending store has one process-memory slot and no persistence API.
It clears only when Flutter returns `true` for the matching invocation ID. A
missing engine, unavailable channel, malformed payload, occupied app inbox, or
negative acknowledgement retains the native request only for another
foreground attempt in that same process; process termination discards it.

The Apple adapter cannot import or call a timer, queue, review service, or Haven
Action Engine. Its successful delivery stops at `HavenSystemIntentInbox`.
Phase 217A preparation, Phase 217B state binding and policy, the Phase 217C
one-shot card, and the reviewed Phase 217D production host remain the only path
to an explicitly confirmed owner mutation.

No App Intents import or conformance, App Shortcut provider, Siri entitlement,
usage description, deep link, native public copy, dependency, or Android
registration is added. Public Apple discovery and invocation must wait for a
separate complete-copy and fifteen-language review, availability-gated iOS
registration, real-device Siri/Shortcuts and VoiceOver acceptance, signed
release builds, store review, and explicit distribution approval.

## Phase 217F locked Apple-native assistant copy

Phase 217F isolates twenty-eight complete English messages for a future Apple
native discovery surface. The set contains one collection title, one discovery
description, privacy and no-parameter summaries, one review instruction, five
route titles, five route descriptions, five invocation phrases, six truthful
handoff or failure outcomes, and two accessibility labels. Invocation phrases
carry only one `applicationName` string placeholder. There is no duration,
task, queue-item, transcript, utterance, account, or other free-form input.

Every route asks to prepare or review a request. Native handoff says only that
FocusHaven must be opened for review and that nothing has happened yet. The
copy never converts submission, Siri dialogue, a timeout, a cancellation, or a
system acknowledgement into confirmation or successful execution.

Fifteen independent fluent reviews are required. Base Portuguese may be
derived only from the completely approved Brazilian Portuguese delta. The
existing Flutter runtime-catalog digests are freshness locks, not destinations:
the Apple-native messages must never enter Flutter ARBs. A later integration
may map approved values into an Apple string catalog while preserving exact
keys and placeholders.

Phase 217F adds no Runner source, native accessor, Apple string catalog, App
Intent, App Shortcut provider, Siri entitlement, dependency, permission,
platform registration, production consumer, or execution path. Public Apple
registration, real-device acceptance, signed builds, store review, and
distribution remain separately reviewed and authorized. Android stays a
separate adapter and release gate, and copy approval alone grants no App Intent,
Shortcut, Siri, Android, execution, publication, or distribution authority.

### Phase 217F reviewed Apple-native catalog integration

After all fifteen reviews pass, the isolated integration maps the twenty-eight
approved keys into one Runner-local Apple String Catalog. English and fifteen
reviewed locales are direct inputs; base Portuguese is an exact derivation from
approved Brazilian Portuguese. The only format parameter is one `%@`
application-name token in each of the five invocation phrases. A typed Swift
accessor validates that shape and maps the existing five text-free routes to
their title, description, and phrase keys.

The catalog and accessor are copy authority, not request authority. They do not
import App Intents, conform to `AppIntent`, publish shortcuts, call the Phase
217E store, cross the Flutter channel, or touch timer, queue, confirmation, or
execution owners. The Flutter localization catalogs remain unchanged. Public
registration, native assistant behavior, signed release validation, real-device
accessibility checks, store review, and distribution remain later gates.

## Phase 217G availability-gated Apple registration

Phase 217G registers exactly five parameter-free Apple intents and five App
Shortcuts on iOS 16 and later. The app continues to target iOS 15, and the
registration refresh is protected by an availability check. Each shortcut
phrase is derived from the reviewed Phase 217F phrase in all seventeen Apple
catalog locales, replacing the one native `%@` application-name format token
with the one App Shortcuts `${applicationName}` token. No untranslated or
independently authored shortcut phrase is admitted.

An App Intent may choose only one existing `HavenSystemAssistantAppleRoute` and
generate one bounded opaque invocation ID. The submission seam first verifies
that the route title, description, phrase, and all three possible result
messages exist in the reviewed catalog. It then validates the exact Phase 217E
request and attempts to place it in that phase's single process-memory slot.
Missing copy, an invalid ID, or an occupied slot fails closed without replacing
the pending request.

Every App Intent requires authentication and opens FocusHaven for the existing in-app review.
The only native results are ready for review, a review already
pending, or unavailable. The native layer never confirms or executes an action,
and its results never claim that timer status was read, a timer changed, Focus
Queue opened, or a Haven Action ran. Native submission and Siri dialogue are not
the in-app Confirm action. The existing Phase 217D host, Phase 217B fresh-state
review service, and Haven Action Engine remain the only path to settlement.

The registration source contains no parameter, transcript, utterance, duration,
task, queue item, timer or queue owner, review service, engine, persistence,
network, or AI dependency. It adds no Siri entitlement or usage description,
deep link, Android manifest entry, or third-party dependency. Real-device Siri
and Shortcuts behavior, cold and warm launch, VoiceOver, large text, all-language
device review, signed release builds, privacy/store disclosure, candidate
validation, and distribution remain separately authorized release gates.
Android App Actions remain independent.
