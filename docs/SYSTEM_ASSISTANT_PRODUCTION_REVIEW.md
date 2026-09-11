# System assistant production review gate

Status: Phase 217G availability-gated Apple review registration active on iOS
16 and later; all seventeen Flutter runtime catalogs and the app-level review
host are enabled, while execution, release, and Android registration remain
closed.

## Purpose

Phases 217A through 217C define five text-free request routes, convert one
valid request into one opaque two-minute review through the existing Haven
Action Engine, and render that review in an accessible one-shot card. Phase
217D locks the complete English presentation proposal and multilingual review
boundary, then integrates the independently approved copy into one app-level
production host without registering a native assistant.

The isolated proposal is
`localization/proposals/app_en_system_assistant_review.arb`. It contains
eleven public interface messages and eleven complete metadata records. It
remains the immutable review source rather than a Flutter runtime catalog. The
eleven approved messages now also exist in every runtime locale.

## Complete-copy contract

Every production locale must independently review complete strings for:

- the system-assistant eyebrow and review title;
- the supported-source disclosure and explicit statement that FocusHaven has
  not acted;
- the text-free privacy boundary;
- the exact two-minute lifetime and stale timer-or-queue rejection;
- the mandatory in-app confirmation boundary;
- separate informational and reversible-control risk explanations;
- one complete screen-reader summary;
- a dismiss-request action; and
- a confirm-action button whose label exactly matches the confirmation
  disclosure.

The semantic summary owns exactly three placeholders: `interpretation`,
`effect`, and `risk`. Translators may reorder those values as their language
requires, but placeholder names, counts, and types must remain exact. The
production adapter must not assemble a sentence from translated fragments.

## Privacy and truthfulness

The proposal says only what the five-route contract guarantees. A native
adapter may pass the schema version, one bounded opaque request ID, and one
allowlisted action kind. It cannot pass a transcript, utterance, task title,
journal, reflection, coaching history, account value, or free-form parameter.

The source disclosure does not claim Siri, App Intents, Shortcuts, or Android
App Actions are currently available. The copy remains a proposal until a
separately reviewed native adapter exists. No request can execute from a
spoken acknowledgement, timeout, notification action, background callback,
or system-assistant success response.

## Production placement and lifecycle

The production host presents one app-level review above the current FocusHaven
route so all five allowlisted actions can be reviewed without depending on a
particular screen. It receives a text-free request through one memory-only
inbox, prepares it through `HavenSystemIntentService`, receives an opaque
`HavenSystemIntentReview` from its one issuing
`HavenSystemIntentReviewService`, supplies complete reviewed locale copy, and
returns the exact review to only the selected dismiss or confirm callback.

The host disappears when the review is dismissed, confirmed, superseded,
expired, or invalidated by owner state. It may not automatically confirm,
stack reviews, restore a consumed review, infer consent, or expose the private
proposal. The inbox persists nothing and rejects a second request while one is
pending. No production native producer is registered in this phase.

## Required review sequence

1. Lock the English proposal and all existing runtime-catalog digests.
2. Prepare only the eleven-message delta for each of the fifteen non-English
   production languages.
3. Require one complete independent fluent review per language. Machine output
   cannot approve a row.
4. Derive base `pt` only from the completely approved `pt-BR` delta.
5. Merge all complete approved deltas into the seventeen runtime catalogs in
   one separately verified integration. Completed in Phase 217D.
6. Generate localization and verify placeholder, semantics, large-text,
   narrow-layout, stale-state, replay, and one-shot behavior. Completed in
   Phase 217D.
7. Add one production host only after the localized integration is complete.
   Completed in Phase 217D with no native producer.
8. Review Apple and Android native adapters separately; neither platform
   receives authority from copy approval.

## Incremental delta-review foundation

The external incremental-review manifest locks the exact eleven-message
English proposal, the current digest of every one of the fifteen target runtime
catalogs, and the current base Portuguese fallback. It reuses
`tool/localization_incremental_review.dart`; no system-assistant-specific
translation or workbook engine is added. Japanese and Korean retain their
explicit font-coverage gates, and base `pt` remains a mechanical derivative of
the completely approved `pt-BR` delta rather than a sixteenth review.

The committed preflight may read those locked public files and report only
aggregate counts. `prepare` may turn separately supplied private draft bundles
into one private review CSV per language, and `accept` may write private
approved deltas only after every row in that language has one immutable fluent
decision. One language cannot approve another, a partial set cannot authorize
integration, and neither machine output nor a workbook formula can approve a
row.

The foundation itself created no provider configuration, glossary, machine
draft, real workbook, review, approval, runtime merge, generated localization,
or production consumer. The subsequent reviewed integration accepted all 165
fluent decisions, derived base Portuguese only from approved Brazilian
Portuguese, merged eleven complete messages into all seventeen catalogs, and
connected the app-level host. Provider and review artifacts remain private and
unchanged.

## Authority boundary

The reviewed copy grants no timer, queue, navigation, persistence, provider,
network, AI, deployment, publication, or phone authority. The integration
changes no dependency, permission, entitlement, manifest, deep link, or
platform file. The Phase 217B bridge and Haven Action Engine remain the only
path that can settle a fresh, explicitly confirmed review. Phase 217G App
Intents and Shortcuts can only submit into that review path; Android App Actions
remain unregistered.

Phase 217E adds only the private Apple delivery seam described in
`APPLE_SYSTEM_ASSISTANT_INGRESS_REVIEW.md`. Its exact three-field payload may
enter the existing memory inbox, but no Siri or Shortcuts capability is
declared and no unreviewed native copy is exposed. Public Apple registration,
native-copy localization, real-device acceptance, signed release validation,
store review, and distribution remain separate gates. Android is unchanged.

Phase 217F locks that Apple-native copy as a separate twenty-eight-message
English proposal and fifteen-language incremental-review manifest. It remains
outside every Flutter runtime catalog. The five
invocation phrases use only the `applicationName` placeholder; all native
outcomes preserve the truth that submission is not confirmation and no action
has run. Approval may later authorize an exact Apple string-catalog transform,
but cannot register an App Intent, publish a Shortcut, add a Siri entitlement,
execute a Haven Action, authorize Android, or release a build.

All fifteen approvals now authorize exactly that closed transform. The
Runner-local String Catalog contains the reviewed values plus base Portuguese
derived from approved Brazilian Portuguese, and a typed accessor maps the five
routes without calling the native store or Flutter transport. It adds no App
Intent, Shortcut provider, entitlement, request submission, confirmation, or
execution authority.

Phase 217G separately adds availability-gated Apple entry points for those five
reviewed routes on iOS 16 and later. Each App Intent has no parameters, requires
authentication, opens FocusHaven, and may submit only the existing schema
version, opaque invocation ID, and route kind to the one-slot process-memory
ingress. A native result reports only ready for review, pending review, or
unavailable. It never confirms the review or claims that a timer or queue action
happened.

The iOS 15 deployment target remains unchanged. No Siri entitlement, deep link,
third-party dependency, Android registration, persistence, timer/queue owner,
or Haven Action execution call is added. Real-device Siri, Shortcuts, VoiceOver,
large-text, signed-release, store-review, candidate, and distribution gates
remain closed.
