# Android system-assistant App Actions mapping review

Status: Phase 217J exact capability and fulfillment mapping reviewed; Phase
217K separately implements the source registration while Assistant preview,
execution, and release authority remain closed.

## Why this review exists

Phase 217I completed reviewed Android-native copy without choosing an App
Actions capability. Phase 217J records the smallest truthful mapping before a
later phase may create `shortcuts.xml`, query-pattern resources, manifest
metadata, or production fulfillment code. The machine-readable contract is
`docs/contracts/android_system_assistant_app_actions_mapping_v1.json`.

The review uses the current official Android App Actions contract. A capability
in `shortcuts.xml` maps either a supported built-in intent or a custom intent to
an explicit Android fulfillment. Built-in intents must match the app's actual
functionality. Custom intents require app-owned query patterns and currently
support user invocation only when both the device and Assistant use `en-US`.

## Exact five-route mapping

| FocusHaven route | Reviewed capability | Fulfillment action | Assistant input admitted to the FocusHaven request |
| --- | --- | --- | --- |
| `readTimerStatus` | `custom.actions.intent.REVIEW_FOCUS_TIMER_STATUS` | `com.focushaven.app.action.REVIEW_FOCUS_TIMER_STATUS` | None |
| `startFocusTimer` | `custom.actions.intent.REVIEW_START_FOCUS_TIMER` | `com.focushaven.app.action.REVIEW_START_FOCUS_TIMER` | None |
| `pauseTimer` | `custom.actions.intent.REVIEW_PAUSE_FOCUS_TIMER` | `com.focushaven.app.action.REVIEW_PAUSE_FOCUS_TIMER` | None |
| `resumeTimer` | `custom.actions.intent.REVIEW_RESUME_FOCUS_TIMER` | `com.focushaven.app.action.REVIEW_RESUME_FOCUS_TIMER` | None |
| `openFocusQueue` | `actions.intent.OPEN_APP_FEATURE` | `com.focushaven.app.action.REVIEW_OPEN_FOCUS_QUEUE` | None; the required constant `feature` inventory match is validated and discarded |

All five fulfillments target the existing `com.focushaven.app.MainActivity`.
A later resolver may translate only the exact Android action string into one
existing `HavenSystemAssistantAndroidRoute`. It must generate its own bounded
opaque invocation ID and submit only schema version, invocation ID, and route
kind to the existing Phase 217H process-memory slot.

`OPEN_APP_FEATURE` requires inline inventory for its `feature` field. The only
admissible inventory value is the public constant `focus_queue_review`. It may
select the hard-coded queue-review route, but it is not copied into the Phase
217H request. Unknown extras, altered feature values, URI data, arbitrary text,
durations, task values, and queue values fail closed.

## Why the timer routes are custom

The current built-in-intent catalog has no timer-control BII for third-party
focus apps. The health-and-fitness exercise BIIs do not describe FocusHaven's
timer review and must not be repurposed. `GET_THING` and `GET_ITEM_LIST` model
search or list retrieval, not a fresh timer-status review. Using any of those
BIIs would misstate the app's capability and violate the requirement that BIIs
be directly relevant to the app behavior they fulfill.

The four timer routes therefore use parameter-free custom intents. Their future
query-pattern arrays must contain only the corresponding reviewed English
invocation example. They cannot contain placeholders, synonyms inferred from
private content, durations, task names, or queue values.

## Honest locale boundary

Reviewed native labels and truthful result copy exist in seventeen Android
resource configurations. That does not expand Assistant's invocation support.
The four custom timer intents are eligible only for `en-US` under the current
platform contract. `OPEN_APP_FEATURE` currently lists en-US, en-GB, en-CA,
en-IN, en-BE, en-SG, en-AU, es-ES, and pt-BR for user invocation.

A future registration must not claim that all seventeen FocusHaven resource
locales are Assistant invocation locales. Unsupported locales retain ordinary
app launch and the complete in-app experience. Any platform locale expansion
requires a new source check, mapping review, test-tool preview, and release
evidence.

## Closed implementation and authority boundary

Phase 217J creates no `shortcuts.xml`, `app:queryPatterns`, string-array,
`android.app.shortcuts` manifest metadata, Jetpack Core dependency, deep link,
exported destination, capability, static shortcut, public App Action, or
request resolver. It does not contact Google, create an Assistant preview, or
submit a request.

Mapping approval is not registration or release approval. Before registration,
a later phase must implement the exact mapping, reject every unlisted action
and value, prove cold- and warm-launch behavior, and keep Assistant dialogue
separate from the visible in-app Confirm action. Official preview, real-device
TalkBack and large-text checks, supported-language checks, signed builds, Play
disclosure review, candidate validation, and explicit distribution
authorization remain separate gates.

Official references:

- [App Actions overview](https://developer.android.com/develop/devices/assistant/overview)
- [App Actions capability schema](https://developer.android.com/develop/devices/assistant/action-schema)
- [Custom intents](https://developer.android.com/develop/devices/assistant/custom-intents)
- [`OPEN_APP_FEATURE` built-in intent](https://developer.android.com/reference/app-actions/built-in-intents/common/open-app-feature)
- [Build App Actions and policy requirements](https://developer.android.com/develop/devices/assistant/get-started)
