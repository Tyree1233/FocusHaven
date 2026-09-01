# FocusHaven Flutter Localization Extraction Inventory

Status: Phase 215G-B3B audited extraction contract

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

Planning and recovery cards outside the completed B3A and B3B boundaries remain
owned by B3C.
Coach, Haven action, reminder, account, backup, milestone-sheet internals,
Focus History sheet internals, Queue sheet internals, and service/notification
messages retain their later owners. Timer notification wording intentionally
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
service-originated planning text remain B6-owned. B3C remains required for
optional system connections. English behavior and stored planning
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
permission, dependency, backend, deployment, or store setting changed. B3C
through B6 remain required.

## Remaining Phase 215G-B slices

1. **B3C — Optional system connections:** Haven Window, Focus Shield, and their
   permission, platform-truth, and advisory presentation boundaries.
2. **B4 — Coaching and voice:** local Coach, enhanced-AI boundary text,
   Voice-to-Coach, safe voice commands, permission states, transcript review,
   and Haven action review/confirmation.
3. **B5 — Account and purchases:** authentication, account settings, backup,
   deletion, Pro, purchases, journal, profile, reminders, and support/legal
   launch surfaces.
4. **B6 — Service and notification messages:** user-facing strings produced by
   services plus Flutter-owned notification and recovery copy. Native Apple,
   Android, widget, watch, permission-purpose, policy, support, store-listing,
   and screenshot localization remains Phase 215G-E.

Each slice must preserve English behavior, add catalog metadata for every new
message, update focused tests, pass the complete suite and release builds, and
leave all planned locales inactive. Phase 215G-B is complete only when every
Flutter-owned source string and accessibility message has an audited owner.
