# FocusHaven Privacy-Safe Diagnostics Policy

**Effective date: August 24, 2026**

FocusHaven uses a local-first diagnostic boundary. The released client does
not include a third-party crash-reporting SDK, does not maintain an app-owned
crash-report store, and does not upload client crash reports.

This policy governs developer diagnostics in Flutter and operational logs in
the private enhanced-coaching function. It does not prevent Apple, Google, or
the device operating system from producing system crash or diagnostic reports
under the user’s platform settings.

## Client diagnostic contract

Developer builds may emit only:

- a stable event code chosen from the closed `FocusHavenDiagnosticEvent` enum;
  and
- a coarse error category chosen from the closed
  `FocusHavenDiagnosticErrorKind` enum.

The client diagnostic API accepts no arbitrary metadata or stack trace. It
never formats an exception with `toString()`. In release builds it is a no-op.
FocusHaven neither persists nor transmits this debug output.

Client diagnostics must never include:

- task names, queue items, intentions, parked thoughts, journal text, moods,
  Focus Coach messages, prompts, replies, or generated context;
- names, email addresses, account identifiers, device identifiers, tokens,
  capabilities, purchase identifiers, or authentication state;
- exact timer/session state, timestamps, filenames, URLs, request IDs, network
  details, exception messages, or stack traces; or
- arbitrary caller-provided fields, even if they appear technical.

FocusHaven does not install catch-all error handlers merely to log failures.
Ordinary framework and platform failure behavior remains unchanged.

## Private function logging contract

The enhanced-coaching function may write only structured, allowlisted fields:

- `diagnosticEvent`: one closed event code;
- `errorKind`: a coarse allowlisted category for quota-reservation failures;
- `providerStatus`: an integer HTTP failure status from 400 through 599; and
- `period`: a UTC quota month in `YYYY-MM` form.

The function must never log coaching prompts or replies, account identifiers,
authentication state, provider request IDs, arbitrary error names or messages,
stack traces, or spread caller/provider objects into a log payload.

Operational log retention is controlled by the configured Google Cloud
Logging policy. FocusHaven should keep that retention bounded and review it
before production launch; this repository does not claim a retention period
that has not been configured and verified in the service account.

## Review gate for any future crash-reporting SDK

A future SDK requires a separate product, privacy, and release decision. At a
minimum, that change must include:

1. explicit user choice with collection off by default;
2. native automatic collection disabled before SDK initialization;
3. a documented field allowlist, retention period, deletion path, processor,
   region, and store-disclosure impact;
4. adversarial tests proving private content and identifiers cannot enter a
   report; and
5. an updated privacy policy before any production collection begins.

Until every gate is satisfied, FocusHaven remains without a client
crash-reporting SDK.
