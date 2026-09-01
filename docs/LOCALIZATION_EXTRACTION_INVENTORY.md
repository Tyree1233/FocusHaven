# FocusHaven Flutter Localization Extraction Inventory

Status: Phase 215G-B6C1 audited extraction contract

This inventory divides the English-source extraction into reviewable slices.
It prevents one converted screen from being mistaken for a completely
localized application. English (`en`) remains the only production locale;
Spanish, French, German, and Brazilian Portuguese remain planned and inactive.

## Inventory method

The Phase 215G-B baseline reviewed app-owned Dart sources for visible text,
tooltips, semantics, errors, confirmations, empty states, receipts, dynamic
interpolation, plurals, and service-originated messages. Mechanical literal
counts are only discovery aids: identifiers, preference keys, routes, asset
paths, diagnostic names, and user-authored content are not translation copy.
Every slice therefore requires both source review and focused behavior tests.

## B1 — Core entry and compact controls

The following production surfaces are fully catalog-owned within their stated
boundary:

- first-run onboarding headings, supporting copy, progress labels, and errors;
- appearance-sheet heading, navigation tooltip, help and error text, and all
  six theme display names;
- custom-duration sheet heading format, instructions, compact minute/second
  units, and confirmation label (the session name remains caller-owned until
  the timer-dashboard slice is extracted);
- mindful-pause heading, instructions, all breathing phases, completion text,
  controls, and second pluralization;
- main timer screen-reader label and the complete remaining/total/progress
  value, including minute and second pluralization.

The reusable `BuildContext.l10n` access pattern and the English ARB catalog are
the presentation authority. Stored enum names, preference values, timer state,
and user-authored text are unchanged. No locale was activated by B1.

## B2 — Timer dashboard and session controls

The following timer-dashboard presentation is now fully catalog-owned:

- focus, short-break, and long-break names, status headings, encouragement,
  completion copy, start/pause/reset/resume/next-session actions, and saved
  session recovery;
- visible countdown duration forms, focus-intention entry, the dashboard's
  Focus Queue entry and link boundary, and linked-task completion waiting copy;
- compact statistics, the daily focus goal and challenge, recent-focus empty
  state and rows, locale-aware relative/short dates, and the clear-history
  confirmation and receipt;
- focus-summary copy success and failure receipts plus dashboard tooltips and
  user-facing input guidance inside this boundary.

Planning and recovery cards outside the completed B3A, B3B, and B3C
presentation boundaries retain their later audited owners.
Queue sheet internals are now owned by B3A. Reminder, account, backup,
milestone-sheet internals, and Focus History sheet internals are now owned by
B5. Service and notification messages retain their B6 owner. Timer notification wording intentionally
continues to come from `TimerService` until B6. English behavior and all stored
timer, task, queue, goal, and history values are unchanged. No locale was
activated by B2.

## B3A — Queue and planning foundation

The first planning-and-recovery sub-slice is now fully catalog-owned within
these presentation boundaries:

- Focus Queue sheet headings, guidance, empty and completed states, task-action
  tooltips, completion receipt, add/select/edit/complete/remove errors, and the
  completed-task history and restore presentation;
- Haven Plan energy and time choices, preview chrome, duration forms, privacy
  boundary, acceptance and dismissal actions, dashboard entry, and start
  receipt;
- Haven Planner headings, local-only and review boundaries, goal and duration
  controls, draft and review states, proposal-context labels, uncertainty
  labels, exact queue confirmation, action states, receipts, and errors;
- the Plan-to-Focus task-decision card, its fail-closed errors, and the stale
  recovery-link receipt.

User-authored task titles and goals remain opaque placeholders: they are never
catalog keys and are not translated or sent anywhere. Planner item titles,
assumptions, explanations, Haven Plan task/step/explanation values, and other
service-originated planning text remain B6-owned. B3C now owns optional-system
connection presentation without changing planning behavior. English behavior and stored planning
data are unchanged, no locale was activated, and no permission, dependency,
backend, deployment, or store setting changed.

## B3B — Reflection and restorative guidance

The reflection and restorative presentation slice is now fully catalog-owned
within these boundaries:

- the optional, text-free completed-session reflection heading, guidance, fit
  choices, and private-save receipt;
- Haven Rhythm kind labels, presentation chrome, possible-pace unit, privacy
  note, reflection bridge, accessibility message, and agency boundary;
- Focus Forecast kind labels, expandable-card semantics, presentation chrome,
  privacy and advisory notes, reflection bridge, and agency boundary;
- Smart Reset headings, time acknowledgement, compact duration presentation,
  privacy and linked-task boundaries, and all three explicit actions;
- Haven Journey place labels, presentation chrome, accessibility and privacy
  boundaries, and the completion-to-Journey advisory.

Personal reflection content is never a catalog key: the completed-session
reflection remains text-free and stores only the existing bounded fit enum.
Service-generated headlines, details, evidence, and explanations remain B6-owned
runtime values, including Rhythm, Forecast, Smart Reset, and Journey guidance.
They are passed through the localized presentation as opaque values and are not
translated, copied to the ARB catalog, or sent anywhere. English behavior and
stored focus data are unchanged. No locale was activated by B3B, and no
permission, dependency, backend, deployment, or store setting changed. B6
remains required.

## B3C — Optional system connections

The optional-system-connection presentation slice is now fully catalog-owned
within these boundaries:

- Haven Window status and action labels, expandable-card semantics, dormant,
  held, and arrived explanations, locale-aware held-window time ranges,
  privacy and no-calendar-write boundaries, and fail-closed dashboard receipts;
- Focus Shield phase and action labels, card eyebrow, running-focus-only
  boundary, and private on-device selection boundary.

Haven Window suggestion headlines, details, and evidence and Focus Shield state
headlines and details remain B6-owned service-generated runtime values. They
pass through the localized cards as opaque values and are not translated or
copied into the catalog. B3C changes no permission prompt, calendar access,
calendar write behavior, reminder behavior, Focus Shield rule, platform bridge,
dependency, backend, deployment, or store configuration. English behavior is
unchanged. No locale was activated by B3C, and B6 remains required.

## B4 — Coaching and voice

The coaching-and-voice presentation slice is now fully catalog-owned within
these boundaries:

- local Focus Coach headings, empty state, starter prompts, quick replies,
  composer chrome, retry and clear-conversation controls, care boundary,
  accessibility labels, and local/enhanced-AI state and consent disclosures;
- Voice-to-Coach and safe-command tap-to-talk disclosure, listening,
  preparing, editable-draft, stop, discard, and permission/recognition notice
  presentation;
- Haven action heading, privacy and source labels, example commands, review
  and exact-confirmation controls, risk labels, proposal semantics, action
  states, and typed/voice composer chrome.

The voice service exposes stable notice codes to presentation code. Its English
`notice` getter remains only as a compatibility diagnostic for existing tests
and non-UI callers; production sheets map `noticeCode` through the generated
catalog. Recognition behavior, speech locale selection, permission requests,
and transcript lifecycle are unchanged.

User-authored messages and recognized transcripts remain opaque values.
Local- or remote-Coach responses, service errors and receipts, interpreted
proposal explanations and effects, and execution results also remain runtime
values with their existing service owners; they are not copied into the ARB
catalog or sent to a translation service. B6 still owns service-generated
user-facing text. Phase 215G-D must later align recognition, rule-based action
interpretation, local coaching, and fallbacks with each individually qualified
locale.

B4 records no audio, contacts no local or remote AI, changes no permission,
speech-recognition behavior, enhanced-AI gate, action policy, dependency,
backend, deployment, or store configuration. English behavior is unchanged,
no planned locale was activated, and B6 remains required.

## B5 — Account, purchases, and private records

The account-and-purchase presentation slice is now fully catalog-owned within
these boundaries:

- authentication and account-sheet headings, states, provider actions,
  privacy guidance, dashboard entry, and fail-closed app-owned errors;
- cloud-backup and restore presentation, entitlement guidance, receipts, and
  the exact cloud, local-data, and account-deletion confirmations;
- FocusHaven Pro headings, benefit and entitlement presentation, purchase and
  restore controls, and app-owned store-action errors;
- Reflection Journal chrome, stable mood display labels, editor actions,
  private-device boundary, and locale-aware dates;
- Focus Profile questions, choices, results, tips, and localized presentation
  of the existing stable stored profile identifiers;
- reminder chrome, weekday labels, scheduling guidance, test-notification
  controls, and app-owned errors and receipts;
- Focus Milestones and Focus History chrome, locale-aware dates and weekdays,
  duration/session plurals, filters, metadata, and copy-summary presentation;
- the current privacy-policy launch action and its app-owned failure message.

Private account identity, journal and reflection content, task names, and
other user-authored values remain opaque placeholders and never become catalog
keys. Stable stored mood and profile identifiers remain unchanged; small
presentation-only mappers localize their display labels without migrating,
copying, or translating stored data. Store prices remain store-owned values.
Authentication-provider errors, account-deletion results, store/backend
errors, daily prompts, and other service-generated messages remain opaque
runtime values with their existing owners; B6 still owns service-generated
user-facing text.

B5 does not sign in or out, purchase or restore an entitlement, back up,
restore, delete an account or data, request notification permission, schedule
a reminder, launch a policy, contact a provider, change a dependency, deploy,
or edit a store configuration. English behavior is unchanged, no planned
locale was activated, and B6 remains required.

## B6A — Notifications and bounded service receipts

The first service-owned extraction slice is now catalog-owned within these
boundaries:

- Flutter-owned notification titles and bodies for the explicit notification
  test, scheduled focus reminders, completed timer sessions, and one user-held
  Haven Window;
- Flutter-created Android notification channel names and descriptions for
  those same three notification categories;
- focus, short-break, and long-break labels plus the three bounded completion
  messages used by timer-completion notifications; and
- all stable account-deletion outcome receipts, mapped from the existing
  `AccountDeletionStatus` enum only when presented.

Notification identifiers, channel identifiers, schedules, time-zone rules,
permission behavior, timer state, and account-deletion behavior are unchanged.
Account-deletion results remain stable status values in the service layer; no
success or failure status is inferred from translated text. English remains
the only production locale, and the catalog fallback exists only to preserve
that current single-locale runtime until a reviewed locale-selection boundary
is implemented.

B6A requests no permission, schedules no reminder, finishes no timer, deletes
no account or data, contacts no provider, changes no dependency, deploys
nothing, and activates no planned locale. Generated planner, restorative,
Haven Window/Focus Shield, Coach, Haven action, authentication, store, journal,
and other service-owned guidance remains for later B6 slices. Phase 215G-B is
therefore not complete.

## B6B1 — Generated Haven Planner guidance

The first generated-guidance sub-slice is now catalog-owned within these
boundaries:

- empty and oversized-goal validation returned by the local planner;
- the three transparent planner assumptions and its uncertainty explanation;
- the three generated queue-item title templates and explanations;
- the informational session-size title and safety explanation; and
- the informational free-time title and explicit no-calendar explanation.

User-authored goal text remains an opaque placeholder. It is bounded by the
existing service before insertion and is never used as a catalog key,
translated, persisted by this phase, or sent anywhere. Proposal schema, IDs,
time bounds, title bounds, uncertainty level, affected-data declarations,
review choices, queue mutations, timer behavior, and calendar behavior are
unchanged. English remains the only production service catalog and the
fallback remains explicit until a later reviewed locale-selection boundary.

B6B1 creates no proposal during verification, reads or writes no calendar,
changes no queue or timer, adds no permission or dependency, contacts no AI or
translation provider, deploys nothing, and activates no planned locale.

## B6B2 — Restorative and optional-system guidance

The second generated-guidance sub-slice is now catalog-owned within these
boundaries:

- Haven Rhythm learning, recovery, pace, evidence, and reflection-connection
  guidance;
- Focus Forecast learning, flexible, emerging-window, evidence, range, and
  reflection-connection guidance;
- Smart Reset validation and its three deterministic explanation paths;
- Haven Journey place, completion-connection, validation, and non-punitive
  progression guidance;
- Haven Window unsupported, disconnected, denied, invalid, stale, learning,
  opening, no-opening, range-label, evidence, and duration-validation guidance;
- Focus Shield consent, permission, private-selection, fail-closed, starting,
  protecting, paused, break, recovery, and ready guidance.

Private reflections, completion identities, counts before they become bounded
placeholders, redacted calendar availability boundaries, and native-owned app
or website selections remain runtime values. They are never copied into ARB
keys or sent to a translator. The six services retain their deterministic
rules, thresholds, model types, local ownership, optional-permission behavior,
and explicit English fallback. English remains the only production locale.

B6B2 reads no calendar during verification, changes no queue or timer, starts
no protection, adds no permission or dependency, contacts no AI or translation
provider, deploys nothing, and activates no planned locale. Phase 215G-B is
therefore not complete.

## B6C1 — Haven action service results

The first remaining-service sub-slice is now catalog-owned within these
boundaries:

- typed- and reviewed-voice request validation and fail-closed rejection copy;
- reviewed timer, navigation, and queue-item interpretation and effect text;
- stable session, activity, and destination labels used only to assemble those
  reviewed effects;
- proposal validation, expiry, stale-state, availability, and fixed-limit
  policy decisions;
- replay, exact-confirmation, service-decline, failure, and successful
  execution receipts.

User-authored queue titles remain opaque bounded placeholders and are never
used as catalog keys or sent to a translator. English command phrases remain
the only accepted runtime grammar until Phase 215G-D aligns action
interpretation with a separately qualified locale. The action kind allowlist,
protected-operation exclusions, proposal schema and lifetime, state token,
confirmation fingerprint, replay consumption, timer and queue ownership, and
navigation callback are unchanged. Both the Haven action sheet and reviewed
Planner-to-Queue path pass the selected catalog explicitly; English remains
the only production catalog.

B6C1 creates no proposal during verification, executes no action, changes no
queue or timer, records no audio, contacts no AI or translation provider, adds
no permission or dependency, deploys nothing, and activates no planned locale.
Phase 215G-B is therefore not complete.

## Remaining Phase 215G-B slices

1. **B6C2 — Local-Coach responses and receipts:** deterministic local-Coach
   responses, enhanced-AI fallback notices, and remaining coaching service
   errors and cleanup receipts.
2. **B6C3 — Remaining service results:** authentication, store, journal
   prompts, exports, and all other audited user-facing service errors and
   receipts.

Native Apple, Android, widget, watch, permission-purpose, policy, support,
store-listing, and screenshot localization remains Phase 215G-E.

Each slice must preserve English behavior, add catalog metadata for every new
message, update focused tests, pass the complete suite and release builds, and
leave all planned locales inactive. Phase 215G-B is complete only when every
Flutter-owned source string and accessibility message has an audited owner.
