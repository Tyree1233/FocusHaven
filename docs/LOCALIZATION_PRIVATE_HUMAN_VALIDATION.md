# FocusHaven Private Human Validation

Status: Phase 215G-C2D records completed private validation of the isolated
Spanish candidate; Spanish remains runtime inactive

## Result

The complete 980-message Spanish candidate was checked by a fluent first-
language Spanish speaker using the locked Phase 215G-C2B review packet. The
completed review contains 980 accepted translations, zero revisions, zero
blocked messages, zero source mutations, and zero placeholder mismatches.

The accepted text is byte-for-byte identical to the isolated candidate with
SHA-256
`611d1afcc6eb688f92d56928f08cad5dbfdef2b5031c537c53615accfb16b83f`.
The source catalog and review packet also remain at their previously locked
digests. No replacement text needs to be merged.

## Privacy boundary

The review workbook is a private working artifact and is not committed. The
repository does not record or infer the reviewer's name, email address, phone
number, employer, location, signature, payment information, qualifications,
contact details, workbook metadata, private notes, or completion timestamp.

The repository stores only a compact, anonymous validation record containing:

- the locale and exact source, candidate, packet, and sanitized-payload locks;
- aggregate message, decision, and risk counts;
- zero-count integrity checks; and
- explicit false values for personal-data inclusion and release activation.

The private sanitized payload used to verify all 980 rows remains outside the
repository. It contains only the locked translations and validation facts, not
workbook metadata or reviewer information.

## Reusable workflow

For each future language, FocusHaven can use the same short process:

1. create a locked candidate and review packet from non-sensitive catalog copy;
2. give the private workbook to a fluent first-language reviewer;
3. receive the completed workbook without collecting identity or contact data;
4. audit every decision, source value, translation, and placeholder locally;
5. retain only anonymous aggregate proof and exact content hashes in Git; and
6. run language-specific integration, layout, accessibility, voice, native,
   store, and country-release gates before advertising support.

The earlier Phase 215G-C2C named-assignment mechanism was prepared but never
used. Phase 215G-C2D uses this simpler private-validation branch instead. The
unused assignment authorization and assignment record remain absent.

## Runtime boundary

Private validation does not itself activate Spanish. Phase 215G-C3A may copy
the exact reviewed candidate into `lib/l10n` for generated-delegate and isolated
integration testing, but `FocusHavenApp` continues to use the separate
English-only production locale allowlist. Spanish voice and coaching, native
resources, public policies, store listings, screenshots, signed builds, and
country releases remain independently unqualified.

The integration phase runs Flutter generation, complete tests, explicit
Spanish rendering, ICU plural, fallback, and production-allowlist checks.
Layout, accessibility, voice, native/store, and real-device qualification still
remain before a later explicit production-activation decision.
