# System assistant production review gate

Status: Phase 217D English copy and incremental-review foundation locked;
every runtime catalog, production host, and native system-assistant adapter
remains disabled.

## Purpose

Phases 217A through 217C define five text-free request routes, convert one
valid request into one opaque two-minute review through the existing Haven
Action Engine, and render that review in an accessible one-shot card. Phase
217D locks the complete English presentation proposal and the multilingual
review boundary without making that card reachable from production.

The isolated proposal is
`localization/proposals/app_en_system_assistant_review.arb`. It contains
eleven public interface messages and eleven complete metadata records. It is
not a Flutter runtime catalog, and no runtime localization generator reads it.

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

## Closed production placement

Phase 217D does not choose or implement a production host. A later host must
present one app-level review above the current FocusHaven route so all five
allowlisted actions can be reviewed without depending on a particular screen.
It must receive an opaque `HavenSystemIntentReview` from the one issuing
`HavenSystemIntentReviewService`, supply complete reviewed locale copy, and
return the exact review to only the selected dismiss or confirm callback.

The host must disappear when the review is dismissed, confirmed, superseded,
expired, or invalidated by owner state. It may not automatically confirm,
stack reviews, restore a consumed review, infer consent, or expose the private
proposal. Production hosting remains closed until all language and integration
gates pass.

## Required review sequence

1. Lock the English proposal and all existing runtime-catalog digests.
2. Prepare only the eleven-message delta for each of the fifteen non-English
   production languages.
3. Require one complete independent fluent review per language. Machine output
   cannot approve a row.
4. Derive base `pt` only from the completely approved `pt-BR` delta.
5. Merge all complete approved deltas into the seventeen runtime catalogs in
   one separately verified integration.
6. Generate localization and verify placeholder, semantics, large-text,
   narrow-layout, stale-state, replay, and one-shot behavior.
7. Add one production host only after the localized integration is complete.
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

This foundation creates no provider configuration, glossary, machine draft,
real workbook, review, approval, runtime merge, generated localization, or
production consumer. Any Google-assisted draft run requires separate explicit
authorization. All fifteen complete approvals and the derived Portuguese
fallback must pass a later atomic catalog-integration phase before the card can
receive production copy.

## Authority boundary

This proposal contains only public interface copy. It grants no timer, queue,
navigation, persistence, provider, network, AI, system-assistant, deployment,
publication, or phone authority. It changes no runtime catalog, dependency,
permission, entitlement, manifest, deep link, or platform file. The Phase
217B bridge and Haven Action Engine remain the only path that can settle a
fresh, explicitly confirmed review.
