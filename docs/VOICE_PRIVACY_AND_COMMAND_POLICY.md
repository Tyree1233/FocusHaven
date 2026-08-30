# Voice Privacy and Command Policy

Status: future-feature policy; voice is **not implemented** through Phase 210

FocusHaven currently declares no Android `RECORD_AUDIO` permission, no iOS
`NSMicrophoneUsageDescription`, and no speech-recognition dependency. This
document does not change that boundary. It defines the conditions that must be
met before a later release may add Voice-to-Coach or safe voice commands.

The Phase 210 typed prerequisite now includes an accessible review
announcement, keyboard submission, an editable **Change request** path, and a
settled proposal lifecycle after both successful and rejected execution. That
is input and confirmation hardening, not microphone or speech implementation.

## Experience boundary

Voice will be an optional input method, not an autonomous assistant.

- Capture begins only after an explicit **tap-to-talk** or press-and-hold
  action.
- There is no always-listening mode, wake word, hidden background capture, or
  recording while the app is closed.
- A persistent visual indicator and accessible status identify listening,
  transcribing, stopped, unavailable, and failed states.
- Releasing or tapping stop ends capture immediately.
- Typing remains a complete alternative. No core feature requires speech.
- Spoken output is separately controlled and never implies the microphone is
  active.

## Transcript-first data flow

```text
explicit tap -> bounded audio capture -> platform speech recognition
             -> editable transcript -> user sends or proposes action
             -> local coach or Haven Action Engine
```

The first implementation keeps no raw-audio history. Audio is not written to
FocusHaven preferences, Firestore, cloud backup, coaching history, analytics,
diagnostics, or system-focus snapshots. The recognized transcript appears for
review before it is sent to coaching or evaluated as a command.

On-device recognition is preferred when the operating system and language
support it. Some platform recognizers may use a network service. FocusHaven
must disclose the effective behavior before permission and must not claim that
recognition is on-device when the platform cannot guarantee it. If a person
declines network-assisted recognition, typing and local app controls remain
available.

## Permission rules

1. Do not request microphone or speech-recognition access at application
   startup.
2. Explain the purpose immediately before the first tap-to-talk attempt.
3. Request only the platform permissions required for that chosen feature.
4. A denial, restriction, interruption, phone call, route change, timeout, or
   unavailable recognizer stops cleanly and changes no timer state.
5. Do not repeatedly prompt after denial. Offer system settings only after an
   explicit user action.
6. Adding a microphone purpose string, Android permission, speech dependency,
   or recognition service requires a new privacy and store disclosure review.

## Coaching boundary

Voice-to-Coach first creates an editable transcript. The local Focus Coach is
the default recipient and offline fallback. Enhanced remote coaching remains a
separate opt-in governed by its existing release flag, server switch, App
Check, entitlement, quota, consent, and retention disclosures.

Choosing voice does not choose remote AI. If the user explicitly selects the
enhanced coach, FocusHaven may send the reviewed transcript and the same bounded
context allowed for typed coaching. It does not send raw audio, microphone
metadata, unrelated conversation, calendar content, or background sound.

## Voice-command authority

Voice receives no authority beyond typed input. A transcript must pass through
the Haven Action Engine described in
[`HAVEN_AI_ACTION_ARCHITECTURE.md`](HAVEN_AI_ACTION_ARCHITECTURE.md).

### Eligible after deterministic validation

- read the current timer status;
- start a ready session;
- pause or resume;
- add a bounded amount of time;
- open a FocusHaven surface;
- draft one queue item for review.

The interface shows what it understood. If speech is ambiguous, incomplete, or
contradicts current state, FocusHaven asks or rejects it and makes no change.

### Requires explicit visual confirmation

- reset or discard a session;
- replace or reorder saved queue content;
- accept and save a Haven Plan;
- create or release a Haven Window hold;
- change a normal duration, reminder, or Focus Shield selection;
- clear local history or coaching content.

The confirmation binds to the exact displayed proposal. A spoken “yes” alone
does not satisfy a destructive confirmation.

### Navigation only; never voice-completed

- delete cloud backup or delete an account;
- sign out or change an authentication provider;
- purchase, restore, cancel, or change a subscription;
- grant a microphone, calendar, notification, Family Controls, or other system
  permission;
- create, edit, or delete a calendar event;
- change protected account or security settings.

Voice may open the dedicated screen, but the existing UI, authentication, and
confirmation rules remain mandatory.

### Forbidden

Voice and in-app AI cannot modify Firebase, IAM, App Check enforcement,
providers, credentials, functions, Hosting, remote-coaching enablement, build
configuration, store delivery, TestFlight, or review submission.

## Retention and deletion

- Raw audio is not retained by FocusHaven.
- An unsent transcript is ephemeral and disappears when dismissed.
- A transcript intentionally sent to coaching follows the same local history,
  deletion, and optional remote-processing rules as typed coaching text.
- A command transcript is discarded after the proposal settles unless the
  person separately chooses to keep its text as a task or coaching message.
- Privacy-safe diagnostics may record categories such as
  `voice.permission_denied` or `voice.recognition_unavailable`; they do not
  contain audio, transcript text, task content, names, account identifiers, or
  credentials.

## Accessibility and safety

- Every voice action has a visible, keyboard, switch-control, and screen-reader
  equivalent.
- Listening and confirmation states are announced without relying on color,
  animation, sound, or haptics alone.
- No timer control depends on spoken output being audible.
- Transcripts remain editable because recognition errors are expected,
  especially for accents, speech disabilities, noisy environments, task names,
  and uncommon words.
- Voice suggestions use calm language and never diagnose attention, mood, or
  health.

## Release gates

Voice-to-Coach cannot ship until the release branch includes:

- platform-specific permission copy and denial handling;
- an explicit no-always-listening implementation test;
- tests proving raw audio is not persisted or uploaded by FocusHaven;
- store privacy and data-safety answers updated for the actual recognizer;
- disclosure of any operating-system or provider network processing;
- fresh Android and Apple release builds and validation;
- a support path for deleting any saved transcript through existing local
  coaching deletion controls.

Safe voice commands additionally require the completed Phase 210 typed action
engine, ambiguity tests, confirmation binding, stale/replay protection, and
negative tests for every navigation-only and forbidden category.
