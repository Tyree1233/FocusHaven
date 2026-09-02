# FocusHaven Spanish Candidate Preparation

Status: Phase 215G-C1A preparation only; Spanish remains planned and inactive
Source checkpoint: `fed1c9a2e6096d86f76bc458d4ccc47870f6e0fc`

## Purpose

Phase 215G-C1A prepares a deterministic, fail-closed path for turning a complete
Spanish translation bundle into an isolated ARB candidate. It does not create a
Spanish candidate, translate source copy, approve a translation, or activate a
locale.

The separation is deliberate. A file can be structurally complete while its
wording is unnatural, unsafe, culturally inappropriate, or misleading. A
qualified human reviewer must still assess all 980 messages in context before
any candidate can progress beyond structural readiness.

## Allowed inputs

The future translation bundle may contain only:

- the exact locked source commit and catalog digest;
- locale `es` and preparation phase `215G-C1A`;
- one proposed Spanish string for every source message key; and
- a non-empty reviewer rationale for every intentionally source-equal value,
  such as the `FocusHaven` product name.

Tasks, journal entries, reflections, transcripts, coaching conversations,
account identities, calendar events, purchases, focus history, and other
private runtime values are not translation inputs. Synthetic examples may be
used when a reviewer needs placeholder context.

No external translation provider is approved by this phase. Provider use would
require separate authorization and a documented boundary limiting input to the
non-sensitive source catalog. Machine output can be a draft, never human
approval.

## Bundle shape

The future uncommitted input path is
`localization/intake/es/translations.json`. It must use this structure:

```json
{
  "phase": "215G-C1A",
  "locale": "es",
  "sourceCommit": "fed1c9a2e6096d86f76bc458d4ccc47870f6e0fc",
  "sourceCatalogSha256": "ba6e97b200060f211d3e0d73276e1132e03c8de18ac0778d38c356abe9874e87",
  "translations": {
    "appTitle": "FocusHaven"
  },
  "approvedSourceEqual": {
    "appTitle": "The registered product name remains invariant."
  }
}
```

The example is intentionally incomplete and cannot produce a candidate.

## Builder boundary

`tool/localization_spanish_candidate_builder.dart` requires exact translation
key parity, non-empty values, the locked source identifiers, valid source-equal
decisions, preserved metadata, and safe ICU placeholder use. It then runs the
Phase 215G-C0 catalog qualification audit over the constructed candidate.
The command also accepts only `lib/l10n/app_en.arb` as its source path and
independently verifies that file's locked SHA-256 before constructing output.

The builder refuses:

- a wrong phase, locale, source commit, or catalog digest;
- missing, extra, empty, or null-character translation values;
- source-equal values without a specific non-empty rationale;
- a rationale attached to a value that is not actually source-equal;
- missing or changed placeholder metadata or ICU placeholder use;
- output anywhere except `localization/candidates/app_es.arb`; and
- overwriting an existing candidate.

The future command is:

```bash
dart run tool/localization_spanish_candidate_builder.dart \
  lib/l10n/app_en.arb \
  localization/intake/es/translations.json \
  localization/candidates/app_es.arb
```

A zero exit status will mean only that an isolated candidate was created and
is structurally ready for human review. It will not mean linguistically
approved, runtime qualified, release qualified, or publicly supported.

## Inactive runtime boundary

No Spanish catalog exists in this phase. `lib/l10n` continues to contain only
the locked English source catalog, and the production locale registry continues
to expose only English. A future isolated candidate must remain outside
`lib/l10n` until explicit linguistic, Flutter runtime, voice and coaching,
native, store, policy, support, accessibility, and country-release gates pass.

## Phase 215G-C1A non-actions

This phase does not create a Spanish candidate or translation bundle, approve a
term, activate a locale, change a language setting, translate private runtime
values, contact an external translation provider, add a dependency or
permission, change Firebase or store configuration, deploy, upload, or make a
language or country availability claim.
