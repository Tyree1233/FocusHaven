# FocusHaven Spanish Reviewer Assignment

Status: Phase 215G-C2C assignment safeguards prepared; no reviewer is assigned
and review has not started

## Purpose

Phase 215G-C2C prepares a deterministic, fail-closed assignment gate for the
exact Phase 215G-C2B Spanish review packet. It does not choose, contact,
invent, or impersonate a reviewer. It creates no authorization or assignment
record, changes no packet entry, and does not begin review.

The gate exists so a later, separately authorized assignment can bind one real
qualified reviewer to the exact packet, English source, Spanish candidate, and
accepted scope without weakening the current inactive-locale boundary.

## Required real-reviewer record

A later assignment authorization must contain only these fields:

- schema version, Phase 215G-C2C, and Spanish locale identity;
- the exact packet, English-source, and Spanish-candidate SHA-256 locks;
- the exact `general_international_spanish` review scope;
- the real reviewer's name;
- a non-sensitive statement of relevant Spanish-language and localization
  review qualification;
- a conflict-of-interest or independence statement;
- an offset-aware acceptance time;
- explicit assignment authorization; and
- `reviewStarted: false`.

The repository must not contain the reviewer's email address, phone number,
home or work address, government identification, signature image, credentials,
payment details, or private communications. Contact and contracting records,
if needed, remain outside this repository.

## Assignment is not review start

The guarded tool can eventually create only
`localization/reviews/es/reviewer-assignment.json`. A successful future record
will say `assigned_not_started`, preserve all 980 pending decisions, and keep
`reviewStarted`, `linguisticallyApproved`, and `runtimeActivated` false.

Starting human review is a separate later gate. It must verify the assignment,
make an immutable working copy or equivalent reviewed artifact, and explicitly
transition the review state before any reviewer decision is entered. Assignment
alone cannot change the qualification status to `human_review`.

## Fail-closed behavior

The assignment tool refuses:

- missing, extra, placeholder, or invented reviewer fields;
- a changed packet, source, candidate, qualification, or audit lock;
- any packet containing a pre-filled decision, replacement, or note;
- an assignment that also claims review has started;
- any path outside the isolated intake and review locations; or
- overwrite of an existing assignment record.

No assignment authorization file or assignment record does exist in Phase
215G-C2C. Human review has not started, all 980 entries remain pending, and
Spanish remains linguistically unapproved, outside `lib/l10n`, runtime
inactive, release unqualified, and unsupported publicly.

## Phase 215G-C2C non-actions

This phase does not identify or assign a real qualified reviewer, distribute
the packet, begin review, fill or infer a decision, approve Spanish, copy the
candidate into `lib/l10n`, activate a locale, contact a reviewer or provider,
use private runtime data, add a permission or dependency, deploy, upload,
invoke, modify a store, or make a public language or country claim.
