# FocusHaven Translation Qualification

Status: Phase 215G-C2B review packet created and audited; no reviewer, human
review, or translated locale is active
Source checkpoint: `fed1c9a2e6096d86f76bc458d4ccc47870f6e0fc`
First candidate locale: Spanish (`es`), planned and inactive

## Purpose

Phase 215G-B completed the English Flutter extraction. Phase 215G-C now needs a
repeatable way to accept, review, and qualify a translation without allowing an
unfinished catalog to become runtime or store-visible support.

Phase 215G-C0 establishes that boundary. It does not translate or activate a
language. Spanish remains planned and inactive. French, German, and Brazilian
Portuguese remain later members of the planned first wave.

Phase 215G-C1A adds the deterministic candidate builder and controlled input
contract described in `docs/LOCALIZATION_SPANISH_CANDIDATE_PREPARATION.md`.
It still creates no translation bundle or Spanish candidate. The builder is a
fail-closed preparation mechanism, not a translation or approval authority.

Phase 215G-C1B uses that builder with the authorized machine-assisted draft of
the locked, non-sensitive catalog. The complete candidate now exists only at
`localization/candidates/app_es.arb`; both the builder audit and an independent
audit report it structurally ready for human review. No qualified human review
has started, and Spanish remains planned and inactive.

Phase 215G-C2A prepares a deterministic builder for a future isolated human
review packet. It is locked to the exact C1B source, candidate, and structural
audit; preserves descriptions and placeholder schemas; classifies high-risk
copy; creates batches no larger than 50 entries; and leaves reviewer decisions
empty. The preparation phase does not create the packet or change the
`structurally_ready` qualification state.

Phase 215G-C2B uses the exact committed C2A builder to create and independently
audit the isolated packet. The 884,241-byte packet has SHA-256
`325231a14ff0dfe2b176f6267996292aa0575b5db16d3c084cf453bf5f75737e`,
contains all 980 locked message pairs in 20 critical-first batches, and leaves
all 980 reviewer decisions empty. The packet remains unassigned, review has not
started, and the qualification state remains `structurally_ready`.

## Locked English source

The Spanish intake starts from the exact English source below:

| Field | Locked value |
| --- | --- |
| Git commit | `fed1c9a2e6096d86f76bc458d4ccc47870f6e0fc` |
| Catalog | `lib/l10n/app_en.arb` |
| SHA-256 | `ba6e97b200060f211d3e0d73276e1132e03c8de18ac0778d38c356abe9874e87` |
| Messages | 980 |
| Messages with placeholders | 148 |

If English copy changes after translation starts, the candidate must be
rebased deliberately. A reviewer must see the added, removed, and changed keys;
the source checkpoint must never move silently.

## Candidate isolation

Before approval, candidate catalogs remain outside `lib/l10n`. The Spanish
candidate now exists at `localization/candidates/app_es.arb` with SHA-256
`611d1afcc6eb688f92d56928f08cad5dbfdef2b5031c537c53615accfb16b83f`.

This isolation is intentional. Flutter discovers ARB catalogs in `lib/l10n`
and generates locale delegates from them. Moving an unfinished candidate there
would create production-shaped runtime support before qualification. Only
`lib/l10n/app_en.arb` may remain in the production catalog directory until an
explicit activation phase passes.

## Structural audit

`tool/localization_catalog_qualification.dart` compares a candidate against the
English source. It fails closed when it finds:

- an unexpected source or candidate locale;
- a missing or extra message key;
- missing message metadata or descriptions;
- a changed placeholder name, type, format, or placeholder schema;
- a placeholder used differently in ICU message syntax;
- an empty translation; or
- source-equal text that has not been explicitly reviewed as an invariant.

An approved source-equal allowlist is for brand names or genuinely invariant
tokens only. Every allowlisted key still requires a reviewer decision; the
auditor never assumes that matching English text is correct.

The independent candidate command used by Phase 215G-C1B was:

```bash
dart run tool/localization_catalog_qualification.dart \
  lib/l10n/app_en.arb \
  localization/candidates/app_es.arb \
  es \
  appTitle durationMinutesShort havenWindowHeldSameDay \
  havenWindowHeldMultiDay accountPro proTitle journalMoodCount \
  reminderDaySeparator reminderTimeAndDays timerServiceExportSessionRow \
  havenPlanServiceExplanationWithDetails
```

The command producing a zero exit status means only that a candidate is
structurally ready to enter human review.

## Human linguistic review

A structurally complete candidate is not an approved translation. A qualified
human reviewer must assess every message in context, including:

- calm, non-punitive FocusHaven tone;
- safety, care, uncertainty, privacy, and agency boundaries;
- authentication, purchase, restore, deletion, and destructive actions;
- permission, notification, account, and error language;
- plural categories, gender-neutral language, dates, times, counts, and
  durations;
- placeholders embedded in natural sentences;
- accessibility labels, hints, semantics, and screen-reader phrasing;
- narrow layouts, large text, overflow, and keyboard or assistive navigation;
- consistency with the reviewed terminology worksheet; and
- any source-equal brand or technical term.

The reviewer identity, scope, source checkpoint, completion time, unresolved
issues, and approval decision must be recorded. Empty reviewer fields or a
status other than explicit approval cannot authorize runtime integration.

## Privacy boundary

Tasks, journal entries, reflections, transcripts, coaching conversations,
account identities, and other private runtime values are not translation
source material. They remain opaque placeholders supplied only while the app
runs. They must never be copied into a candidate catalog, terminology sheet,
review ticket, translation prompt, or external provider.

Phase 215G-C0 contacts no machine-translation or human-translation provider.
Future provider use, if any, requires a separately approved data boundary and
may receive only the non-sensitive source catalog. Machine output never counts
as human approval.

## Qualification states

The Spanish review record began with `status: not_started` and
`candidatePresent: false`. Phase 215G-C1B advances it only to
`status: structurally_ready` and `candidatePresent: true`. Future state changes
must remain explicit:

1. `not_started` — no candidate exists.
2. `drafting` — a candidate exists outside `lib/l10n` and is incomplete.
3. `structurally_ready` — the catalog auditor passes.
4. `human_review` — a qualified reviewer is evaluating the complete candidate.
5. `approved_for_runtime_integration` — linguistic approval is recorded, but
   the locale is still not active.
6. `runtime_qualified` — a later phase has passed Flutter generation, complete
   tests, layout, accessibility, fallback, and language-selection gates.
7. `release_qualified` — native, policy, support, store, screenshot, signed
   build, and country evidence also pass.

No single state silently implies the next one.

## Remaining gates

Phase 215G-C1A prepares the isolated builder without creating a candidate.
Phase 215G-C1B creates and structurally audits the complete Spanish candidate
against the locked English source after explicit authorization of the local
machine-assisted draft boundary. Human approval remains separate from catalog
generation and has not started.

Phase 215G-C2A prepares the locked review-packet builder only. Phase 215G-C2B
creates and digests the isolated packet without assigning it or starting
review. A later explicit assignment must identify a real qualified reviewer
before `status: human_review` or `reviewStarted: true` can be recorded. Packet
preparation, packet creation, reviewer assignment, completed linguistic
approval, runtime integration, and release qualification are separate states.

Voice and coaching qualification remains Phase 215G-D. Spanish UI copy alone
does not authorize Spanish speech recognition, safe-command interpretation,
Local Coach understanding, Enhanced AI behavior, or an implicit English
fallback for private text.

Native and store qualification remains Phase 215G-E. Spanish UI copy alone
does not localize iOS, Android, widgets, watches, permission-purpose text,
privacy policies, support content, store listings, screenshots, or any country
release.

## Phase 215G-C1B non-actions

This phase does not approve the Spanish ARB candidate, activate a locale,
change `supportedLocales`, add a saved language, translate private content,
contact a provider, add a dependency or permission, change Firebase or an app
store, deploy, upload, or make a language or country availability claim.

## Phase 215G-C2A non-actions

This phase does not create or distribute a review packet, assign or impersonate
a reviewer, begin human review, record a reviewer identity, approve Spanish,
change the `structurally_ready` status, copy the candidate into `lib/l10n`,
activate a locale, translate private content, contact a provider, add a
dependency or permission, change Firebase or an app store, deploy, upload, or
make a language or country availability claim.

## Phase 215G-C2B non-actions

This phase does not distribute or assign the packet, contact or impersonate a
reviewer, begin human review, record a reviewer identity, fill or infer a
reviewer decision, approve Spanish, change the `structurally_ready` status,
copy the candidate into `lib/l10n`, activate a locale, translate private
content, contact a provider, add a dependency or permission, change Firebase
or an app store, deploy, upload, or make a language or country availability
claim.
