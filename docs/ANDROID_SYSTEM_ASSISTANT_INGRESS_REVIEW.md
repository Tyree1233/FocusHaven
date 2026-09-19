# Android system-assistant ingress review gate

Status: Phase 217H private Android-to-Flutter ingress active, Phase 217I
reviewed Android-native resource catalog integrated, and Phase 217J exact App
Actions mapping reviewed. Phase 217K registration resources are retained, but
the first-release cleanup detaches their launcher manifest reference. External
Google Assistant/Gemini invocation is deferred; retained direct intent handling
still ends at in-app review. Historical checkpoint descriptions below are not
claims of current provider availability or release approval. See
[the first-release scope](ANDROID_EXTERNAL_ASSISTANT_RELEASE_SCOPE.md).

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

## Phase 217J exact mapping review

Phase 217J completes only the first mapping decision above. Four timer routes
use parameter-free custom intents because the current built-in-intent catalog
has no truthful third-party timer BII. Health-and-fitness exercise BIIs and
search or list BIIs are explicitly rejected. The queue route alone maps to
`actions.intent.OPEN_APP_FEATURE`; its required `feature` inventory value is
one public constant used only for matching and is discarded before the
existing three-field request is constructed.

The custom-intent invocation boundary is honestly limited to `en-US` under the
current Android contract. The queue BII has its own narrower documented locale
set. Seventeen reviewed native resource configurations do not imply seventeen
Assistant invocation locales.

The exact mapping is recorded in
`ANDROID_SYSTEM_ASSISTANT_APP_ACTIONS_MAPPING_REVIEW.md` and its machine-readable
contract. This review creates no `shortcuts.xml`, query-pattern resource,
manifest metadata, dependency, resolver, App Action, Assistant preview, request
submission, or execution path. Public registration remains a separate phase.

## Phase 217I reviewed native-resource catalog

Phase 217I isolates twenty-eight complete messages in one English proposal:
collection and discovery copy, privacy and no-parameter summaries, one review
instruction, five short labels, five long labels, five invocation examples,
six truthful outcomes, and two TalkBack labels. The proposal contains no
placeholder or parameter, and its keys remain outside every Flutter runtime
catalog.

Fifteen independent fluent reviews are required, with explicit Japanese and
Korean font-coverage gates and later base-Portuguese derivation only from an
approved Brazilian-Portuguese delta. Runtime-catalog digests are freshness
locks rather than copy destinations. Provider-assisted drafts remain a
separately authorized private operation.

Following all fifteen independent approvals, the exact twenty-eight values now
exist in seventeen isolated Android resource files: English, fifteen reviewed
locales, and one base-Portuguese fallback copied mechanically from reviewed
Brazilian Portuguese. Indonesian review provenance remains `id` while the
Android resource qualifier is `values-in`. A typed Kotlin accessor owns only
fail-closed resource lookup and the exact five-route label mapping.

The resource catalog adds no `shortcuts.xml`, capability, built-in or custom
intent, query pattern, fulfillment, static shortcut, manifest metadata, deep
link, permission, dependency, request submission, or production registration.
Copy approval and resource integration cannot authorize public registration, Assistant
preview, request execution, signed release, Play distribution, or phone access.

## Phase 217K exact registration result

Phase 217K implements the Phase 217J mapping through one launcher-referenced
`shortcuts.xml`, four en-US-only custom query arrays, one constant queue
inventory, AndroidX Core, and one fail-closed Kotlin resolver. Cold and warm
activity launches can submit only the existing five text-free routes into the
same single process-memory slot.

Timer fulfillments reject every extra. Queue fulfillment requires exactly one
`feature=focus_queue_review` value and discards it before request construction.
Unknown actions, extra inputs, URI data, `ClipData`, selectors, missing copy,
and malformed IDs fail closed. Recognized intents are replaced after
resolution so activity recreation cannot replay them.

Registration and request submission now exist in source, but confirmation and
execution remain closed. No native path reads or changes timer or queue state.
Assistant preview, real-device checks, signing, Play review, candidate
validation, and distribution remain separate gates.
