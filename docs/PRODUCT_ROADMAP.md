# FocusHaven Product Roadmap

Status: living product contract; Phase 210 typed actions are implemented
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
| Haven Action Engine | Shipped | Typed local requests become versioned proposals with explanation, state checks, exact confirmation where required, replay protection, and service-owned execution. | Remain the shared policy boundary for later voice and system-assistant inputs. |
| Focus Queue | Shipped | Local task ordering, editing, completion, restoration, and one confirmed typed draft action exist. | Expand only through bounded, independently confirmed proposals. |
| Living Lantern | Shipped | A compassionate, ephemeral timer companion is derived locally without health loss or scoring. | Join the unified Haven Loop without adding pressure mechanics. |
| Haven Journey and Focus Garden | Partial | Lantern, campsite, cabin, garden, and sanctuary stages are locally derived and cannot regress. | Add more restorative scenes and reflection-driven personalization without levels, locks, or public ranks. |
| Haven Plan | Partial | Energy, available time, queue state, and text-free focus events produce a transparent local session preview. | Expand into a goal-to-plan workflow whose proposals require acceptance. |
| Smart Reset | Shipped | Interrupted attempts can receive a smaller, private restart suggestion. | Become one explicit recovery action available to typed and voice proposals. |
| Reflection and session fit | Shipped | Optional text-free feedback can describe whether a session was too much, about right, or could be longer. | Feed an explainable Adaptive Focus Engine. |
| Haven Rhythm | Shipped | Local text-free patterns produce one cautious observation at a time. | Contribute evidence to adaptation without becoming a diagnosis or score. |
| Focus Forecast | Shipped | Repeated local completion times can reveal a possible focus window with uncertainty. | Supply optional planning context, never an obligation. |
| Haven Window | Foundation shipped | Redacted calendar boundaries can support one explicit local hold and reminder on reviewed hosts. | Offer confirmed scheduling proposals while calendar writes remain a separate permission and action. |
| Focus Shield | Foundation shipped | iPhone has a consent-based adapter; Android truthfully reports unsupported. | Improve supported-platform reliability and guidance without pretending cross-platform enforcement exists. |
| Local Focus Coach | Shipped | Private local coaching remains the default and offline fallback. | Receive structured context and optional typed or voice transcripts through a common input boundary. |
| Enhanced remote coach | Foundation shipped, disabled | The callable is deployed but gated; client and server enablement remain off. | Remain separate from voice and action execution until entitlement, quota, enforcement, consent, and release gates pass. |
| Haven AI planner | Planned | There is no general AI orchestration or goal decomposition engine. | Convert an explicit goal into explainable task, session, and schedule proposals. |
| Voice-to-Coach | Planned | The current app has no microphone permission or speech dependency. | Add explicit tap-to-talk transcription with no always-listening mode and no raw-audio history. |
| Safe voice commands | Planned | Voice cannot currently control the timer or queue. | Route transcripts through the same typed Haven Action Engine and confirmation policy. |
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

Status: implemented. The timer screen now exposes a local typed action sheet;
the interpreter, policy, executor, confirmation, and receipt contracts are
separate; and focused tests cover ambiguity, protected actions, stale state,
exact confirmation, bounded add-time, and proposal replay. Phase 210 adds no
microphone permission, speech dependency, remote model call, or backend action.

### Phase 211 — Voice-to-Coach

Add explicit press-and-hold or tap-to-talk transcription for coaching input.
Voice first fills an editable transcript; it does not execute timer actions in
this phase.

Exit criteria:

- microphone access is requested just in time with an honest purpose string;
- denial, interruption, offline recognition, and unavailable recognition are
  safe and understandable;
- no wake word, background capture, or raw-audio history exists;
- store privacy disclosures and platform tests are updated before release.

### Phase 212 — Safe voice commands

Route a confirmed transcript through the same Phase 210 engine. Voice gains no
special authority and cannot call services directly.

Exit criteria:

- safe timer and navigation commands share typed-command tests;
- ambiguous recognition always asks rather than guesses;
- sensitive and destructive categories remain blocked or require an explicit
  visual confirmation;
- accessibility does not depend on speech recognition or spoken output.

### Phase 213 — Haven AI planner

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

### Phase 214 — Unified Haven Loop

Connect Plan, focus, reflection, Rhythm, Forecast, Smart Reset, Journey, and
local coaching into one calm lifecycle without turning the dashboard into a
checklist or streak pressure system.

### Phase 215 — Adaptive Focus Engine

Offer explainable local adjustments to session length, break shape, and timing
using bounded text-free signals. Recovery needs and explicit user choices
override learned patterns.

### Phase 216 — System assistant intents

Publish the proven safe subset through Siri/App Intents, Shortcuts, and Android
App Actions. System assistants receive bounded action parameters, not coaching
history or arbitrary private text.

### Phase 217 — Soundscapes and focus environments

Start with local, user-selected sound and predictable offline playback. Any
future generated environment is opt-in, cost-bounded, independently moderated,
and never required for core focus.

### Phase 218 — Expanded Haven Journey and Garden

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
