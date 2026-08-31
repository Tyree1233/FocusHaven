# FocusHaven Localization and Global-Release Policy

Status: Phase 215G-A architecture contract

FocusHaven is intended to become useful in multiple languages without making
premature availability claims or weakening its local-first privacy boundary.
This policy separates technical locale support, linguistic completeness, and
country release readiness.

## Current truth

- English (`en`) is the source catalog and the only production-supported
  runtime locale.
- Spanish (`es`), French (`fr`), German (`de`), and Brazilian Portuguese
  (`pt-BR`) form the planned first translation wave.
- Planned locales are not exposed by `MaterialApp.supportedLocales` and must
  not appear as supported languages in Apple or Google store metadata.
- Phase 215G-A localizes only the app-shell title. Existing English interface
  strings remain source material for the complete extraction phase.
- No runtime translation service is used, and no private user content is sent
  anywhere for translation.

## Catalog authority

Flutter's generated localization pipeline is the runtime authority. The
English ARB file is the source catalog, each message requires descriptive
metadata, and generated Dart files are build artifacts rather than reviewed
source. Locale definitions separately distinguish `production` from
`planned`; adding a definition cannot activate a locale.

The following content must be catalog-owned before another locale can be
considered complete:

1. visible Flutter labels, headings, buttons, menus, dialogs, sheets, errors,
   empty states, receipts, and confirmations;
2. screen-reader semantics, live-region messages, hints, duration text, plural
   forms, interpolation placeholders, and validation feedback;
3. timer, queue, planner, reflection, Rhythm, Forecast, Smart Reset, Journey,
   coaching, Haven action, authentication, purchase, privacy, and deletion
   surfaces;
4. notification text, Android resources, Apple strings and purpose text,
   widgets, Live Activities, Wear OS, Apple Watch, and system intents;
5. privacy policy, account deletion, support, onboarding, release notes, and
   App Store and Google Play listing content.

## Production-locale gate

A planned locale becomes production-supported only after all of these gates
pass for that exact locale:

- the catalog has every source message and no untranslated fallback in the
  supported user journey;
- plurals, gender-neutral language, dates, times, numbers, durations, and
  placeholders are reviewed in context;
- a qualified human reviewer checks meaning, tone, safety, privacy, purchase,
  deletion, permission, and destructive-action language;
- narrow screens, text expansion, large accessibility sizes, right-to-left
  readiness where applicable, keyboard navigation, and screen readers pass;
- native phone, web, desktop, widget, watch, notification, and system surfaces
  either match the locale or truthfully declare a documented limitation;
- Voice-to-Coach and safe voice commands use an explicitly supported speech
  locale and pass real-device recognition, editing, discard, confirmation,
  background-stop, and no-duplicate tests;
- local Coach and rule-based interpretation are reviewed in that language;
  unsupported enhanced-AI language behavior fails safely and honestly;
- public policies, support paths, store questionnaires, screenshots, and
  listings are consistent for every country where that locale is promoted;
- fresh signed builds and store candidates complete the applicable privacy,
  accessibility, platform, and release validations.

Machine translation can help draft non-sensitive copy only after a separate
review approves the provider and data boundary. It cannot receive tasks,
journal entries, reflections, transcripts, coaching conversations, account
data, or other private user content. Machine output never bypasses human review
for production copy.

## Locale selection and fallback

Initially FocusHaven follows the operating-system locale. A future in-app
language selector must be explicit, reversible, locally stored, accessible in
every supported language, and independent of account or cloud backup. If the
device language is not supported, Flutter falls back to the complete English
catalog. FocusHaven must never show a partly translated locale mixed with
unreviewed safety-critical English merely to claim wider coverage.

## Store and country boundary

A translated interface does not by itself authorize distribution in a new
country. Pricing, taxes, consumer disclosures, subscription terms, age and
content ratings, health-related wording, account deletion, data practices,
export rules, support capacity, and applicable local law require independent
review. A locale may be technically complete while promotion in one or more
countries remains blocked.

Google Play contact-number verification is an account checkpoint, not a locale
or country-release approval. Other Play Console verification or publishing
tasks must still be evaluated from the console's current state.

## Phase sequence

- **215G-A — Foundation:** generated localization, English source catalog,
  truthful locale registry, documentation, and contract tests.
- **215G-B — English extraction:** move all current app-owned Flutter strings
  and semantics into the source catalog without changing behavior.
- **215G-C — First translation wave:** complete and qualify Spanish, French,
  German, and Brazilian Portuguese one locale at a time.
- **215G-D — Voice and coaching:** align recognition, action interpretation,
  local coaching, and explicit fallbacks with each qualified locale.
- **215G-E — Native and store surfaces:** complete platform resources, public
  policies, screenshots, listings, and country-specific release evidence.

Planning approval is not release approval. Each new production locale changes
the claims and test surface of a release and therefore requires new evidence.
