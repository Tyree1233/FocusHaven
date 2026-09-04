# FocusHaven Streamlined Locale Workflow

Status: reusable workflow for locales added after the Spanish foundation

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

It never activates a locale, edits the production registry, copies a catalog
into `lib/l10n`, contacts a translation provider, reads private FocusHaven
content, records a reviewer identity, deploys, publishes, or changes a store.

## 1. Initialize the locale

Run from the repository root. French is shown only as an example:

```bash
dart run tool/localization_streamlined_pipeline.dart \
  init fr French Français general_french
```

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

## 3. Complete the private fluent review

The fluent reviewer changes only the final two CSV columns:

- `decision`: `ACCEPT`, `REVISE`, or `BLOCK`;
- `replacement`: required only for `REVISE`.

The reviewer must inspect every row in context. They must not change the key,
source, candidate, description, placeholder, sequence, or risk columns. No
name, email address, signature, qualifications, timestamp, notes, or contact
information is requested or stored in Git.

A blocked row stops the pipeline. A revised row becomes part of the reviewed
catalog only after its placeholders and ICU structure pass again.

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
revisions, reruns structural qualification, and writes only:

- the reviewed ARB catalog; and
- an anonymous aggregate validation record containing content hashes, counts,
  scope, and closed runtime boundaries.

The private worksheet remains outside Git. `verify` checks every source,
candidate, review, and approved-catalog lock and reports whether the locale is
ready for integration.

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
