# Android system-assistant candidate validation

Status: Phase 217L defines the exact candidate-validation and release-review
contract for the five Phase 217K Android App Actions routes. No Assistant
preview, Google-account operation, signed candidate, phone access, Play upload,
App Actions review, or distribution authorization has occurred.

## Purpose

Source registration is not proof that Google Assistant recognizes a route, that
an installed candidate delivers the intended explicit Android intent, or that
the resulting FocusHaven review is accessible on a real device. Phase 217L
therefore separates the evidence needed for candidate validation from every
external operation that could create that evidence.

The source of truth is
`docs/contracts/android_system_assistant_candidate_validation_v1.json`. It
inherits exactly the five routes and closed execution boundary from
`android_system_assistant_app_actions_registration_v1.json`. The contract is a
plan and preflight gate only. A blank result is not a pass, and completing one
gate cannot authorize another.

## Required route matrix

Each of the five registered routes must be exercised through the official App
Actions test tool against the exact signed candidate under review:

- review Focus timer status;
- review starting the Focus timer;
- review pausing the Focus timer;
- review resuming the Focus timer; and
- review opening Focus Queue.

Every route must be checked from both a cold app launch and a warm activity.
For an action available in the restored owner state, the observable destination
is the existing in-app **Confirm action** review, not a completed timer or queue
mutation. An unavailable action must instead produce a correlated policy
rejection without a review or timer or queue mutation. The contract's
`expectedDestination` names the admitted review destination; it does not bypass
state-dependent action policy. Recreating `MainActivity` after a
recognized delivery must not replay the fulfillment. Repeating an already
consumed request code must also fail closed.

### Cold restoration and state-dependent outcomes

A process-cold launch starts a new application process and restores persisted
owner state before review preparation. Recreating an activity in an existing
process, or launching the app before delivering the request, is not proof of
process-cold delivery. Record which lifecycle path was actually exercised.

The existing timer restoration policy does not automatically restart an
interrupted countdown. An unexpired persisted deadline restores a stopped
timer with a pending resume; an explicitly paused timer remains paused.
The required Pause/Resume outcomes after restoration are:

| Restored state | Pause request | Resume request |
| --- | --- | --- |
| Ready | Policy rejection | Policy rejection |
| Pending resume | Policy rejection | Confirm action review |
| Explicitly paused | Policy rejection | Confirm action review |

Pause remains available only while the timer is running. Do not start or resume
the timer merely to turn a cold Pause rejection into a positive review result.
A missing review alone is not proof of rejection: correlate the delivered
request with the policy result and verify unchanged timer and queue state.
Separate restoration's own persistence updates from subsequent request effects.

`test/haven_system_intent_cold_restoration_test.dart` covers all six composed
restoration outcomes, unchanged owner and mock preference state after review
preparation, and replay rejection. These source tests do not prove Android
intent delivery, device accessibility, Assistant recognition, or candidate
qualification. Device and official-tool evidence remain separate requirements.

## Negative-input matrix

Candidate validation must prove rejection without replacing a pending review
or changing timer or queue state for:

- an unknown action;
- any extra on a timer route;
- a missing, changed, or additional queue `feature` value;
- URI data, `ClipData`, or an Android intent selector;
- an invalid or unbounded invocation ID;
- missing or malformed reviewed native copy; and
- activity recreation after the fulfillment intent has been neutralized.

No transcript, utterance, task title, duration, queue item, journal,
reflection, coaching content, account value, or arbitrary Assistant parameter
may appear in the request, logs, screenshots, or retained test evidence.

## Locale and accessibility matrix

The four custom intents require matching `en-US` device and Assistant language
settings. They must also be checked under a nonmatching locale to prove that
FocusHaven does not claim broader custom-intent availability. The
`OPEN_APP_FEATURE` route may be tested only in locales documented for that BII;
the seventeen reviewed Android string configurations do not expand Assistant
eligibility.

On each admitted route, the resulting review must be usable with TalkBack,
large text, and increased display size. Validation records the visible title,
review summary, privacy disclosure, separate dismiss and confirm controls,
focus order, announcement order, clipping result, and the fact that no action
has run. Screenshots or recordings must not contain private user content.

## Candidate identity

Device results qualify only one signed, installable candidate. Evidence must
bind the application ID, version name, version code, source commit, source tree,
artifact SHA-256, signing-certificate SHA-256, build type, device model,
Android version, Google app or Assistant version, test-tool version, device
locale, Assistant locale, and observation time. Credentials, keystore files,
private keys, access tokens, account identifiers, and device identifiers must
never enter Git or the evidence summary.

Debug or locally signed evidence cannot silently qualify a Play candidate.
Changing source, resources, versioning, signing identity, Assistant tooling, or
the tested artifact invalidates the affected evidence.

## Play and App Actions review boundary

Google documents App Actions review as separate from ordinary Android app
review. Before public availability, the release owner must separately verify:

- current App Actions terms in Play Console;
- an eligible internal or closed test path for unapproved actions;
- current App content, App access, privacy-policy, and Data safety answers;
- the exact uploaded artifact identity;
- the App Actions review status; and
- an explicit FocusHaven distribution authorization after all other launch
  gates pass.

An upload is not approval. App approval is not App Actions approval.
App Actions approval is not FocusHaven distribution authorization.

## Closed authority

Phase 217L performs no external validation. It creates no preview and accesses
no Google account, Android device, signing identity, Play Console, or provider.
It cannot settle an in-app review, mutate a timer or queue, execute a Haven
Action, deploy, publish, or distribute a build. Those operations require
separate, explicit authorization and their own immutable evidence.

Official Android references verified for this contract:

- [Google Assistant plugin for Android Studio](https://developer.android.com/develop/devices/assistant/test-tool)
- [Build App Actions](https://developer.android.com/develop/devices/assistant/get-started)
- [Custom intents](https://developer.android.com/develop/devices/assistant/custom-intents)
- [Built-in intents](https://developer.android.com/develop/devices/assistant/intents)
- [Prepare an app for Play review](https://support.google.com/googleplay/android-developer/answer/9859455)
