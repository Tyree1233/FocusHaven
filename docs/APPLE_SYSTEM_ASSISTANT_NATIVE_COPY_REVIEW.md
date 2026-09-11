# Apple system-assistant native copy review gate

Status: Phase 217F fifteen-language review accepted and reviewed Apple String
Catalog integration active; public Siri, App Intent, and App Shortcut
registration disabled.

## Purpose

The Phase 217F copy-lock foundation isolates the complete English copy that a
future Apple system-assistant adapter may expose. It did not add that copy to
Runner, an Apple String Catalog, Siri, Shortcuts, or a production consumer. The
reviewed integration described below now maps the approved values into a
Runner-local catalog without registering an adapter. The isolated English
source remains
`localization/proposals/app_en_apple_system_assistant_native_review.arb`.

The proposal contains exactly twenty-eight complete messages and twenty-eight
metadata records. It covers one collection title, one discovery description,
the privacy and no-parameter boundaries, one in-app review instruction, five
route titles, five route descriptions, five invocation phrases, six truthful
handoff or failure outcomes, and two complete accessibility labels.

## Five-route copy contract

The native proposal mirrors only the existing Phase 217A routes:

| Route | Title | Required meaning |
| --- | --- | --- |
| `readTimerStatus` | Check Focus timer status | Prepare a request to review current status; do not claim it was read. |
| `startFocusTimer` | Start Focus timer | Prepare the ready Focus session with no duration parameter. |
| `pauseTimer` | Pause Focus timer | Prepare pausing only the current Focus timer. |
| `resumeTimer` | Resume Focus timer | Prepare resuming only a paused Focus timer. |
| `openFocusQueue` | Open Focus Queue | Prepare opening Focus Queue without reading or editing queue content. |

Each invocation phrase explicitly asks to **review** the route in FocusHaven.
The five phrase messages each contain exactly one `applicationName` string
placeholder. Translators may place that placeholder where their language
requires, but they may not rename, duplicate, remove, translate, or replace it.
No title, description, phrase, result, or accessibility label may introduce a
duration, task, queue item, transcript, utterance, or other free-form value.

## Truthful handoff and failure copy

The successful native handoff says only that the person must open FocusHaven
to review the request and that nothing has happened yet. It does not say the
timer started, paused, resumed, or was read, and it does not say Focus Queue
opened. Siri and Shortcuts cannot convert native submission into confirmation.

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
and prevent a stale review foundation. They are input locks only. Apple-native
copy must never be merged into the Flutter ARB runtime catalogs. Later approved
deltas may be transformed into an Apple string catalog only by a separate,
verified integration phase with an exact key and placeholder mapping.

The existing private CSV and two-sheet Excel review helpers may be reused after
separately supplied draft bundles exist. The foundation itself creates no
provider configuration, glossary, translation request, draft, CSV, workbook,
review, approval, Apple string catalog, runtime catalog, or production native
consumer. Provider-assisted drafts require separate explicit authorization.

## Reviewed catalog integration

All fifteen independent reviews are now complete: 420 decisions contain 189
accepted draft values, 231 fluent revisions, and zero blocked messages. The
anonymous private acceptance lock is the sole authority for the deterministic
catalog transform. Review workbooks, completed-review CSVs, validation records,
and provider responses remain outside Git.

`ios/Runner/AppleSystemAssistantNativeCopy.xcstrings` contains the exact
twenty-eight keys in English, the fifteen independently reviewed locales, and
one base-Portuguese fallback derived only from approved Brazilian Portuguese.
The transform replaces the five reviewed `{applicationName}` placeholders with
Apple's single `%@` format token and rejects any other placeholder or percent
shape. `HavenSystemAssistantAppleNativeCopy` exposes only typed, fail-closed
lookup and exact five-route key mapping. It cannot submit or deliver a request.

`localization/integrations/apple_system_assistant_native_copy_v1.json` records
the source proposal, acceptance-lock, approved-delta, catalog, locale,
placeholder, and decision-count provenance without translation text or
reviewer identity. Contract tests prove all seventeen Apple localizations,
exact `pt-BR`-to-`pt` derivation, complete key coverage, catalog compilation,
and continued separation from the seventeen Flutter runtime catalogs.

## Deliberately closed placement and release boundary

The original Phase 217F copy-lock commit contained no native catalog or
accessor. The reviewed catalog integration adds only those two copy resources
and their tests. It contains no App Intents framework import, `AppIntent`
conformance, App Shortcut provider, Siri entitlement, Siri usage description,
supported-intent declaration, deep link, dependency, Android resource, or
Android manifest change. All twenty-eight keys remain absent from every Flutter
runtime catalog and from every Runner source except the typed copy accessor.

A later Apple-only integration may proceed only after all fifteen reviews are
complete and must:

1. map approved keys into a localized Apple string catalog without changing
   their meaning or `applicationName` placeholder;
2. compile availability-gated App Intents only on supported Apple OS versions
   while preserving normal iOS 15 launch and app behavior;
3. submit only the existing three-field request to the Phase 217E memory slot;
4. open FocusHaven for the existing visible review and never treat a spoken or
   native acknowledgement as the in-app Confirm action;
5. prove occupied, unavailable, cancellation, expiry, rejection, cold-launch,
   warm-launch, replay, and process-termination behavior;
6. complete large-text, VoiceOver, Siri, and Shortcuts checks in every supported
   language on real devices;
7. complete fresh signed builds, privacy and store-disclosure review, candidate
   validation, and explicit distribution authorization.

Apple copy approval cannot authorize Android registration. Android App Actions
remain a separate later copy, adapter, review, test, and release gate.
