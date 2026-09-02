# FocusHaven Spanish Candidate Preparation

Status: Phase 215G-C1B candidate structurally ready; human review not started
Source checkpoint: `fed1c9a2e6096d86f76bc458d4ccc47870f6e0fc`

## Purpose

Phase 215G-C1A prepares a deterministic, fail-closed path for turning a complete
Spanish translation bundle into an isolated ARB candidate. It does not create a
Spanish candidate, translate source copy, approve a translation, or activate a
locale.

Phase 215G-C1B used that path with an authorized machine-assisted draft of only
the locked, non-sensitive English catalog. It created the isolated candidate at
`localization/candidates/app_es.arb` and independently audited it. No external
translation provider or private runtime data was used. This is candidate
creation, not qualified human approval or locale activation. The result is
structurally ready for qualified human review only; Spanish remains planned and
inactive.

The separation is deliberate. A file can be structurally complete while its
wording is unnatural, unsafe, culturally inappropriate, or misleading. A
qualified human reviewer must still assess all 980 messages in context before
any candidate can progress beyond structural readiness.

## Allowed inputs

The uncommitted translation bundle consumed by Phase 215G-C1B contained only:

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

The controlled uncommitted input path is
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

The guarded command used was:

```bash
dart run tool/localization_spanish_candidate_builder.dart \
  lib/l10n/app_en.arb \
  localization/intake/es/translations.json \
  localization/candidates/app_es.arb
```

Its zero exit status means only that the isolated candidate was created and is
structurally ready for human review. It does not mean linguistically
approved, runtime qualified, release qualified, or publicly supported.

## Phase 215G-C1B structural result

| Field | Verified value |
| --- | --- |
| Candidate | `localization/candidates/app_es.arb` |
| Candidate SHA-256 | `611d1afcc6eb688f92d56928f08cad5dbfdef2b5031c537c53615accfb16b83f` |
| Authorized draft-bundle SHA-256 | `192f8c5906d939aa42dd4cf328345d762d8eb701fb9f250cbdbc2bba7964557f` |
| Messages | 980 |
| Messages with placeholders | 148 |
| Approved source-equal invariants | 11 |
| Missing, extra, or empty values | 0 |
| Missing metadata | 0 |
| Placeholder-schema mismatches | 0 |
| ICU placeholder mismatches | 0 |
| Human reviewer | Not assigned |
| Linguistic approval | No |
| Runtime activation | No |

The structural audit initially exposed a false positive in the C1A auditor for
ordinary ICU plural-branch text. The corrected scanner distinguishes a branch
body such as `{thought}` from a declared named placeholder and still discovers
real placeholders nested inside branch bodies. A focused regression test
preserves that boundary.

## Inactive runtime boundary

The Spanish candidate exists only in the isolated review directory. `lib/l10n`
continues to contain only the locked English source catalog, and the production
locale registry continues to expose only English. The isolated candidate must remain outside
`lib/l10n` until explicit linguistic, Flutter runtime, voice and coaching,
native, store, policy, support, accessibility, and country-release gates pass.

## Phase 215G-C1A non-actions

This phase does not create a Spanish candidate or translation bundle, approve a
term, activate a locale, change a language setting, translate private runtime
values, contact an external translation provider, add a dependency or
permission, change Firebase or store configuration, deploy, upload, or make a
language or country availability claim.

## Phase 215G-C1B non-actions

Phase 215G-C1B does not claim that the machine-assisted wording is correct,
assign or impersonate a human reviewer, activate Spanish, move the candidate
into `lib/l10n`, generate runtime delegates, change a language setting, qualify
Spanish voice or coaching behavior, localize native or store surfaces, contact
a provider, use private runtime data, add a dependency or permission, deploy,
upload, or make a language or country availability claim.
