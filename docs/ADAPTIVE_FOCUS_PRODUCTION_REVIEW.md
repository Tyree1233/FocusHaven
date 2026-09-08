# Adaptive Focus production review gate

Status: Phase 216D copy lock prepared; production presentation remains closed.

## Purpose

Phases 216A through 216C already produce one bounded local suggestion, expose
one accessible review card, and allow the timer owner to apply one exact
reviewed duration pair without starting a session. Phase 216D prepares the
missing production copy and placement contract without weakening those
boundaries or invalidating the sixteen reviewed runtime catalogs.

The English proposal is isolated at
`localization/proposals/app_en_adaptive_focus_review.arb`. It is not a Flutter
runtime catalog. No generated localization class or production screen reads
it, so preparing or revising this copy cannot expose an English fallback in a
non-English interface.

## Proposed placement

After every active locale has a complete reviewed version of the proposal, the
card may appear on the timer dashboard immediately after Focus Forecast. It may
appear only for a fresh, stopped, incomplete Focus session when:

- timer initialization has completed;
- Focus and short-break defaults are whole minutes;
- `AdaptiveFocusService` returns a suggestion that changes at least one value;
- the suggestion matches the timer owner's exact live defaults; and
- `AdaptiveFocusDelegationService.beginReview()` returns a fresh one-use owner
  ticket.

The card must disappear when any of those conditions stops being true. A newer
valid suggestion supersedes the previous ticket.

## Copy contract

Every locale must review complete strings for:

- a gentler title and a room-to-grow title;
- complete current and suggested plan lines;
- separate recovery, reflection, Rhythm, and optional Forecast explanations;
- the local text-free privacy boundary;
- the no-automatic-change and stopped-timer boundary;
- one complete screen-reader summary;
- distinct keep-current and use-suggestion actions; and
- applied, kept-current, and stale-state outcomes.

Translators may reorder placeholders as their language requires. Placeholder
names, counts, and types must remain exact. The product must not assemble a
production sentence from translated fragments.

## Review and activation sequence

1. Lock this English proposal and its metadata.
2. Create private draft translations for the other fifteen active languages.
3. Run independent fluent review of every proposed message and placeholder.
4. Merge only complete approved deltas into the English source, the sixteen
   production catalogs, and the mechanical base `pt` fallback.
5. Regenerate Flutter localization and verify no existing catalog message
   changed.
6. Add the production adapter and deliberate dashboard placement.
7. Verify keep-current, accept, stale-state rejection, no-start behavior,
   persistence, semantics, large text, narrow layouts, and all active locales.
8. Run the complete Flutter suite, analysis, and fresh web, Android, and
   unsigned iOS builds before committing or pushing the activation.

## Authority and privacy boundary

The proposal contains only public interface copy. It contains no task,
journal, reflection, coaching, transcript, account, calendar, or reviewer data.
It grants no persistence, timer-start, queue, calendar, Haven Action, local-AI,
remote-AI, network, deployment, or publication authority. The existing timer
service remains the only owner allowed to persist a reviewed duration pair.
