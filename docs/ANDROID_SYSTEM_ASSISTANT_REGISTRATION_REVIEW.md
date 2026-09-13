# Android system-assistant App Actions registration review

Status: Phase 217K exact registration source and fail-closed fulfillment are
implemented locally; Assistant preview, device validation, signing, Play
review, distribution, review settlement, and Haven Action execution remain
closed. Phase 217L now locks their required validation evidence without
performing an external operation.

## What is registered in source

The launcher activity references one `res/xml/shortcuts.xml` resource. It
declares exactly the five capabilities approved in Phase 217J:

- four distinct, parameter-free custom intents for timer-status, start, pause,
  and resume review; and
- one `actions.intent.OPEN_APP_FEATURE` capability for Focus Queue review.

All fulfillments explicitly target `com.focushaven.app.MainActivity`. The four
custom intents reference one query pattern each from the default `values`
configuration, which Android's resource linker requires because the base
`shortcuts.xml` references those arrays. The separate registration contract
still limits custom-intent eligibility to matching `en-US` device and
Assistant locales. Reviewed native labels in seventeen Android configurations
do not claim seventeen Assistant invocation locales.

The queue capability has exactly one inline-inventory entity. Its public
shortcut ID is `focus_queue_review`; its reviewed short and long labels come
from the existing Android-native catalog. No duration, task, queue item,
transcript, utterance, or private value appears in the capability definition.

## Fail-closed fulfillment

`HavenSystemAssistantAndroidAppActionResolver` recognizes only the five exact
reviewed Android action strings. Timer actions require an empty extras map. The
queue action requires exactly one `feature` extra equal to
`focus_queue_review`. That inventory value selects the hard-coded route and is
discarded before request creation.

Unknown actions, additional extras, changed feature values, URI data,
`ClipData`, selectors, missing reviewed copy, and malformed generated
invocation IDs all fail without changing the native pending slot. An occupied
slot is preserved. A successful fulfillment writes only schema version `1`, a
bounded opaque invocation ID, and one allowlisted route kind into the existing
single process-memory slot.

Cold and warm activity delivery use the same resolver. After one recognized
fulfillment attempt, `MainActivity` replaces the retained activity intent with
a neutral package-scoped launch intent so activity recreation cannot replay
the public fulfillment. Delivery still terminates at the Phase 217D in-app
review. Native submission is not the visible **Confirm action** and grants no
timer, queue, or Haven Action authority.

## Dependency and permission boundary

The implementation adds `androidx.core:core:1.17.0`, satisfying the Android
Shortcuts capability requirement. It adds no permission, deep link, exported
component, background service, persistence, network request, provider, or AI
dependency. The existing `MainActivity` remains the only fulfillment target.

## Closed release gates

Source registration is not distribution authorization. This phase creates no
App Actions test-tool preview, Google request, signed candidate, Play Console
upload, phone interaction, production rollout, or store disclosure answer.
Real-device Assistant behavior, TalkBack, large text, cold/warm launches,
supported locales, rejection cases, signed builds, Play disclosures,
candidate validation, and explicit distribution authorization remain separate
required gates.

Phase 217L enumerates those gates in
`docs/contracts/android_system_assistant_candidate_validation_v1.json`. The
contract requires the exact five-route cold/warm matrix, neutral-intent replay
rejection, the complete negative-input set, honest custom-intent and BII locale
checks, accessibility results, signed-artifact identity, current Play
disclosures, separate App Actions review status, and explicit distribution
authorization. It is not itself preview, device, signing, upload, approval, or
release evidence.

Official Android references checked for this implementation:

- [Create shortcuts.xml](https://developer.android.com/develop/devices/assistant/action-schema)
- [Custom intents](https://developer.android.com/develop/devices/assistant/custom-intents)
- [OPEN_APP_FEATURE](https://developer.android.com/reference/app-actions/built-in-intents/common/open-app-feature)
- [Build App Actions](https://developer.android.com/develop/devices/assistant/get-started)
