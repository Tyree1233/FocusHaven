# FocusHaven Flutter Localization Extraction Inventory

Status: Phase 215G-B1 audited extraction contract

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

## Remaining Phase 215G-B slices

1. **B2 — Timer dashboard and session controls:** session names, timer actions,
   task entry, goals, queue entry points, receipts, errors, and all associated
   semantics.
2. **B3 — Planning and recovery:** Queue, Plan, Planner, Plan-to-Focus,
   reflection, Rhythm, Forecast, Smart Reset, Journey, Haven Window, Focus
   Shield, and related advisory boundaries.
3. **B4 — Coaching and voice:** local Coach, enhanced-AI boundary text,
   Voice-to-Coach, safe voice commands, permission states, transcript review,
   and Haven action review/confirmation.
4. **B5 — Account and purchases:** authentication, account settings, backup,
   deletion, Pro, purchases, journal, profile, reminders, and support/legal
   launch surfaces.
5. **B6 — Service and notification messages:** user-facing strings produced by
   services plus Flutter-owned notification and recovery copy. Native Apple,
   Android, widget, watch, permission-purpose, policy, support, store-listing,
   and screenshot localization remains Phase 215G-E.

Each slice must preserve English behavior, add catalog metadata for every new
message, update focused tests, pass the complete suite and release builds, and
leave all planned locales inactive. Phase 215G-B is complete only when every
Flutter-owned source string and accessibility message has an audited owner.
