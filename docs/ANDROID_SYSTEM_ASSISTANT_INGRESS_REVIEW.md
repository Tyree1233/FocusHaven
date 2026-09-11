# Android system-assistant ingress review gate

Status: Phase 217H private Android-to-Flutter ingress active; public App
Actions registration, Android-native discovery copy, release, and execution
remain closed.

## Purpose

Phase 217H adds the smallest Android-native transport that can later carry a
reviewed system-assistant request into the existing app-level review host. It
does not make a command discoverable to Google Assistant and does not add a
public Android shortcut. Native titles, descriptions, query patterns, and
Assistant-facing outcomes remain new public copy that must pass independent
review before any public registration.

The adapter mirrors exactly five text-free routes:

- read timer status;
- start a Focus timer with no duration parameter;
- pause the timer;
- resume the timer; and
- open Focus Queue.

No native route exists for adding time, starting a break, editing a queue item,
passing a task, or supplying an arbitrary parameter.

## Exact wire and memory contract

One request contains exactly schema version `1`, one opaque ASCII invocation ID
of at most 128 characters, and one allowlisted route name. Kotlin and Dart both
reject unknown fields, malformed identifiers, unsupported schema versions,
unknown routes, and free-form parameters. There is no field for a transcript,
utterance, task title, journal, reflection, coaching history, account value,
requested duration, queue text, or other user-authored content.

The native store holds at most one request in process memory. It writes no
preferences, file, database, cloud value, analytics event, or log. A second
request is rejected. The first remains pending until Flutter returns `true`
after the existing `HavenSystemIntentInbox` accepts that exact payload. Failed,
malformed, unhandled, or capacity-blocked delivery is not acknowledged or
cleared.

## Production ownership

`MainActivity` installs one private method-channel adapter with the existing
Flutter engine. The Android-only lifecycle host asks for delivery after Flutter
has installed its handler and whenever the app resumes. Apple, web, macOS,
Windows, and Linux leave this host dormant.

Acknowledgement grants no action authority. The native adapter and lifecycle
host import no timer, queue, review service, or Haven Action Engine. An accepted
request enters only the existing memory inbox. Preparation, fresh-state
binding, two-minute expiry, visible localized review, exact confirmation,
policy revalidation, and service-owner execution remain unchanged.

## Closed public registration boundary

Current Android App Actions use `capability` declarations in a
`res/xml/shortcuts.xml` resource referenced by `android.app.shortcuts` metadata
in the application manifest. Phase 217H adds neither file nor metadata. It also
adds no built-in intent, custom intent, query pattern, static or dynamic
shortcut, deep link, exported Assistant activity, Jetpack Core dependency,
provider, permission, or Android-native public copy.

Before any public Android registration, a separately authorized phase must:

1. choose exact built-in or custom intent mappings for the five review-only
   routes without accepting parameters;
2. lock complete English Assistant discovery, invocation, privacy, handoff,
   failure, and accessibility copy;
3. obtain independent fluent approval for all fifteen non-English production
   languages and derive base Portuguese only from reviewed Brazilian
   Portuguese where applicable;
4. prove every fulfillment opens FocusHaven for review and never reports that
   an action succeeded before the in-app Confirm action settles it;
5. test cold launch, warm launch, process termination, occupied-request
   behavior, cancellation, replay, stale owner state, Assistant discovery,
   TalkBack, large text, and supported languages using the official App Actions
   test tooling and real supported devices; and
6. complete signed release builds, privacy and Play disclosure review,
   candidate validation, and explicit distribution authorization.

The platform contract is documented by Android's official
[App Actions overview](https://developer.android.com/develop/devices/assistant/overview)
and
[shortcuts capability schema](https://developer.android.com/develop/devices/assistant/action-schema).
Apple registration cannot authorize Android registration or release.
