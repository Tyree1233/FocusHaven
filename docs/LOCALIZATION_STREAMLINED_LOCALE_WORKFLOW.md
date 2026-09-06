# FocusHaven Streamlined Locale Workflow

Status: reusable workflow for locales added after the Spanish foundation

First completed use: French (`fr`), with 980 anonymously reviewed messages and
no blocked decisions. Its integration proves that ordinary future locales can
reuse the shared registry, picker, fallback, layout, semantics, privacy, test,
and build gates without replaying the Spanish foundation phases.

The first two-locale batch activated German and Brazilian Portuguese. The
later three-locale Latin-script batch activated Italian, Polish, and Dutch only
after independent complete fluent reviews, a focused four-row correction
merge, and zero-issue content-safety verification across all 2,940 messages.

## Goal

An ordinary new language should take one compact product pass, not a replay of
every Spanish foundation phase. The reusable path is:

1. initialize one locale plan;
2. prepare one complete candidate and private review worksheet;
3. obtain one complete private fluent review;
4. accept the review and verify the anonymous content locks;
5. integrate the exact reviewed catalog, run the shared UI and accessibility
   gates, activate the registry entry, and complete tests and builds; and
6. create one locale commit, push it once, and verify its CI once.

The Spanish rollout established the app-wide localization, layout,
screen-reader, speech-recognition, fallback, and language-picker foundations.
Those foundations are reused. Physical devices, speech, special fonts,
right-to-left work, and store promotion are added only when the new locale or
an enabled feature materially needs them.

## What is automated

`tool/localization_streamlined_pipeline.dart` replaces the separate candidate
preparation, candidate creation, packet preparation, packet creation, named
reviewer assignment, and aggregate-review validation stages used while the
Spanish foundation was being proven.

The tool has four commands:

```text
init     Create one locked locale plan.
prepare  Build and structurally audit the candidate and create a private CSV.
accept   Apply the completed anonymous review and create its aggregate proof.
verify   Confirm the exact reviewed catalog is ready for runtime integration.
```

## Batch several independent locales

`tool/localization_streamlined_batch.dart` runs those same four operations for
one to ten locale entries from a locked batch manifest. It is an orchestrator,
not a second translation or approval system: each child operation is delegated
to `tool/localization_streamlined_pipeline.dart`, each locale keeps its own
plan, candidate, structural audit, private worksheet, reviewed catalog, and
anonymous validation record, and the batch never approves one locale because
another passed.

The manifest contains no translation, reviewer identity, or private review
path. It locks the common English source and supplies only public locale
metadata:

```json
{
  "schemaVersion": 1,
  "workflow": "focus_haven_streamlined_locale_batch_v1",
  "sourceCatalog": "lib/l10n/app_en.arb",
  "sourceCatalogSha256": "the current English catalog digest",
  "maxParallelism": 3,
  "locales": [
    {
      "locale": "de",
      "englishName": "German",
      "nativeName": "Deutsch",
      "reviewScope": "general_german"
    },
    {
      "locale": "pt-BR",
      "englishName": "Brazilian Portuguese",
      "nativeName": "Português (Brasil)",
      "reviewScope": "brazilian_portuguese"
    },
    {
      "locale": "ja",
      "englishName": "Japanese",
      "nativeName": "日本語",
      "reviewScope": "japanese_cjk",
      "exceptionalGates": {
        "rightToLeft": false,
        "fontCoverage": true,
        "physicalScreenReader": false,
        "physicalSpeechRecognition": false,
        "storePromotion": false
      }
    }
  ]
}
```

`exceptionalGates` is optional for an ordinary locale and defaults to all five
closed (`false`). When present, it must contain all five boolean gates. This
lets one mixed batch declare locale-specific work before initialization. For
example, Japanese and Korean remain left-to-right in the app but set
`fontCoverage` to `true` so glyph coverage, fallback fonts, wrapping, and CJK
line breaking require explicit evidence before activation. A locale that needs
right-to-left layout instead sets `rightToLeft` to `true`.

Japanese and Korean completed that exceptional gate with anonymous physical
checks on exact Android debug artifacts and standalone signed iOS profile
artifacts. The iOS profile path avoids the iOS debug-launch dependency on a
resident Flutter debugger. Its isolated CJK entry point accepts only explicitly
authorized non-release builds and remains fail-closed in release mode. Each
locale keeps an anonymous `physical-cjk-coverage.json` record that binds the
reviewed catalog and platform artifacts while recording no operator or device
identity. Passing this gate permits in-app registry activation only; speech
recognition, screen-reader qualification, store promotion, and country release
remain independent.

The batch is deliberately bounded to ten locales and five simultaneous child
operations. Three locales with `maxParallelism: 3` is the recommended first
wave. Every operation performs a complete batch preflight before starting a
child command, so missing inputs or existing outputs cause a no-write stop.
Once execution begins, a structural or review failure is isolated to its
locale; the remaining locale checks finish and the final JSON summary reports
each result. Successful locales are never rolled back, and failed locales are
never treated as approved.

Run the batch commands from the repository root:

```bash
dart run tool/localization_streamlined_batch.dart init \
  /path/to/locale-batch.json

dart run tool/localization_streamlined_batch.dart prepare \
  /path/to/locale-batch.json \
  /private/path/translation-bundles \
  /private/path/review-worksheets

dart run tool/localization_streamlined_batch.dart accept \
  /path/to/locale-batch.json \
  /private/path/review-worksheets

dart run tool/localization_streamlined_batch.dart verify \
  /path/to/locale-batch.json
```

Private bundle directories and review directories must be outside the
repository. File names are deterministic:

- `focushaven-<locale>-translations.json` for the machine-assisted bundle;
- `focushaven-<locale>-review.csv` for the private review worksheet.

There is one private review worksheet per locale. Fluent decisions remain
independent, and an incomplete language may be left out of a later activation
wave while completed languages continue. If execution—not preflight—produces
a partial batch, use the ordinary single-locale command to repair or complete
only the failed locale; existing successful outputs are never overwritten.

Batch verification establishes content readiness only. Runtime catalog copies,
registry edits, shared tests and builds, the activation commit, CI, speech,
store promotion, and country distribution remain explicit later steps.

It never activates a locale, edits the production registry, copies a catalog
into `lib/l10n`, contacts a translation provider, reads private FocusHaven
content, records a reviewer identity, deploys, publishes, or changes a store.

## Optional Google Cloud draft adapter

`tool/localization_google_translate_drafts.dart` can create the private
machine-assisted bundles consumed by the existing `prepare` command. It is an
offline development tool, not an app dependency or runtime translation
feature. It sends only the locked public English ARB messages to Google Cloud
Translation Advanced v3 and never sends tasks, reflections, transcripts,
account data, or other FocusHaven runtime content.

The adapter deliberately keeps provider access outside the repository:

- it uses a private configuration file and private output directory;
- it accepts OAuth access from the authenticated `gcloud` CLI and never accepts
  or stores an API key or credential file;
- it requires one distinct bilingual glossary resource per target locale;
- it uses `us-central1`, the required glossary location, and the general NMT
  model;
- it chunks the 980 messages into requests of no more than 5,000 code points;
- it never prints source copy, translations, access tokens, provider response
  bodies, or provider request identifiers;
- it refuses existing outputs and writes a bundle only after the complete
  locale passes the ordinary structural and content-safety preparation gate;
- one provider or safety failure remains isolated to that locale; and
- every generated draft still requires the complete private fluent review,
  acceptance, integration, test, build, and activation gates below.

The private provider configuration has this exact shape:

```json
{
  "schemaVersion": 1,
  "workflow": "focus_haven_google_translation_drafts_v1",
  "projectId": "your-google-cloud-project-id",
  "location": "us-central1",
  "model": "general/nmt",
  "maxCodePointsPerRequest": 4500,
  "locales": {
    "id": {
      "targetLanguageCode": "id",
      "glossary": "projects/your-google-cloud-project-id/locations/us-central1/glossaries/focushaven-en-id",
      "approvedSourceEqual": {
        "appTitle": "The registered product name remains invariant."
      }
    }
  }
}
```

The config's locale set must exactly equal the batch manifest. A glossary may
not be reused for another locale. `approvedSourceEqual` is not inferred from
provider output: every exact English value needs an explicit non-empty
rationale, and a stale rationale fails closed if the provider returns a
translated value instead.

Run a no-network preflight first:

```bash
dart run tool/localization_google_translate_drafts.dart preflight \
  /private/path/locale-batch.json \
  /private/path/google-translation-config.json \
  /private/path/translation-bundles
```

After the Cloud Translation API and all per-language glossaries exist and the
active `gcloud` identity has only the required translation permissions, create
the private drafts:

```bash
dart run tool/localization_google_translate_drafts.dart translate \
  /private/path/locale-batch.json \
  /private/path/google-translation-config.json \
  /private/path/translation-bundles
```

The output names remain
`focushaven-<locale>-translations.json`, so the ordinary batch `prepare`
command consumes them without a provider-specific exception. Google remains a
draft source only: it cannot approve a message, produce a validation record,
copy a runtime ARB, edit the picker, or activate a locale.

## 1. Initialize the locale

Run from the repository root. French is shown only as an example:

```bash
dart run tool/localization_streamlined_pipeline.dart \
  init fr French Français general_french
```

The optional final argument is a quoted JSON object containing all five
exceptional gates. The batch orchestrator supplies it automatically whenever a
locale has a non-default gate; direct single-locale initialization normally
omits it.

This creates `localization/plans/fr.json` with the exact current English
catalog hash and deterministic candidate, audit, approval, and runtime paths.
For a regional locale, use its canonical tag, for example `pt-BR`; the tool
automatically uses `pt_BR` where Flutter ARB naming requires it.

Review the plan's exceptional gates before translation starts. Ordinary
left-to-right Latin-script locales begin with every exceptional gate false.
Changing one to true records that the locale needs additional evidence; it
does not claim that evidence has passed.

## 2. Supply one complete translation bundle

The private translation bundle has this exact shape:

```json
{
  "schemaVersion": 1,
  "workflow": "focus_haven_streamlined_locale_v1",
  "locale": "fr",
  "sourceCatalogSha256": "the digest copied from the locale plan",
  "translations": {
    "appTitle": "FocusHaven"
  },
  "approvedSourceEqual": {
    "appTitle": "The registered product name remains invariant."
  }
}
```

`translations` must contain every source message exactly once. The structural
auditor rejects missing or extra keys, empty values, changed placeholder
schemas, changed ICU placeholder use, or source-equal copy without a written
rationale. The bundle may contain only public catalog copy—never tasks,
journal entries, reflections, transcripts, account data, or other runtime
content.

Prepare the candidate and a private worksheet outside the repository:

```bash
dart run tool/localization_streamlined_pipeline.dart prepare \
  localization/plans/fr.json \
  /private/path/focushaven-fr-translations.json \
  /private/path/focushaven-fr-review.csv
```

The command creates the isolated candidate and structural audit inside the
repository. It refuses to place the review CSV anywhere inside the repository
and refuses to overwrite any existing output. The CSV opens normally in Excel
and sorts safety-, privacy-, deletion-, permission-, purchase-, AI-, and
action-related copy first.

Candidate preparation also runs a deterministic content-safety screen before
creating any output. It fails closed when a translation introduces an email or
URL absent from the matching English source, changes the protected
`FocusHaven` product name, changes literal numbers, swaps minutes and seconds,
contains runaway word or CJK repetition, introduces an unexpected writing
system, or reuses one identical translation for eight or more distinct source
messages. These checks catch high-confidence corruption and cross-contamination;
they do not replace fluent review or claim that machine-generated copy is
linguistically correct.

The repetition check preserves ordinary Latin-language word boundaries. It
does not treat four identical letters created only by removing spaces—such as
the boundary in Dutch `twee eerlijke`—as runaway repetition. Four repeated
tokens, repeated multi-character units, and single-character CJK runs remain
fail-closed.

If an older prepared candidate predates these checks, its private worksheet can
still be reviewed and repaired. `accept` applies all reviewed revisions first
and then runs the same content-safety screen on the proposed approved catalog.
Unrepaired corruption therefore cannot become an approval or runtime catalog.

## 3. Complete the private fluent review

The fluent reviewer changes only the final two CSV columns:

- `decision`: `ACCEPT`, `REVISE`, or `BLOCK`;
- `replacement`: required only for `REVISE`.

The reviewer must inspect every row in context. They must not change the key,
source, candidate, description, placeholder, sequence, or risk columns. No
name, email address, signature, qualifications, timestamp, notes, or contact
information is requested or stored in Git.

A blocked row stops the pipeline. A revised row becomes part of the reviewed
catalog only after its placeholders, ICU structure, and intentional leading or
trailing whitespace pass again. Boundary whitespace matters when one localized
message is appended to another. If a fluent reviewer deliberately enters the
exact English source as a `REVISE`
replacement—for example, for a product label or a word that is legitimately
identical in both languages—the pipeline records that message key as an
explicit review-approved source-equal value. This decision is anonymous and
does not require a reviewer note or identity.

## 4. Accept and verify the review

```bash
dart run tool/localization_streamlined_pipeline.dart accept \
  localization/plans/fr.json \
  /private/path/focushaven-fr-review.csv

dart run tool/localization_streamlined_pipeline.dart verify \
  localization/plans/fr.json
```

`accept` verifies that all immutable worksheet columns still match the locked
source and candidate, requires one valid decision per message, applies
revisions, records any explicit review-approved source-equal message keys,
reruns structural qualification and the deterministic content-safety screen,
and writes only:

- the reviewed ARB catalog; and
- an anonymous aggregate validation record containing content hashes, counts,
  scope, and closed runtime boundaries.

The private worksheet remains outside Git. `verify` checks every source,
candidate, review, and approved-catalog lock, reruns the content-safety screen
on the exact approved catalog, and reports whether the locale is ready for
integration.

## 5. One integration and activation pass

After `verify` reports `readyForIntegration: true`:

1. copy the exact reviewed catalog to the plan's `runtimeCatalog` path;
2. change that locale's registry status from `planned` to `production` and add
   it to `FocusHavenLocales.production` and `productionLocales`;
3. run Flutter localization generation;
4. run the shared narrow-layout, enlarged-text, semantics, fallback, locale
   selection, privacy-boundary, and optional-feature fail-closed tests;
5. run the complete Flutter tests, analysis, web build, Android build, and iOS
   no-codesign build; and
6. commit the plan, candidate, audit, reviewed catalog, anonymous validation,
   runtime catalog, registry change, and any locale-specific test updates as
   one reviewed locale change.

The Appearance language list is generated from the production registry. A new
production definition therefore becomes an in-app choice automatically; the
picker and local-preference service do not need another language-specific enum
or manually added radio button.

The first production batch applies this same activation boundary independently
to German and Brazilian Portuguese. Each locale keeps its own reviewed catalog,
anonymous validation record, exact runtime identity, and verification result;
the shared commit does not merge their approval evidence or let one language's
result stand in for the other.

For a region-specific ARB such as `app_pt_BR.arb`, Flutter requires the matching
base fallback (`app_pt.arb`) during generation. The base fallback must be a
mechanical copy of the reviewed regional catalog with only `@@locale` changed;
it remains an implementation fallback and must not become another production
registry choice.

## Exceptional gates

The following are not repeated automatically for every language:

- physical screen-reader checks, when shared controls and layouts are already
  covered and the locale introduces no material accessibility risk;
- physical speech recognition, when voice is unsupported and fails closed or
  when the locale does not expose voice;
- right-to-left layout work for left-to-right locales;
- special font and shaping checks for scripts already covered by the app's
  fonts; and
- App Store, Google Play, screenshots, support, or country promotion when the
  request is only to make the language available inside the app.

If a locale requires one of these, set its plan flag to true and add only that
bounded evidence. A safely unavailable optional feature does not block the
fully translated typed interface.

## Release boundary

Passing this workflow authorizes only the in-app locale after its integration
and activation commit is verified. It does not authorize store-language
promotion, a new country launch, localized legal claims, new support promises,
pricing, tax treatment, or distribution changes. Those remain explicit,
separate product decisions.
