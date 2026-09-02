# FocusHaven Product Roadmap

Status: living product contract; Phase 215G-B6C3 English Flutter localization extraction is implemented
Roadmap baseline: August 30, 2026
Source baseline: `8b27408` (`Define AI and voice product roadmap`)

This roadmap defines how FocusHaven grows from a private focus timer into a
calm, local-first focus companion. It records what already exists, what has only
a foundation, and what is deliberately still future work. It does not grant a
runtime permission, enable enhanced coaching, deploy a service, alter a store
candidate, or promise a release date.

## Status vocabulary

- **Shipped:** implemented and covered by the current repository's tests.
- **Foundation shipped:** a safe lower-level contract exists, but the complete
  user outcome does not.
- **Partial:** meaningful pieces are available, but the intended experience is
  not yet unified or complete.
- **Planned:** approved product direction with no claim that it currently
  exists in the app.
- **Deferred:** intentionally later because privacy, safety, moderation, cost,
  or operational work must come first.
- **Replaced:** an earlier concept has been superseded by a calmer design.

## Product commitments

Every future phase must preserve these rules:

1. **Local-first usefulness.** Core timer, planning, recovery, and local
   coaching remain useful without an account, network, subscription, or remote
   model.
2. **Agency before automation.** FocusHaven may understand and propose, but a
   person remains the authority for meaningful state changes.
3. **Compassion before scoring.** The product does not punish missed days,
   interrupted attempts, disability, illness, or changing capacity.
4. **Explainability.** Suggestions show the bounded signals that produced them
   and state uncertainty honestly.
5. **Progressive permission.** A capability requests access only when the
   person explicitly enters that capability, and denial leaves the rest of the
   app usable.
6. **Honest platform parity.** Unsupported platforms say so; they do not show
   controls that cannot keep their promise.
7. **Private by construction.** User-authored tasks, reflections, coaching,
   moods, and account content stay out of system-focus snapshots and public or
   locked surfaces.

## Current product map

| Experience | Status | Current truth | Next outcome |
| --- | --- | --- | --- |
| Core timer and recovery | Shipped | Focus and break sessions, persistence, pause/resume/reset/add-time, completion, and recovery are implemented. | Remain the sole authority behind Haven actions and future assistant inputs. |
| Haven Action Engine | Shipped | Typed requests and reviewed voice transcripts become versioned proposals with explanation, state checks, exact confirmation where required, replay protection, and service-owned execution. | Remain the shared policy boundary for later planner and system-assistant inputs. |
| Focus Queue | Shipped | Local task ordering, editing, completion, restoration, and one confirmed typed draft action exist. | Expand only through bounded, independently confirmed proposals. |
| Living Lantern | Shipped | A compassionate, ephemeral timer companion is derived locally without health loss or scoring. | Join the unified Haven Loop without adding pressure mechanics. |
| Haven Journey and Focus Garden | Partial | Lantern, campsite, cabin, garden, and sanctuary stages are locally derived and cannot regress. One exact completed Focus session can now explain whether the cumulative Journey kept its place or crossed an existing boundary. | Add more restorative scenes and reflection-driven personalization without levels, locks, or public ranks. |
| Haven Plan | Partial | Energy, available time, queue state, and text-free focus events produce a transparent local session preview. | Expand into a goal-to-plan workflow whose proposals require acceptance. |
| Smart Reset | Shipped | Interrupted attempts can receive a smaller, private restart suggestion. | Become one explicit recovery action available to typed and voice proposals. |
| Reflection and session fit | Shipped | Optional text-free feedback can describe whether a session was too much, about right, or could be longer. | Feed an explainable Adaptive Focus Engine. |
| Haven Rhythm | Shipped | Local text-free patterns produce one cautious observation at a time. | Contribute evidence to adaptation without becoming a diagnosis or score. |
| Focus Forecast | Shipped | Repeated local completion times can reveal a possible focus window with uncertainty. | Supply optional planning context, never an obligation. |
| Haven Window | Foundation shipped | Redacted calendar boundaries can support one explicit local hold and reminder on reviewed hosts. | Offer confirmed scheduling proposals while calendar writes remain a separate permission and action. |
| Focus Shield | Foundation shipped | iPhone has a consent-based adapter; Android truthfully reports unsupported. | Improve supported-platform reliability and guidance without pretending cross-platform enforcement exists. |
| Local Focus Coach | Shipped | Private local coaching remains the default and offline fallback. | Receive structured context and optional typed or voice transcripts through a common input boundary. |
| Enhanced remote coach | Foundation shipped, disabled | The callable is deployed but gated; client and server enablement remain off. | Remain separate from voice and action execution until entitlement, quota, enforcement, consent, and release gates pass. |
| Haven AI planner | Foundation shipped | A deterministic local planner turns an explicit goal and time window into an ephemeral proposal with inputs, assumptions, uncertainty, independently reviewable queue tasks, session-size guidance, and a calendar-free free-time suggestion. It has no remote model or execution authority. | Add an optional, separately disclosed remote drafting path whose output still returns through the same local review and action policy. |
| Unified Haven Loop | Foundation shipped | An explicitly selected active queue-item identity can follow one Focus session. Completion pauses for an exact task decision before optional reflection, Rhythm, Forecast, and Journey context. During an interruption, one ephemeral single-use ticket may preserve the same unchanged link through an explicit Smart Reset choice. Queue and timer services retain ownership. | Add local-coach context as one bounded, reviewable connection. |
| Voice-to-Coach | Shipped | Explicit tap-to-talk creates an editable coaching draft; FocusHaven keeps no raw-audio history and sends nothing until the person taps Send. | Complete fresh Android and Apple release, permission, and store-disclosure validation before distribution. |
| Safe voice commands | Shipped | Explicit tap-to-talk creates an editable action draft; Review action creates a local proposal; a second visual control runs or exactly confirms it through the same policy as typing. | Complete fresh platform builds, real-device command acceptance, accessibility checks, and store-disclosure validation before distribution. |
| Global localization | English Flutter extraction shipped | Generated Flutter localization is wired to the English source catalog. Core presentation and all audited Flutter-owned user-facing service results are catalog-owned. English is the only production runtime locale; Spanish, French, German, and Brazilian Portuguese are planned, not current language claims. | Human-review first-wave catalogs, language-aware understanding, and native/store surfaces before qualifying each locale independently. |
| Siri, Shortcuts, and Android App Actions | Planned | Existing widgets and watches use private, bounded timer commands; general assistant intents do not exist. | Expose a small reviewed action subset after the engine is proven in-app. |
| Soundscapes and focus environments | Planned | No built-in soundscape engine or generated environment exists. | Begin with bundled/offline audio and explicit playback controls before considering generated media. |
| Haven Rooms and body doubling | Deferred | There is no social presence, matching, chat, or shared timer service. | Revisit only after identity, abuse prevention, moderation, age, reporting, privacy, and operating-cost plans exist. |
| Focus Score | Replaced | FocusHaven intentionally avoids a productivity score. | If a summary is useful, design **Haven Momentum** as non-punitive, explainable, private, and never competitive. |

## Delivery sequence

### Phase 209 — Roadmap and safety contracts

Define this roadmap, the Haven Action architecture, and the voice/privacy
policy. Add contract tests that distinguish current behavior from planned work
and preserve the current no-microphone runtime boundary.

Exit criteria:

- shipped, partial, planned, deferred, and replaced concepts are explicit;
- future AI cannot bypass existing service ownership;
- voice is tap-to-talk, transcript-first, and not always listening;
- destructive, account, purchase, permission, and backend actions are outside
  direct voice execution;
- no runtime permission, dependency, manifest, provider, or deployment changes.

Status: complete at `8b27408`.

### Phase 210 — Haven Action Engine, typed input first

Implement a local, deterministic action proposal and policy layer. Typed
phrases exercise it before any microphone integration. Existing services remain
the only timer, queue, planning, hold, and navigation executors.

Exit criteria:

- a versioned proposal model and allowlisted actions exist;
- freshness, replay, availability, and current-state checks fail closed;
- state-changing proposals present an explanation and confirmation when
  required;
- unit and widget tests cover ambiguous, stale, duplicate, and unavailable
  actions;
- no remote model is required to understand the initial command set.

Status: implemented at `a734f31`, with review-surface accessibility hardening
at `8000342`. The timer screen exposes a typed action sheet;
the interpreter, policy, executor, confirmation, and receipt contracts are
separate; and focused tests cover ambiguity, protected actions, stale state,
exact confirmation, bounded add-time, and proposal replay. Phase 210 adds no
microphone permission, speech dependency, remote model call, or backend action.
The review surface also announces the exact interpretation, effect, risk, and
available choices; supports keyboard review and an explicit editable
**Change request** path; remains usable with large text on a narrow surface;
and removes every consumed proposal after success or rejection.

### Phase 211 — Action review hardening

Harden the typed review surface before introducing another input method. Keep
interpretation, effect, risk, confirmation, and change-request controls usable
with screen readers, keyboards, large text, and narrow displays.

Status: complete at `8000342`.

### Phase 212 — Voice-to-Coach

Add explicit tap-to-talk transcription for coaching input.
Voice first fills an editable transcript; it does not execute timer actions in
this phase.

Exit criteria:

- microphone access is requested just in time with an honest purpose string;
- denial, interruption, offline recognition, and unavailable recognition are
  safe and understandable;
- no wake word, background capture, or raw-audio history exists;
- store privacy disclosures and platform tests are updated before release.

Status: implemented in the current source. The recognizer initializes only
after an informed tap, uses a bounded listening window, exposes stop and
discard controls, keeps the transcript editable, and sends nothing until the
person taps **Send**. Platform speech recognition may operate on-device or over
a network. Fresh signed binaries and final store answers remain release work;
prior validated candidates predate this permission and dependency change.

### Phase 213 — Safe voice commands

Route a confirmed transcript through the same Phase 210 engine. Voice gains no
special authority and cannot call services directly.

Exit criteria:

- safe timer and navigation commands share typed-command tests;
- ambiguous recognition always asks rather than guesses;
- sensitive and destructive categories remain blocked or require an explicit
  visual confirmation;
- accessibility does not depend on speech recognition or spoken output.

Status: implemented in the current source. The shared transcription service
creates only an editable draft. Voice input cannot propose while listening and
cannot execute after transcription. The person must separately tap **Review
action**, inspect the source-labelled proposal, and then use **Run reviewed
action** or **Confirm exact action**. Typed and voice sources share the same
allowlist, state token, expiry, argument bounds, protected-action rejection,
exact confirmation, and replay protection. Local Coach and system-intent text
are rejected as proposal sources. No remote AI, backend call, direct service
path, new dependency, or new permission was added in Phase 213. Fresh signed
binaries, real-device acceptance, accessibility checks, and store disclosure
review remain required before distribution.

### Phase 214 — Haven AI planner

Turn an explicit user goal into a reviewable proposal containing possible
tasks, session sizes, queue changes, and optional free-time suggestions. The
model can draft; only the local action policy can apply accepted pieces.

Exit criteria:

- every proposal identifies inputs, assumptions, uncertainty, and affected
  local data;
- a person can accept, edit, or reject each meaningful change independently;
- remote processing is separately disclosed and opted into;
- no calendar write, queue replacement, or timer start occurs from generated
  text alone.

Status: Phase 214A local foundation implemented in the current source. **Plan a
goal** creates a deterministic, local-only, non-persistent proposal from the
explicit goal and time choices. The review identifies its inputs, assumptions,
medium uncertainty, and affected local data. Every task, session suggestion,
and free-time suggestion has its own **Accept**, **Edit** where supported, or
**Reject** choice. Nothing mutates until all items are settled and the exact
accepted queue list is confirmed. Each accepted task then becomes a fresh
state-bound `HavenActionProposal` and is executed by the existing Focus Queue
owner; the planner never writes the queue directly. Session and free-time
suggestions are informational, the timer remains unchanged, and no calendar is
read or written. Remote AI drafting, calendar proposals, and automatic plan
execution remain planned rather than shipped.

### Phase 215 — Unified Haven Loop

Connect Plan, focus, reflection, Rhythm, Forecast, Smart Reset, Journey, and
local coaching into one calm lifecycle without turning the dashboard into a
checklist or streak pressure system.

Status: Phase 215F completion-to-Journey continuity implemented in the current
source, building on the Phase 215A local Plan-to-Focus loop, Phase 215B
task-decision-to-reflection connection, Phase 215C reflection-to-Rhythm
connection, Phase 215D reflection-to-Forecast connection, and Phase 215E
linked Smart Reset continuity.
An explicit queue selection stores only the active queue-item ID and delegates
the visible intention to the existing timer owner. The queue remains the sole
owner of task text, ordering, and completion. The timer remains the sole owner
of Focus lifecycle state. No goal, planner proposal, task text, or session
history is copied into the link.

When that exact linked Focus session completes, the normal next-session control
waits for one explicit outcome. **Mark task complete** delegates to the existing
queue toggle; **Keep for later** preserves the active item. Either outcome
consumes the link and clears the timer intention. A rename, removal, prior
completion, session change, or manual intention edit invalidates the link
without mutating the queue. A stale or mismatched action fails closed.

Phase 215B connects that settled task decision to the existing session-fit
reflection without creating a second owner. While an exact linked-task outcome
is pending, reflection stays hidden and the next-session control remains
withheld. After **Mark task complete** or **Keep for later** succeeds, the
existing optional, text-free reflection appears. Taking the break without a
choice is an explicit skip and stores no reflection value. A choice is written
only by `TimerService`, bound to the exact immutable completion identity, and a
stale or replayed callback cannot modify a later completed attempt.

Phase 215C connects a saved fit on that exact current completion to one
ephemeral Haven Rhythm explanation. `HavenRhythmService` rebuilds the
connection from the existing bounded, text-free focus-event history. The card
states whether one reflection is still only a beginning, repeated reflections
contribute to the current local observation, or recent recovery signals still
lead. It offers no pace or timer control, states that nothing changed
automatically, and disappears when the exact completed Focus boundary ends.
Unanswered, stale, duplicate, or mismatched completion evidence returns no
connection.

Phase 215D independently connects the same exact saved fit to the existing
local Focus Forecast. `FocusForecastService` continues to infer timing only
from completed-session start times; the reflection cannot change its minimum
evidence, dominance, or local-time rules. The ephemeral explanation says
whether Forecast is still learning, the exact completion falls inside or
outside a possible window, or recent timing remains flexible. It has no
control, never ranks a best time, and states both **Nothing changed
automatically** and **A possible window is not a rule**. Current energy and
real-life availability continue to lead.

Phase 215E connects an interrupted linked Focus attempt to the existing Smart
Reset choice without adding a second task or recovery store. After the timer
pauses for review, `HavenLoopService` issues one ephemeral, single-use recovery
ticket only when the exact active queue-item ID still matches the Focus
intention. The ticket contains no task text. The sheet discloses that the link
continues only while the item remains active and unchanged. **Restart
smaller**, **Reset without restarting**, and **Keep this session** remain the
existing explicit timer-owned choices; only the already explicit restart
choice starts a smaller timer.

After the choice, the ticket is consumed and both owners are checked again. A
rename, removal, completion, manual intention change, newer ticket, replay, or
other mismatch fails closed and gains no queue authority. The selected item is
never completed, reordered, renamed, or removed by recovery. Ordinary unlinked
Smart Reset remains available and makes no queue-continuity claim.

Phase 215F connects the exact current completed Focus attempt to the existing
cumulative Haven Journey only after any linked task decision is settled.
`HavenJourneyService` requires the newest `FocusCompletionIdentity` to appear
exactly once in bounded text-free event history and independently re-derives
the supplied Journey state from its cumulative count. Stale, duplicate,
unresolved, or inconsistent evidence returns no connection.

The ephemeral card explains either that the completion is kept equally inside
the current place or that the established cumulative count crossed an existing
lantern, campsite, cabin, garden, or sanctuary boundary. It does not create a
new milestone, progress bar, score, streak, task outcome, or Journey mutation.
It stores no task title, queue ID, reflection, transcript, event copy, or
second Journey state; has no control; and disappears with the exact completed
Focus boundary. The visible statement says **This advisory changed nothing
automatically** and that Journey remains private, cumulative, and free of
scores or streak pressure.

Phases 215A through 215F do not infer success from elapsed time, auto-complete
work, select a break, copy task text or reflection content into a connection,
contact local or remote coaching, read or write a calendar, or add an account,
permission, dependency, backend, or deployment. Local-coach context remains
later Phase 215 work and must keep the same explicit, service-owned boundary.

### Phase 215G — Global localization

Build a release-quality localization system before promoting FocusHaven in
additional languages. Locale availability must remain truthful: an incomplete
catalog is not a supported language.

Status: Phase 215G-A foundation and Phase 215G-B1/B2/B3A/B3B/B3C/B4/B5/B6A/B6B1/B6B2/B6C1/B6C2/B6C3 English Flutter extraction are
implemented in the current source. Flutter's generated localization pipeline
owns the application title plus onboarding, appearance selection,
custom-duration chrome, guided breathing, and the main timer's complete
screen-reader description through one English ARB source catalog. B2 adds the
bounded timer dashboard: session names and encouragement, timer controls and
saved-session recovery, focus-intention and queue entry points, daily progress,
recent focus, short dates, confirmations, receipts, and errors. English remains
the only production-supported runtime locale. B3A adds Focus Queue management
and completed-task history, Haven Plan controls and preview chrome, Haven
Planner's local proposal and
review presentation, and the exact Plan-to-Focus task-decision card. Private
task and goal text remains opaque, while service-originated planning text
retains its B6 owner. B3B adds the text-free session-reflection presentation,
Haven Rhythm and Focus Forecast chrome and advisory boundaries, Smart Reset
presentation and actions, and Haven Journey place, privacy, accessibility, and
completion-advisory copy. Personal reflection content remains outside the
catalog, while service-generated restorative guidance retains its B6 owner.
Phase 215G-B3C adds Haven Window and Focus Shield presentation chrome, status
and action labels, permission and platform truth, privacy and agency boundaries,
locale-aware held-window time ranges, and Haven Window fail-closed receipts.
Service-generated Haven Window suggestion text and Focus Shield state text
retain their B6 owner and pass through as opaque runtime values.
Phase 215G-B4 adds the app-owned Focus Coach presentation, local/enhanced-AI
state and consent boundaries, Voice-to-Coach and safe-command tap-to-talk
presentation, localized stable permission and recognition notices, and Haven
action review, risk, semantics, and exact-confirmation presentation. Private
transcripts, user messages, Coach responses, proposal explanations and effects,
execution results, and service errors remain opaque runtime values with their
existing owners. B4 does not change recognition, permission, coaching, action,
or enhanced-AI behavior.
Phase 215G-B5 adds account and authentication presentation, cloud-backup and
destructive-data confirmations, Pro and purchase presentation, Reflection
Journal and Focus Profile chrome, reminders, milestones, Focus History, and
the current privacy-policy launch action. Private account identity, journal
and reflection content, task names, store prices, and service-returned values
remain opaque. Stable stored mood and profile identifiers are localized only
for presentation and are not migrated or translated in storage. B5 does not
perform an account, store, backup, deletion, reminder, permission, or legal
launch action.
Phase 215G-B6A adds catalog-owned Flutter notification titles and bodies,
Flutter-created Android notification channel labels, timer-completion
notification copy, and presentation mapping for every stable
account-deletion outcome. It changes no notification or channel identifier,
schedule, permission behavior, timer state, or deletion result. Generated
planning/restorative guidance and coaching, action, authentication, store,
journal, export, and other service results were completed by the later B6
slices without changing their owning behaviors.
Phase 215G-B6B1 adds catalog-owned stable local Haven Planner validation,
assumptions, uncertainty explanation, generated queue-item templates,
session-size guidance, and no-calendar free-time guidance. User-authored goal
text remains an opaque bounded placeholder, and proposal, review, queue, timer,
and calendar behavior are unchanged.
Phase 215G-B6B2 adds catalog-owned Haven Rhythm, Focus Forecast, Smart Reset,
Haven Journey, Haven Window, and Focus Shield guidance. Private reflections,
completion identities, redacted availability, and native-owned distraction
selections remain opaque runtime values. Service rules, thresholds, model
types, permissions, platform adapters, queue and timer ownership, and
persistence behavior are unchanged.
Phase 215G-B6C1 adds catalog-owned Haven action interpretation and effect text,
policy decisions, replay and exact-confirmation receipts, service failure
receipts, and successful execution receipts. User-authored queue titles remain
opaque placeholders. The English command grammar, action allowlist, protected
operations, proposal lifetime, state checks, confirmation fingerprints,
replay protection, and owning timer, queue, and navigation services are
unchanged.
Phase 215G-B6C2 adds catalog-owned deterministic private Local-Coach responses,
stable remembered-challenge labels, enhanced-AI fallback notices, and coaching
response, preference, repair, and cleanup errors. Private task names, moods,
profiles, messages, and conversation history remain opaque runtime
placeholders. The selected catalog is in-memory local context only and is not
included in Enhanced-AI prompt data. English signal recognition, responder
selection, consent, fallback, persistence, and cleanup behavior are unchanged.
Phase 215G-B6C3 adds catalog-owned authentication and store service results,
daily journal prompts, private Focus History export copy, Haven Plan guidance,
and Living Lantern guidance. Private identities, store prices, journal text,
moods, tasks, and history values remain opaque placeholders. Provider
diagnostics are not rendered as user copy. Authentication, entitlement,
purchase, persistence, export, plan, lantern, timer, and queue behavior are
unchanged. Phase 215G-B English Flutter extraction is complete.
The locale registry
records Spanish, French, German, and Brazilian Portuguese as the planned first
wave without exposing them through `supportedLocales` or making a
store-language claim.

The completed B6C3 boundary and the earlier extraction slices are recorded in
`docs/LOCALIZATION_EXTRACTION_INVENTORY.md`.
Phase 215G-C will add human-reviewed first-wave catalogs and qualify one locale
at a time. Phase 215G-D will align speech recognition, Voice-to-Coach, Haven
actions, and local coaching with the selected language without silently
translating private user content. Phase 215G-E will localize native Apple,
Android, widget, watch, permission, policy, support, and store surfaces and run
country-specific release checks.

Phase 215G-C0 translation qualification is implemented as the entry gate for
that work. It freezes the 980-message English source catalog at the verified
Phase 215G-B commit, records the 148 placeholder-bearing messages, adds a
fail-closed parity and placeholder auditor, creates an inactive Spanish review
record, and supplies a terminology and high-risk-copy worksheet. No Spanish
candidate exists in the production catalog directory, and no reviewer approval,
runtime activation, voice qualification, native/store qualification, or country
claim is implied.

Phase 215G-C1A candidate preparation adds an exact-source-locked, fail-closed
builder for the future isolated Spanish candidate. It requires complete key
parity, safe placeholders, non-empty translations, and explicit rationales for
intentional source-equal values, and it refuses production-directory output or
overwrite. This preparation slice creates no translation bundle or candidate,
contacts no translation provider, and leaves Spanish planned and inactive.

Phase 215G-C1B creates the complete machine-assisted Spanish candidate only in
the isolated review directory. The guarded builder and independent audit pass
all 980 messages, 148 placeholder-bearing messages, metadata, ICU placeholder
use, non-empty values, and 11 documented source-equal invariants. The candidate
has not received qualified human linguistic review and remains outside
`lib/l10n`; Spanish is still planned, inactive, and absent from public language
or country claims. Voice/coaching, runtime, native/store, accessibility, policy,
support, signed-build, and country gates remain pending.

Phase 215G-C2A prepares the source-locked human-review packet builder without
creating a packet or beginning review. The future packet will pair every locked
English and Spanish message with its description, placeholders, deterministic
risk categories, required checks, and empty decision fields. Critical copy is
ordered first and batches are limited to 50 entries. The builder refuses changed
catalogs, structural evidence, review state, output paths, existing output,
private runtime data, or invented approval. A separate guarded step must create
and lock the packet before a real qualified reviewer can be assigned.

Phase 215G-C2B creates and independently audits that isolated packet. The
884,241-byte packet has SHA-256
`325231a14ff0dfe2b176f6267996292aa0575b5db16d3c084cf453bf5f75737e`,
contains all 980 source/candidate pairs in 20 batches, and preserves 980
pending entries with empty decisions, replacements, and notes. The packet is
not distributed or assigned, human review has not started, and Spanish remains
linguistically unapproved, outside `lib/l10n`, runtime inactive, release
unqualified, and unsupported publicly. Reviewer assignment and completed
human review remain later explicit gates.

No Phase 215G-A, B1, B2, B3A, B3B, B3C, B4, B5, B6A, B6B1, B6B2, B6C1, B6C2, or B6C3 code changes a saved language, sends text to a
translation provider, translates tasks, reflections, journals, transcripts,
coaching, or account data, adds a permission, changes a backend, deploys a
build, or edits a store listing. The detailed release gates are defined in
`docs/LOCALIZATION_AND_GLOBAL_RELEASE_POLICY.md`.

### Phase 216 — Adaptive Focus Engine

Offer explainable local adjustments to session length, break shape, and timing
using bounded text-free signals. Recovery needs and explicit user choices
override learned patterns.

### Phase 217 — System assistant intents

Publish the proven safe subset through Siri/App Intents, Shortcuts, and Android
App Actions. System assistants receive bounded action parameters, not coaching
history or arbitrary private text.

### Phase 218 — Soundscapes and focus environments

Start with local, user-selected sound and predictable offline playback. Any
future generated environment is opt-in, cost-bounded, independently moderated,
and never required for core focus.

### Phase 219 — Expanded Haven Journey and Garden

Add scenes and gentle personalization based on completed sessions and explicit
preferences. Nothing decays, locks, shames, or becomes a public comparison.

### Later research — Haven Rooms

Social focus remains deferred. Before implementation, FocusHaven needs a
separate threat model and operating plan for identity, consent, blocking,
reporting, moderation, minors, harassment, presence privacy, retention,
notifications, and incident response.

## Release boundary for every future phase

Planning approval is not release approval. A phase that changes permissions,
data handling, native capabilities, dependencies, cloud processing, store
claims, or signed entitlements must receive a new privacy review, updated store
disclosures, platform-specific tests, a clean release build, and a newly
validated candidate. Prior Apple or Google validation does not automatically
cover a later feature.
