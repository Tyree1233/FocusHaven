# Apple system-assistant ingress review gate

Status: Phase 217G availability-gated App Intent and App Shortcut registration
active on iOS 16 and later; execution, release, and Android registration closed.

## Purpose

Phase 217E adds the smallest iOS-native transport that can eventually carry a
reviewed system-assistant request into the Phase 217D app-level review host. It
does not make a command discoverable to Siri or Shortcuts. Native titles,
descriptions, invocation phrases, and result dialogue are new public copy and
must complete the same independent fifteen-language review discipline before
registration.

The adapter mirrors exactly five Phase 217A routes:

- read timer status;
- start a Focus timer with no duration parameter;
- pause the timer;
- resume the timer; and
- open Focus Queue.

No native route exists for adding time, starting a break, editing a queue item,
passing a task, or supplying an arbitrary parameter.

## Exact wire contract

One request contains exactly three values: schema version `1`, one opaque
ASCII invocation ID of at most 128 characters, and one allowlisted route name.
The Swift and Dart sides both reject unknown fields, malformed identifiers,
unsupported schema versions, and unknown routes. There is no field for a
transcript, utterance, task title, journal, reflection, coaching history,
account value, requested duration, queue text, or other user-authored content.

The native store holds at most one request in process memory. It writes no
defaults, file, keychain, cloud value, analytics event, or log. A second request
is rejected. The first request remains pending until Flutter returns `true`
after the existing `HavenSystemIntentInbox` accepts the exact payload; a failed,
malformed, unhandled, or capacity-blocked delivery is not acknowledged or
cleared.

## Production ownership

On iOS, the private method-channel adapter is installed with the existing
implicit Flutter engine. A lifecycle host asks for delivery after its handler
is ready and whenever the app resumes. Android, web, macOS, Windows, and Linux
leave this host dormant.

Acknowledgement grants no action authority. The native adapter and lifecycle
host import no timer, queue, review service, or Haven Action Engine. An accepted
request enters only the Phase 217D memory inbox. The existing preparation,
fresh-state proposal, two-minute expiry, visible localized review, exact
confirmation, policy revalidation, and service-owner execution path remains
unchanged.

## Availability-gated registration boundary

Phase 217G adds one dedicated App Intents source, exactly five parameter-free
`AppIntent` conformances, exactly five App Shortcuts, and a mechanically derived
seventeen-locale `AppShortcuts.strings` family. The registration call is
guarded by iOS 16 availability while the deployment target remains iOS 15. No
Siri entitlement, Siri usage description, supported-intent declaration, deep
link, dependency, Android manifest entry, or Android resource is added.

The registration foundation preserves these requirements:

1. lock every native title, description, phrase, parameter summary, and result
   statement as complete English copy;
2. obtain independent fluent approval for all fifteen non-English production
   languages and derive base Portuguese only from reviewed Brazilian
   Portuguese where applicable;
3. compile availability-gated App Intents only on supported Apple OS versions
   without changing behavior on iOS 15;
4. prove every invocation opens FocusHaven for review and never reports that an
   action succeeded before the in-app Confirm action settles it;
5. test cold launch, warm launch, replay, stacking, cancellation, stale owner
   state, large text, VoiceOver, Siri, and Shortcuts on real supported devices;
   and
6. complete fresh signed release builds, privacy/store disclosure review,
   candidate validation, and explicit distribution authorization.

Apple registration cannot authorize Android registration. Android App Actions
remain a separate later adapter, copy, test, and release gate.

## Phase 217F native-copy review foundation

Phase 217F completes the first two preparation steps without opening the third.
The isolated English proposal in
`localization/proposals/app_en_apple_system_assistant_native_review.arb`
contains exactly twenty-eight complete messages and metadata records. The
external incremental-review manifest locks fifteen independent fluent reviews,
Japanese and Korean font-coverage gates, and one later derivation from approved
Brazilian Portuguese to base Portuguese.

The proposal is not imported by Runner, copied into Swift, or merged into the
Flutter runtime catalogs. Existing runtime-catalog hashes are only freshness
locks for the supported-language set. No provider draft, CSV, workbook,
approval, Apple string catalog, App Intent, App Shortcut provider, Siri
entitlement, or native public copy is created by this foundation.

Phase 217G consumes only the all-language approved native copy, preserves the
Phase 217E three-field request and in-app confirmation boundary, and remains
availability-gated above iOS 15. Real-device Siri, Shortcuts, large-text, and
VoiceOver review plus signed release and store gates remain uncompleted. The
independent fifteen-language review grants no Android or release authority.

The completed Phase 217F integration now supplies the exact reviewed catalog
and typed lookup needed by a later adapter. It does not call the Phase 217E
store or platform channel, and it cannot submit, acknowledge, clear, confirm,
or execute a request. The ingress payload remains exactly schema version,
opaque invocation ID, and route kind. Phase 217G registration may submit only
that request and opens FocusHaven; it cannot acknowledge delivery as in-app
confirmation or call any timer, queue, review-settlement, or execution owner.
