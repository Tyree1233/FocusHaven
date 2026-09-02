# FocusHaven Spanish Human-Review Packet

Status: Phase 215G-C2A packet-builder preparation; no packet or human review
has started

## Purpose

Phase 215G-C2A prepares a deterministic, fail-closed way to turn the exact
structurally ready Spanish candidate into an isolated packet for a qualified
human reviewer. It does not generate that packet, assign or impersonate a
reviewer, approve any Spanish wording, or activate Spanish.

The future packet may contain only the locked, non-sensitive English catalog,
the locked isolated Spanish candidate, their localization descriptions and
placeholder schemas, the committed structural-audit evidence, and empty fields
for reviewer decisions. It must never contain tasks, journals, reflections,
transcripts, coaching conversations, account identities, calendar events,
purchase history, focus history, or other private runtime values.

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

## Isolated future output

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

Phase 215G-C2A prepares the builder only. The packet path must remain absent
until a separately guarded creation step verifies the committed C2A builder
and the exact C1B catalog locks.

## Packet schema

The future packet records:

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
