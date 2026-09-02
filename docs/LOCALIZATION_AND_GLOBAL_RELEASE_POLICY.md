# FocusHaven Localization and Global-Release Policy

Status: Phase 215G-C2D private Spanish validation complete; Spanish remains
runtime inactive

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
- Phases 215G-B1, B2, B3A, B3B, B3C, B4, and B5 catalog-own onboarding, appearance selection,
  custom-duration chrome, guided breathing, timer accessibility, the bounded
  timer dashboard/session-control presentation, Focus Queue management and
  completed-task history, Haven Plan, Haven Planner review, and the
  Plan-to-Focus task-decision card, completed-session reflection, Haven Rhythm,
  Focus Forecast, Smart Reset, Haven Journey, Haven Window, Focus Shield,
  Focus Coach, Voice-to-Coach, safe-command, Haven action, account,
  authentication, backup, deletion, Pro, purchase, journal, profile, reminder,
  milestone, Focus History, and current legal-launch presentation boundaries.
  Phase 215G-B6C1 additionally catalog-owns Haven action interpretation,
  policy, and execution copy. Phase 215G-B6C2 catalog-owns deterministic
  Local-Coach responses, enhanced-AI fallback notices, and coaching service
  errors and cleanup receipts. Phase 215G-B6C3 catalog-owns the remaining
  authentication, store, journal-prompt, private-export, Haven Plan, and Living
  Lantern service results. Phase 215G-B English Flutter extraction is
  complete; translation, language-aware understanding, native resources, and
  country-release qualification are not.
- No runtime translation service is used, and no private user content is sent
  anywhere for translation.
- Phase 215G-C0 freezes the completed English catalog for Spanish translation
  intake, adds a fail-closed structural auditor and pending human-review record,
  and keeps every candidate outside `lib/l10n`. It creates no Spanish catalog,
  activates no locale, and makes no language or country availability claim.
- Phase 215G-C1A adds a deterministic, exact-source-locked Spanish candidate
  builder. It accepts only complete translation bundles, preserves metadata and
  placeholders, requires rationales for source-equal values, writes only to the
  isolated candidate path, and refuses overwrite. It creates no bundle or
  candidate and does not approve or activate Spanish.
- Phase 215G-C1B uses that guarded builder to create the complete isolated
  machine-assisted Spanish candidate. Both the builder audit and an independent
  audit pass all 980 messages and 148 placeholder-bearing messages. The
  candidate remains outside `lib/l10n`, its qualified-human-review fields are
  empty, and Spanish remains planned and inactive. Structural readiness is not
  linguistic, runtime, voice/coaching, native/store, or country qualification.
  No external translation provider or private runtime data was used.
- Phase 215G-C2A prepares a second fail-closed builder for the future human
  review packet. It pins the exact English catalog, Spanish candidate, and C1B
  structural audit; produces critical-first batches of at most 50 entries; and
  leaves every reviewer decision empty. It does not create the packet, assign a
  reviewer, begin review, approve Spanish, or activate a locale.
- Phase 215G-C2B separately creates and audits the isolated packet. Its exact
  SHA-256 is
  `325231a14ff0dfe2b176f6267996292aa0575b5db16d3c084cf453bf5f75737e`;
  all 980 entries remain pending in 20 bounded batches, and every decision,
  replacement, and note is empty. The packet is not assigned, human review has
  not started, and Spanish remains linguistically unapproved, outside
  `lib/l10n`, and runtime inactive.
- Phase 215G-C2C prepares the exact-lock reviewer-assignment gate without
  assigning anyone. A later assignment must identify a real qualified reviewer
  and preserve a non-sensitive qualification, independence statement, accepted
  scope, and lock set. Assignment cannot start review, fill any of the 980
  decisions, approve Spanish, or activate the locale. No authorization or
  assignment record exists in this phase.
- Phase 215G-C2D records the completed private validation of all 980 Spanish
  candidate messages without committing the workbook, reviewer identity,
  contact details, qualifications, metadata, or notes. Only anonymous counts
  and exact content locks enter Git. The prepared C2C named-assignment path was
  not used. Spanish remains outside `lib/l10n` and runtime inactive pending
  language-specific integration and later release gates.

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
  deletion, permission, and destructive-action language; the repository may
  retain anonymous validation evidence instead of personal reviewer details;
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
  and semantics into the source catalog without changing behavior. B1, B2,
  B3A, B3B, B3C, B4, B5, B6A, B6B1, B6B2, B6C1, B6C2, and B6C3 are audited;
  the English Flutter extraction is complete. Phase 215G-B3B
  keeps personal reflection content outside the catalog and leaves generated
  restorative guidance with its B6 owner. Phase 215G-B3C catalog-owns optional
  connection chrome, permission and platform truth, and advisory boundaries
  while leaving generated Haven Window and Focus Shield state text with B6.
  Phase 215G-B4 catalog-owns Coach and Haven action presentation, explicit
  tap-to-talk disclosures and controls, enhanced-AI boundaries, and stable
  permission/recognition notice presentation. Private transcripts, user
  messages, Coach responses, interpreted proposal text, execution results, and
  other service-generated runtime values remain outside the catalog; B6 keeps
  ownership of service-generated user-facing text.
  Phase 215G-B5 catalog-owns account and authentication presentation, backup
  and destructive confirmations, Pro and purchase presentation, journal and
  profile chrome, reminders, milestones, Focus History, and the current
  privacy-policy launch action. Private identities, journal text, tasks, store
  prices, stable stored mood/profile identifiers, and service-returned values
  retain their existing owners and are not translated.
  Phase 215G-B6A moves Flutter-owned notification copy, Flutter-created Android
  channel labels, timer-completion notification copy, and stable
  account-deletion receipts into the catalog. Notification and channel IDs,
  schedules, permission behavior, timer state, and deletion status enums remain
  unchanged. Generated planning/restorative copy and coaching, action,
  authentication, store, journal, export, and other service results retain
  later B6 owners, so Phase 215G-B is not complete.
  Phase 215G-B6B1 moves stable local Haven Planner validation, assumptions,
  uncertainty, generated item templates, and informational suggestions into
  the catalog without translating user-authored goals or changing proposal,
  review, queue, timer, or calendar behavior.
  Phase 215G-B6B2 moves stable Haven Rhythm, Focus Forecast, Smart Reset,
  Haven Journey, Haven Window, and Focus Shield guidance into the catalog.
  Private reflections, completion identities, redacted calendar boundaries,
  and native-owned app or website selections remain opaque values; no service
  rule, threshold, permission, platform adapter, timer, queue, or persistence
  behavior changes.
  Phase 215G-B6C1 moves stable Haven action interpretation, proposal-effect,
  policy, replay, confirmation, failure, and success receipts into the
  catalog. User-authored queue titles remain opaque placeholders; the typed
  and voice-transcript allowlist, protected-operation exclusions, proposal
  schema, expiry, state tokens, exact confirmation, replay protection, and
  existing timer, queue, and navigation service ownership remain unchanged.
  Phase 215G-B6C2 moves deterministic private Local-Coach responses,
  remembered stable challenge labels, enhanced-AI fallback notices, and
  coaching save, repair, consent-preference, and cleanup errors into the
  catalog. User messages, task names, moods, profiles, and saved conversation
  content remain opaque runtime placeholders. The in-memory selected catalog
  is deliberately excluded from the Enhanced-AI prompt payload. English
  signal matching and command interpretation remain unchanged until Phase
  215G-D qualifies language-aware understanding.
  Phase 215G-B6C3 moves stable authentication and store results, daily journal
  prompts, private Focus History export copy, Haven Plan guidance, and Living
  Lantern guidance into the catalog. Private identities, prices, journal text,
  moods, tasks, and history remain opaque values. Provider diagnostics are not
  rendered as user copy, and all owning service behavior is unchanged.
  Phase 215G-B6C3 completes the English Flutter extraction. Phase 215G-C,
  215G-D, and 215G-E remain required before any additional locale or country
  availability claim.
- **215G-C — First translation wave:** complete and qualify Spanish, French,
  German, and Brazilian Portuguese one locale at a time.
  Phase 215G-C0 establishes the source lock, candidate isolation, structural
  parity checks, terminology worksheet, and explicit human-review evidence for
  Spanish. Structural readiness is not linguistic approval, runtime
  qualification, or release qualification. Phase 215G-C1A adds the guarded
  builder. Phase 215G-C1B creates and structurally audits the complete isolated
  Spanish machine draft. Phase 215G-C2A prepares the locked packet builder
  without creating a packet or starting review. Phase 215G-C2B creates and
  locks the isolated packet without assigning it or starting review. Phase
  215G-C2C prepares a fail-closed assignment tool, but the assignment record
  does not exist. Phase 215G-C2D uses the alternate private-validation path:
  all 980 Spanish messages are accepted with zero revisions, blocks, source
  mutations, or placeholder mismatches, and no personal reviewer information
  is stored. Spanish remains runtime inactive; isolated integration, layout,
  accessibility, voice/coaching, native, store, and country gates remain.
- **215G-D — Voice and coaching:** align recognition, action interpretation,
  local coaching, and explicit fallbacks with each qualified locale.
- **215G-E — Native and store surfaces:** complete platform resources, public
  policies, screenshots, listings, and country-specific release evidence.

Planning approval is not release approval. Each new production locale changes
the claims and test surface of a release and therefore requires new evidence.
