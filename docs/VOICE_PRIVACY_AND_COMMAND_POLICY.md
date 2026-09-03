# Voice Privacy and Command Policy

Status: Voice-to-Coach is implemented in Phase 212 and Safe Voice Commands is
implemented in Phase 213 source; Phase 215G-D1 adds explicit English/Spanish
speech-locale propagation while production remains English-only

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

Only `typed` and `voiceTranscript` are accepted proposal sources.
`localCoach` and `systemIntent` are rejected. Speech never calls
`TimerService`, `FocusQueueService`, navigation, or another mutation path
directly.

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

Fresh Android and Apple release builds, native permission exercises,
real-device Spanish recognition and Safe Voice Commands acceptance,
language-aware coaching and action checks, signed candidate validation, and
final store privacy answers remain required before distribution. Prior App
Store and Play artifacts are not evidence for this changed permission,
dependency, and action-input boundary.
