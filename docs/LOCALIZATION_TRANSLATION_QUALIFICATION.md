# FocusHaven Translation Qualification

Status: Phase 215G-C0 qualification foundation; no translated locale is active
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

Before approval, candidate catalogs remain outside `lib/l10n`. The planned
Spanish intake path is `localization/candidates/app_es.arb`; it does not exist
in Phase 215G-C0.

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

The future candidate command will be:

```bash
dart run tool/localization_catalog_qualification.dart \
  lib/l10n/app_en.arb \
  localization/candidates/app_es.arb \
  es \
  appTitle
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

The Spanish review record starts with `status: not_started` and
`candidatePresent: false`. Future state changes must be explicit:

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
Phase 215G-C1B will create and structurally audit the complete Spanish candidate
against the locked English source only after the translation-draft source and
data boundary are explicitly chosen. Human approval remains separate from
catalog generation.

Voice and coaching qualification remains Phase 215G-D. Spanish UI copy alone
does not authorize Spanish speech recognition, safe-command interpretation,
Local Coach understanding, Enhanced AI behavior, or an implicit English
fallback for private text.

Native and store qualification remains Phase 215G-E. Spanish UI copy alone
does not localize iOS, Android, widgets, watches, permission-purpose text,
privacy policies, support content, store listings, screenshots, or any country
release.

## Phase 215G-C0 non-actions

This foundation does not create a Spanish ARB candidate, activate a locale,
change `supportedLocales`, add a saved language, translate private content,
contact a provider, add a dependency or permission, change Firebase or an app
store, deploy, upload, or make a language or country availability claim.
