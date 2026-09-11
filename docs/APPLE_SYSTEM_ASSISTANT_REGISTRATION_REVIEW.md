# Apple system-assistant registration review gate

Status: Phase 217G availability-gated registration foundation implemented for
iOS 16 and later; real-device, signed-release, store, and distribution gates
remain closed.

## Exact registered surface

FocusHaven declares exactly five parameter-free App Intents:

- check the current Focus timer status;
- start the ready Focus session;
- pause the current Focus timer;
- resume the paused Focus timer; and
- open Focus Queue.

Each intent has one matching App Shortcut. The localized
`AppShortcuts.strings` family is a deterministic transform of the approved
Phase 217F native phrase values across English, fifteen independently reviewed
languages, and base Portuguese derived from approved Brazilian Portuguese. The
transform changes only the single `%@` application-name token to App
Shortcuts' `${applicationName}` token. The localized strings-family form keeps
the shortcut phrases compatible with the unchanged iOS 15 deployment target;
the iOS-17-only `AppShortcuts.xcstrings` form is explicitly absent.

There is no duration, task title, queue item, transcript, utterance, journal,
reflection, coaching history, account value, or arbitrary text parameter.

## Availability and handoff

The project still targets iOS 15. App Intent types, their provider, and the
registration refresh are gated to iOS 16 or later, so iOS 15 retains its prior
launch and app behavior. Each registered intent requires device authentication
and opens FocusHaven.

Submission constructs only the existing Phase 217E request: schema version
`1`, one generated bounded opaque invocation ID, and one allowlisted route. It
may write only to the existing single-slot, process-memory pending-request
store. It cannot replace an occupied request, persist a request, cross the
Flutter channel directly, inspect owner state, or prepare a Haven Action review.

## Confirmation and execution boundary

The native response can report only one of three reviewed truths:

- FocusHaven is opening so the person can review the request, and nothing has
  happened yet;
- FocusHaven already has one request waiting for review; or
- the request is unavailable and nothing changed.

Authentication, Siri or Shortcuts acknowledgement, app launch, request
submission, and Flutter delivery are never the visible in-app Confirm action.
Only the existing app host can prepare the fresh two-minute review, and only
the existing review service and Haven Action Engine can settle a still-valid,
explicitly confirmed proposal. The App Intents source imports or calls none of
those owners.

## Closed release boundary

Phase 217G adds no Siri entitlement, Siri usage description, supported-intent
Info property, deep link, persistence, analytics, provider, network, AI,
third-party package, Android manifest entry, timer owner, queue owner, or Haven
Action execution call. Flutter runtime localization remains unchanged.

Before distribution, a separately authorized release gate must verify cold and
warm launch, process termination, occupied-request behavior, cancellation,
replay, stale owner state, Siri and Shortcuts discovery, VoiceOver, large text,
and every supported language on real devices. It must also complete fresh
signed builds, privacy and store-disclosure review, candidate validation, and
explicit distribution authorization. Android App Actions require their own
copy, adapter, review, test, and release phase.
