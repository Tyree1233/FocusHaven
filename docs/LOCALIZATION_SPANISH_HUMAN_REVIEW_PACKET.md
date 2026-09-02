# FocusHaven Spanish Human-Review Packet

Status: Phase 215G-C2B packet created and audited; reviewer assignment and
human review have not started

## Purpose

Phase 215G-C2A prepares a deterministic, fail-closed way to turn the exact
structurally ready Spanish candidate into an isolated packet for a qualified
human reviewer. It does not generate that packet, assign or impersonate a
reviewer, approve any Spanish wording, or activate Spanish.

Phase 215G-C2B separately creates and audits that isolated packet without
assigning it or starting review. Packet creation is evidence preparation, not
a reviewer judgment, linguistic approval, runtime activation, or release
qualification.

The packet contains only the locked, non-sensitive English catalog, the locked
isolated Spanish candidate, their localization descriptions and placeholder
schemas, the committed structural-audit evidence, and empty fields for reviewer
decisions. It must never contain tasks, journals, reflections, transcripts,
coaching conversations, account identities, calendar events, purchase history,
focus history, or other private runtime values.

## Exact locked inputs

| Input | Required value |
| --- | --- |
| English catalog | `lib/l10n/app_en.arb` |
| English SHA-256 | `ba6e97b200060f211d3e0d73276e1132e03c8de18ac0778d38c356abe9874e87` |
| English message count | 980 |
| Placeholder-bearing message count | 148 |
| Spanish candidate | `localization/candidates/app_es.arb` |
| Spanish SHA-256 | `611d1afcc6eb688f92d56928f08cad5dbfdef2b5031c537c53615accfb16b83f` |
| Structural audit | `localization/reviews/es/structural-audit.json` |
| Required structural state | `structurally_ready` |

The builder refuses a changed path, digest, locale, structural state, reviewer
state, private-data boundary, output path, or existing output. It reruns the
complete catalog parity, metadata, placeholder-schema, ICU-placeholder,
non-empty, and source-equal-invariant audit before writing anything.

## Isolated packet output

The only allowed output is:

```text
localization/reviews/es/packets/review-packet.json
```

The packet remains review evidence outside `lib/l10n`. Its existence will not
change `supportedLocales`, the locale registry, a saved language, native
resources, voice recognition, coaching behavior, a store listing, or country
availability.

Spanish remains outside `lib/l10n`, planned, and runtime inactive throughout
packet preparation.

At the Phase 215G-C2A checkpoint, no packet or human review has started. That
phase does not generate that packet, assign or impersonate a reviewer, or
approve Spanish. Phase 215G-C2B separately verifies the committed C2A builder
and exact C1B catalog locks, then creates only the isolated packet above.

The created packet is 884,241 bytes with SHA-256
`325231a14ff0dfe2b176f6267996292aa0575b5db16d3c084cf453bf5f75737e`.
Its existence does not assign it, start human review, or change the
`structurally_ready` qualification state.

## Packet schema

The packet records:

- schema version, phase, locale, general-international-Spanish scope, and exact
  source, candidate, and structural-audit locks;
- all 980 English and Spanish message pairs and their catalog descriptions;
- the exact placeholder names for each of the 148 placeholder-bearing
  messages;
- deterministic risk categories and a critical, elevated, then standard
  review order;
- batches of no more than 50 entries so review can be checked and resumed
  without implying that partial work approves the catalog;
- explicit checks appropriate to each risk category; and
- `pending` entries whose reviewer decision, replacement, and notes remain
  null.

The packet-level fields must remain:

```text
packetStatus: ready_for_reviewer_assignment
reviewStarted: false
assignedReviewer: null
reviewerQualification: null
linguisticallyApproved: false
runtimeActivated: false
externalTranslationProviderUsed: false
privateRuntimeDataIncluded: false
```

## Deterministic risk categories

Critical entries appear first when their key, English copy, or catalog context
concerns:

- account deletion, local or cloud data, backup, restore, export, or
  irreversible actions;
- purchases, subscriptions, prices, entitlements, or purchase restoration;
- microphone, speech recognition, notification, calendar, Focus Shield, or
  other permission and system-access boundaries;
- safety, crisis, urgent-care, medical, or professional-help wording;
- privacy, journals, reflections, transcripts, Enhanced AI, Focus Coach, or
  other local-versus-remote coaching boundaries; or
- explicit review, confirmation, replay, stale-state, execution, or
  destructive-action language.

Elevated entries follow when they concern:

- advisory or uncertainty language for Forecast, Rhythm, Planner, Journey,
  Haven Window, Smart Reset, or other user-agency boundaries;
- accessibility, semantic labels, tooltips, and controls;
- placeholders, plurals, selects, or grammatical agreement with runtime
  values; or
- one of the 11 source-equal invariants whose rationale must still be confirmed
  by the human reviewer.

All other product copy is standard risk. Standard does not mean preapproved;
every message still requires qualified human review.

## Phase 215G-C2B audit checkpoint

| Field | Audited value |
| --- | --- |
| Packet SHA-256 | `325231a14ff0dfe2b176f6267996292aa0575b5db16d3c084cf453bf5f75737e` |
| Packet size | 884,241 bytes |
| Messages | 980 |
| Placeholder-bearing messages | 148 |
| Source-equal invariants | 11 |
| Risk counts | 433 critical, 251 elevated, 296 standard |
| Batches | 20, with at most 50 entries each |
| Pending decisions | 980 |
| Completed decisions | 0 |

## Reviewer decisions

Packet preparation cannot supply reviewer judgments. For every message a real
reviewer must later choose an explicit decision such as accept, revise, or
block; record any replacement and notes; and complete all required checks.
Automation must never fill these fields, infer acceptance from an empty field,
or convert partial review into whole-catalog approval.

A future reviewer assignment must separately record the real qualified
reviewer's name, qualification, accepted regional scope, packet digest, source
and candidate digests, assignment time, and conflict-of-interest or
independence statement.
Until that happens, the qualification record remains `structurally_ready`, its
reviewer fields remain null, and `reviewStarted` remains false.

## Phase 215G-C2A non-actions

This phase does not create or distribute a review packet, contact a reviewer or
translation provider, claim that the machine-assisted Spanish wording is
correct, begin human review, record a reviewer identity, approve a term or
message, copy Spanish into `lib/l10n`, change runtime locale support, qualify
voice or coaching, localize native or store surfaces, add a permission or
dependency, deploy, upload, invoke, or make a public language or country claim.

## Phase 215G-C2B non-actions

This phase does not distribute or assign the packet, contact or impersonate a
reviewer, begin human review, fill or infer a reviewer decision, approve a term
or message, change the `structurally_ready` status, copy Spanish into
`lib/l10n`, activate a locale, qualify voice or coaching, localize native or
store surfaces, contact a translation provider, use private runtime data, add a
permission or dependency, deploy, upload, invoke, or make a public language or
country claim.
