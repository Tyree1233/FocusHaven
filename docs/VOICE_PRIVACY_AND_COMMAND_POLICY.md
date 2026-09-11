# Voice Privacy and Command Policy

Status: Voice-to-Coach is implemented in Phase 212 and Safe Voice Commands is
implemented in Phase 213 source; Phase 215G-D2 records bounded physical Spanish
recognition acceptance while production remains English-only

FocusHaven declares narrowly scoped Android microphone access, iOS microphone
and speech-recognition purpose strings, and the `speech_to_text` dependency for
explicit tap-to-talk transcripts. The same bounded transcription service can
fill either an editable Focus Coach draft or an editable Haven action draft.
There is no always-listening mode, background capture, wake word, or raw-audio
history. Fresh signed binaries and store review remain required because earlier
validated candidates predate these capabilities.

## Experience boundary

Voice is an optional input method, not an autonomous assistant.

- Capture begins only after an explicit **tap-to-talk** action and an informed
  disclosure for the surface being used.
- Accepting the Coach disclosure does not silently accept the Haven action
  disclosure; the action notice separately explains its review and execution
  gates.
- There is no always-listening mode, wake word, hidden background capture, or
  recording while the app is closed.
- A visible indicator and accessible status identify listening, transcribing,
  stopped, unavailable, and failed states.
- Stop, discard, closing the surface, backgrounding the app, interruption,
  timeout, or recognition failure ends capture.
- Typing remains a complete alternative. No core feature requires speech.
- Spoken output is separately controlled and never implies the microphone is
  active.
- Every recognition attempt passes an explicitly admitted locale to the
  platform recognizer. The current exact set is English (`en`) and Spanish
  (`es`); an unsupported locale stops before recognizer initialization or
  permission work and keeps typing available.

## Transcript-first data flows

```text
Coach:
explicit tap -> bounded speech recognition -> editable coaching draft
             -> user taps Send -> local Focus Coach

Haven action:
explicit tap -> bounded speech recognition -> editable action draft
             -> user taps Review action -> local source-labelled proposal
             -> user taps Run reviewed action or Confirm exact action
             -> existing FocusHaven service
```

FocusHaven keeps no raw-audio history. Audio is not written to preferences,
Firestore, cloud backup, coaching history, analytics, diagnostics, timer
snapshots, or action history. Depending on platform, device settings, language,
and installed recognition services, speech recognition may happen on-device or
may use the platform provider's network service. FocusHaven discloses this
before permission and does not claim recognition is always local.

Nothing is sent to Focus Coach until the user taps **Send**. Nothing is
proposed to the Haven Action Engine until the user taps **Review action**.
Nothing executes until the user taps the separate visual **Run reviewed
action** or **Confirm exact action** control. A transcript left unsent or
unreviewed remains an editable session draft and disappears when discarded or
the surface is dismissed.

## Permission rules

1. FocusHaven does not request microphone or speech-recognition access at
   application startup.
2. FocusHaven explains the purpose immediately before the first tap-to-talk
   attempt on each voice surface.
3. Request only the platform permissions required for that chosen feature.
4. A denial, restriction, interruption, phone call, route change, timeout, or
   unavailable recognizer stops cleanly and changes no timer or queue state.
5. Do not repeatedly prompt after denial. Offer system settings only after an
   explicit user action.
6. The microphone purpose strings, Android permission, speech dependency, and
   recognition provider require fresh privacy, store, and release evidence
   before distribution.

## Coaching boundary

Voice-to-Coach first creates an editable transcript. The local Focus Coach is
the default recipient and offline fallback. Choosing voice does not choose
remote AI. Enhanced remote coaching remains a separate opt-in governed by its
release flag, server switch, App Check, entitlement, quota, consent, and
retention disclosures.

If the person explicitly selects enhanced coaching and taps **Send**,
FocusHaven may send the reviewed transcript and the same bounded context
allowed for typed coaching. It does not send raw audio, microphone metadata,
unrelated conversation, calendar content, or background sound.

Coach output never becomes action authority. `localCoach` input is rejected by
the Haven interpreter and policy rather than being converted into a proposal.

## Safe voice-command authority

Voice receives no authority beyond typed input. A reviewed transcript passes
through the same Haven Action Engine described in
[`HAVEN_AI_ACTION_ARCHITECTURE.md`](HAVEN_AI_ACTION_ARCHITECTURE.md).

Only `typed` and `voiceTranscript` enter through the free-text interpreter.
`localCoach` and raw `systemIntent` drafts are rejected there. Separately, the
Phase 217B bridge can produce only an exact five-route, fresh-state, two-minute
`systemIntent` proposal after preparing a localized in-app review; every such
route requires a separate exact visual confirmation. Speech never calls
`TimerService`, `FocusQueueService`, navigation, or another mutation path
directly.

The isolated Phase 217C presentation does not accept speech, a transcript, or
an arbitrary string. It can display only one opaque reviewed capability and
complete copy supplied by its caller. Dismiss and confirm are separate visual
choices that disable together before either callback runs. The card cannot
settle the review itself, and no production or native system-assistant input
consumes it in Phase 217C.

Phase 217D first locks the complete public English review-copy proposal. Its
privacy disclosure states that only the action type and a private request code
enter FocusHaven; no transcript, task, journal, coaching, or account text is
included. After fifteen independent fluent approvals, the complete copy is
present in every runtime catalog and one app-level host can consume only a
typed, text-free request from its memory-only inbox. The inbox currently has no
native producer. Copy review and app hosting cannot authorize a spoken
acknowledgement, background callback, notification action, or system-assistant
success response to confirm a Haven Action.

Phase 217E adds one private Apple delivery seam, not a public Siri or Shortcuts
capability. Swift can hold one exact three-field, text-free request only in
process memory; Flutter acknowledges it only after the existing single-slot
inbox accepts it. The native copy cannot include a transcript or arbitrary
parameter, cannot inspect timer or queue state, and cannot confirm or execute a
proposal. Failed delivery is not a spoken acknowledgement and never becomes
action consent.

Native Apple titles, invocation phrases, parameter summaries, and result
dialogue have completed independent review and exist only in the Runner-local
String Catalog and typed accessor. Phase 217G later adds parameter-free App
Intent and App Shortcut declarations on iOS 16 and later. Siri entitlements,
real-device acceptance, store disclosure, and distribution stay closed. Android
App Actions remain a separate later gate.

Phase 217F isolates the complete English proposal for those native Apple
strings without exposing them. Every invocation phrase asks to review one of
the five allowlisted routes and accepts only the application name placeholder.
The privacy copy states that only the action type and a private request code
enter FocusHaven; the parameter copy rejects time, task, and queue details.
Handoff and accessibility results say that review is required and no action has
run. They cannot represent a spoken acknowledgement as consent.

Fifteen independent language approvals were required before the Apple String
Catalog could be built. Copy approval alone grants no App Intent, Shortcut, Siri,
timer, queue, confirmation, execution, deployment, publication, or phone
authority. Public native registration, real-device accessibility and assistant
checks, signed validation, store review, and distribution remain separate.

Those fifteen approvals now feed one exact Runner-local String Catalog and a
typed, fail-closed copy accessor. The catalog transform records no reviewer
identity and sends no text externally. Base Portuguese is derived only from the
approved Brazilian Portuguese values. Catalog availability still grants no
App Intent, Shortcut, Siri, timer, queue, confirmation, execution, deployment,
publication, phone, Android, or distribution authority.

Phase 217G exposes only the five reviewed, parameter-free Apple routes on iOS
16 and later. The system surface receives no transcript, utterance, duration,
task, queue item, journal, reflection, coaching history, account value, or other
free-form field. It may submit only schema version `1`, a bounded opaque
invocation ID, and one allowlisted route to the existing process-memory slot.

Every intent opens FocusHaven for the visible review. Authentication, native
submission, spoken acknowledgement, app launch, and Flutter delivery are not
consent to execute and cannot substitute for the in-app Confirm action. An
occupied slot or unavailable reviewed copy fails closed. No Siri entitlement,
new retention, analytics, persistence, network, provider, or Android capability
is added. Real-device accessibility, assistant, signed-release, privacy/store,
candidate, and distribution review remains required.

Phase 217H adds the matching private Android transport without making any route
discoverable to Google Assistant. One process-memory slot may contain only the
schema version, bounded opaque invocation ID, and one of the same five route
kinds. Kotlin and Dart reject extra fields and free-form parameters, and the
slot clears only after the existing single-slot Flutter inbox accepts the exact
request.

Android delivery is not confirmation and cannot read or change timer or queue
state. The phase adds no `shortcuts.xml`, manifest capability metadata,
Assistant built-in or custom intent, query pattern, public native copy,
permission, persistence, provider, or execution route. Android copy review,
registration, Assistant/device testing, signed validation, Play disclosure,
and distribution remain separate closed gates.

Phase 217I isolates the complete English proposal for Android-native strings
without exposing them. Every long label and invocation example asks to review
one of the five allowlisted routes and accepts no placeholder or parameter.
The privacy copy states that only the action type and a private request code
enter FocusHaven; the parameter copy rejects time, task, and queue details.
Handoff and TalkBack results say that review is required and no action has run.
They cannot represent an Assistant acknowledgement as consent.

Fifteen independent language approvals are required before Android string
resources may be built. Copy approval alone grants no `shortcuts.xml`,
capability, query pattern, manifest entry, App Action, timer, queue,
confirmation, execution, deployment, publication, or phone authority. Public
registration, official Assistant preview, real-device accessibility and
language checks, signed validation, Play review, and distribution remain
separate.

### Eligible through the shared typed-and-voice policy

- read the current timer status;
- start a ready focus or break session;
- pause or resume the current session;
- add a bounded amount of time;
- open an allowlisted FocusHaven surface; and
- draft one queue item for exact review and confirmation.

Typed and voice requests share the same deterministic grammar, current-state
token, expiry, argument bounds, ambiguity rejection, protected-action
rejection, exact confirmation, service ownership, and replay protection. The
interface displays both the interpreted action and its source. Editing a voice
draft does not erase its voice provenance. Discard restores the exact typed
draft that existed before listening.

### Requires explicit visual confirmation

- every reviewed proposal requires a visual run control;
- saved queue edits require **Confirm exact action** bound to the exact proposal
  ID and arguments; and
- reset, discard, saved-plan changes, duration changes, reminder changes,
  Focus Shield changes, and local-history deletion remain outside the current
  voice allowlist.

A spoken “yes” alone does not satisfy a destructive confirmation. Voice cannot
activate either visual confirmation control.

### Navigation only; never voice-completed

- delete cloud backup or delete an account;
- sign out or change an authentication provider;
- purchase, restore, cancel, or change a subscription;
- grant microphone, calendar, notification, Family Controls, or other system
  permission;
- create, edit, or delete a calendar event; and
- change protected account or security settings.

The current Phase 213 grammar rejects these requests rather than completing
them. Any future navigation-only expansion must preserve the dedicated screen,
authentication, and confirmation rules.

### Forbidden

Voice and in-app AI cannot modify Firebase, IAM, App Check enforcement,
providers, credentials, functions, Hosting, remote-coaching enablement, build
configuration, store delivery, TestFlight, or review submission.

## Retention and deletion

- Raw audio is not retained by FocusHaven.
- An unsent or unreviewed transcript is ephemeral and disappears when
  discarded or its surface is dismissed.
- A transcript intentionally sent to coaching follows the same local history,
  deletion, and optional remote-processing rules as typed coaching text.
- A command transcript and proposal disappear after execution or rejection;
  FocusHaven stores no raw command history.
- Privacy-safe diagnostics may record categories such as
  `voice.permission_denied` or `voice.recognition_unavailable`; they do not
  contain audio, transcript text, task content, names, account identifiers, or
  credentials.

## Accessibility and safety

- Every voice path has a visible, keyboard, switch-control, and screen-reader
  equivalent.
- Listening, review, source, risk, confirmation, and completion states are
  announced without relying on color, animation, sound, or haptics alone.
- No timer control depends on spoken output being audible.
- Transcripts remain editable because recognition errors are expected,
  especially for accents, speech disabilities, noisy environments, task names,
  and uncommon words.
- Voice suggestions use calm language and never diagnose attention, mood, or
  health.

## Release evidence and remaining boundary

The Phase 212 and Phase 213 source and test boundary includes:

- platform-specific permission copy and denial handling;
- explicit no-always-listening and lifecycle cancellation tests;
- tests proving raw audio is not persisted or uploaded by FocusHaven;
- separate Coach and Haven-action informed disclosures;
- tests proving no proposal while listening, no proposal before **Review
  action**, and no execution before the second visual control;
- identical typed/voice policy, state, exact-confirmation, and replay tests;
- negative tests for protected requests, Coach output, and system-intent input;
- updated store privacy and data-safety working answers; and
- disclosure of possible operating-system or provider network processing.

Phase 215G-D1 verifies explicit English/Spanish locale propagation from both
voice surfaces and fail-closed handling before platform or permission work for
any unsupported locale. It does not qualify platform locale availability,
recognition accuracy, Spanish Local Coach responses, Spanish safe-command
interpretation, or enhanced-AI language behavior.

Phase 215G-D2 accepts bounded physical Spanish recognition on an approved
Android phone and a redacted trusted iPhone using exact D1 artifacts and two
fixed public phrases per platform. Both voice surfaces produced one
recognizable editable draft; stop, discard, and background cancellation passed
without automatic sending, proposal creation, or execution. Exact normal
English artifacts were restored afterward. The anonymous result stores no
operator identity, phone identifier, live transcript, screenshot, UI dump, or
app-private data. It does not qualify Spanish Local Coach responses, Spanish
safe-command interpretation or execution, or Enhanced AI language behavior.

Fresh Android and Apple release builds, native permission exercises,
Safe Voice Commands acceptance, language-aware coaching and action checks,
signed candidate validation, and final store privacy answers remain required
before distribution. Prior App Store and Play artifacts are not evidence for
this changed permission, dependency, and action-input boundary.
