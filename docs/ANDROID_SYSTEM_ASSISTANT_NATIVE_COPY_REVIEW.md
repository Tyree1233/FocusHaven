# Android system-assistant native copy review gate

Status: Phase 217I English Android-native copy and fifteen-language review
foundation prepared; runtime resources, public App Actions registration,
execution, and release authority remain closed.

## Purpose

Phase 217I isolates the complete English copy that a future Android
system-assistant surface may expose. It does not add the copy to Android
resources, `shortcuts.xml`, the application manifest, Google Assistant, or a
production consumer. The isolated source is
`localization/proposals/app_en_android_system_assistant_native_review.arb`.

The proposal contains exactly twenty-eight complete messages and twenty-eight
metadata records. It covers one collection title, one discovery description,
the privacy and no-parameter boundaries, one in-app review instruction, five
short labels, five long labels, five invocation examples, six truthful handoff
or failure outcomes, and two complete TalkBack labels.

## Five-route copy contract

The native proposal mirrors only the existing Phase 217A routes:

| Route | Short label | Required meaning |
| --- | --- | --- |
| `readTimerStatus` | Check Focus timer | Prepare a request to review current status; do not claim it was read. |
| `startFocusTimer` | Start Focus timer | Prepare the ready Focus session with no duration parameter. |
| `pauseTimer` | Pause Focus timer | Prepare pausing only the current Focus timer. |
| `resumeTimer` | Resume Focus timer | Prepare resuming only a paused Focus timer. |
| `openFocusQueue` | Open Focus Queue | Prepare opening Focus Queue without reading or editing queue content. |

Each long label and invocation example explicitly asks to review the route.
The complete proposal contains no placeholder. No label, example, result, or
accessibility message may introduce a duration, task, queue item, transcript,
utterance, or other free-form value.

## Android platform vocabulary boundary

Android App Actions register `capability` declarations in `shortcuts.xml`.
Static shortcuts may reference localized `shortcutShortLabel` and
`shortcutLongLabel` string resources. Built-in intents model supported user
queries without app-owned query-pattern resources; custom intents use separate
query-pattern arrays and are limited to `en-US` by the current Android
contract. Phase 217I therefore locks review-only invocation examples, not
`app:queryPatterns`, and does not select a built-in intent or custom intent.

Exact BII or custom-intent mapping, capability declarations, query-pattern
eligibility, fulfillment intents, app-launch behavior, and supported Assistant
locales require a separate Android registration review. Copy approval cannot
create or authorize those platform resources.

## Truthful handoff and failure copy

The successful native handoff says only that the person must open FocusHaven
to review the request and that nothing has happened yet. It does not say the
timer started, paused, resumed, or was read, and it does not say Focus Queue
opened. Assistant submission cannot become in-app confirmation.

The remaining complete outcomes cover:

- an already occupied single-request slot;
- an unavailable request or handoff;
- cancellation before confirmation;
- expiration before confirmation; and
- malformed, unsupported, or otherwise rejected input.

Every terminal failure denies mutation with either `Nothing changed` or an
explicit statement that FocusHaven did not change the timer or queue. The two
accessibility labels distinguish one request ready for review from another
request already waiting. They never announce success or imply consent.

## Privacy and parameter boundary

The native privacy summary matches the existing reviewed in-app disclosure:
only the action type and one private request code enter FocusHaven, and no
transcript or private content is included. The no-parameter summary separately
states that no time, task, or queue detail can be added.

The proposal contains no user, reviewer, account, device, credential, provider,
workbook, or private FocusHaven data. It grants no timer, queue, navigation,
review, confirmation, execution, persistence, provider, network, AI, phone,
deployment, publication, or distribution authority.

## Fifteen-language incremental review

The external manifest uses the existing bounded incremental-review workflow
for Spanish, French, German, Brazilian Portuguese, Japanese, Korean, Italian,
Polish, Dutch, Indonesian, Turkish, Swedish, Norwegian Bokmål, Danish, and
Finnish. Each language requires one complete independent fluent review of all
twenty-eight messages. Japanese and Korean retain explicit font-coverage gates.
Base Portuguese may be derived only from a completely approved Brazilian
Portuguese delta and is not a sixteenth independent review.

The locked Flutter runtime-catalog digests prove the exact active language set
and prevent a stale review foundation. They are input locks only. Android-native
copy must never be merged into the Flutter ARB runtime catalogs. Later approved
deltas may be transformed into Android string resources only by a separate,
verified integration phase with an exact key and placeholder-free mapping.

The existing private CSV and two-sheet Excel review helpers may be reused after
separately supplied draft bundles exist. The foundation itself creates no
provider configuration, glossary, translation request, draft, CSV, workbook,
review, approval, Android string resource, runtime catalog, or production
native consumer. Provider-assisted drafts require separate explicit
authorization.

## Placement and release boundary

The Phase 217I repository change may contain only this isolated proposal,
contract tests, and documentation. It adds no `res/values` string, string
array, `shortcuts.xml`, `android.app.shortcuts` manifest metadata, built-in or
custom intent, query pattern, static shortcut, fulfillment intent, deep link,
exported destination, dependency, permission, provider, or production copy
accessor. All twenty-eight keys remain absent from every Flutter runtime
catalog and Android resource file.

Before any public Android registration, a separately authorized phase must:

1. accept all fifteen independent reviews and derive base Portuguese only from
   approved Brazilian Portuguese;
2. map approved keys into localized Android resources without changing their
   meanings or introducing a parameter;
3. choose and verify exact capabilities and fulfillment mappings for the five
   review-only routes;
4. open FocusHaven for the existing visible review and never treat an
   Assistant acknowledgement as the in-app Confirm action;
5. prove occupied, unavailable, cancellation, expiry, rejection, cold-launch,
   warm-launch, replay, and process-termination behavior;
6. complete official Assistant preview plus real-device TalkBack, large-text,
   and supported-language checks; and
7. complete fresh signed builds, privacy and Play-disclosure review, candidate
   validation, and explicit distribution authorization before release.

Apple registration cannot authorize Android registration. Copy approval alone
grants no App Action, shortcut, Assistant, timer, queue, confirmation,
execution, publication, or distribution authority.
