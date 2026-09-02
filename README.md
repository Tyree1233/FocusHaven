# FocusHaven

FocusHaven is a calm, local-first focus timer and wellbeing companion for
Android, iOS, macOS, and the web.

Apple system-focus surfaces now complete the same large-text and screen-reader
boundary as their Android counterparts. The iPhone widget exposes its timer
state separately from every interactive link, announces human-readable
duration and bounded progress, identifies a running value as a live countdown,
and gives every control a full-height, wrapping label at accessibility sizes.
Its visual countdown uses a scalable text style and can contract inside the
fixed WidgetKit canvas without changing command URLs. Apple Watch
uses a scrollable waiting state, a reduced large-text heading, width-bounded
countdown text, vertically stacked 44-point controls at accessibility sizes,
and the same coherent duration/progress semantics. All action labels remain
explicit, while private snapshot content, destructive confirmation, phone-side
authority, stale-command checks, and replay protection are unchanged.
On iOS 16 and later, that same extension now offers purpose-built inline,
circular, and rectangular Lock Screen families. They remain read-only,
text-free status surfaces: the exact validated session, calm activity,
remaining time, and bounded progress are available at a glance without putting
task, journal, queue, mood, coaching, history, or account content on a locked
device. The iOS 15 Home Screen widget and its existing medium-size private
controls remain unchanged.
When a focus timer is actively running on iOS 16.1 or later, FocusHaven may
also start one system Live Activity. Its Lock Screen banner and complete
Dynamic Island presentation show only the validated session kind, calm state,
remaining time, deadline, and bounded progress. Paused and pending-resume
snapshots can update an existing surface but never create a new interruption;
ready state removes it immediately, completion ends it with final state, and a
system-disabled Live Activity is dismissed. The payload remains below
ActivityKit's four-kilobyte boundary and carries no command capability or
user-authored content. All Live Activity regions are intentionally read-only.

On Android, a running timer can now publish one low-interruption ongoing
notification using the notification access the person has already chosen. Its
notification-drawer and Lock Screen presentation contain only the validated
session kind, calm activity, system-rendered deadline countdown, and bounded
progress; task, journal, queue, mood, coaching, history, and account content
never enter it. Pause, resume, reset, and recovery controls use immutable
snapshot-specific intents and the same non-exported command trampoline,
app-private inbox, stale/replay checks, and Flutter authorization router as the
home-screen widget. Paused or pending-resume state can update only an already
active notification, while ready, completed, malformed, denied, or expired
state removes it. The surface never requests permission, starts a foreground
service, polls, or changes the timer directly, and it restores or settles only
from the private snapshot after reboot or package replacement.

Android system-focus surfaces now adapt without weakening their private command
contract. The home-screen widget selects a compact layout when either launcher
dimension is below 180 dp or the system font scale reaches large-text size; its
minimum resize size is 110 dp, both layouts retain 48 dp controls, and compact
mode hides duplicate decoration while preserving the complete semantic timer
state. Static states announce human-readable duration and completion progress,
while a running state identifies its live countdown instead of freezing a stale
spoken timestamp. Package replacement also republishes every bound widget so an
app update cannot leave stale presentation or accessibility metadata. Wear OS
uses smaller round-screen insets, vertically growing
two-line controls, a width-bounded countdown, one coherent duration/progress
description, and explicit focus-timer action labels. These presentation rules
derive only from the validated text-free snapshot and do not alter command
authorization, replay protection, or phone authority.

The core session countdown now adapts to its available width instead of
assuming a fixed phone layout. Large accessibility text scales down only when
needed to stay inside the timer ring, and screen readers receive one coherent
remaining-time, total-duration, and progress description. Reset and primary
timer controls wrap onto another line on narrow or enlarged-text surfaces
without changing the timer's authorization or persistence behavior.

Focus Shield now has one compact, expandable dashboard surface for its private,
text-free decision state. It distinguishes opt-out, unsupported, permission,
selection, ready, starting, confirmed, paused, and failed states without
invoking platform APIs. The surface claims protection only after a native
adapter independently confirms enforcement, and it can expose only the actions
admitted by the current state through an explicitly supplied host callback.
Protection is requested only for an actively running focus session; breaks,
timer pauses, completed sessions, and recovery decisions remain open. App and
website selections never enter Flutter state or FocusHaven history. Every
platform defaults to unsupported and blocks nothing until its separately
consented, tested adapter is installed. iPhone now installs the first adapter
with Apple's Family Controls and Managed Settings frameworks. Authorization,
distraction selection, pausing, resuming, and disabling remain explicit user
actions. Apple supplies only opaque selection tokens, which stay encoded in
app-private iOS preferences and never cross the Flutter channel. FocusHaven
receives only a bounded capability state and reports protection only after the
requested shields can be read back from the system settings store. Android
continues to report unsupported because its consumer APIs do not provide an
equivalent privacy-preserving enforcement contract.

System widgets, lock-screen experiences, notifications, and watch companions
share one versioned system-focus snapshot. The contract contains
only the session kind, timer activity, bounded duration, UTC timestamps, and
the commands valid for that state. It excludes task names, reflections,
journal and coaching content, focus history, moods, and account identifiers by
construction. The snapshot is derived locally, is not persisted by itself,
and cannot mutate the timer or invoke platform code.
Commands arriving from those future surfaces use a separate text-free envelope
with a bounded request ID and the exact UTC snapshot time the person acted on.
FocusHaven accepts an action only when the snapshot still advertises it, rejects
stale and replayed requests, contains callback failures, and keeps platform
transport separate from timer mutation.
The dormant platform bridge uses one dedicated method channel, serializes
snapshot publications, rejects malformed native payloads, and disables command
handling when its initial publication cannot reach a native adapter. Android,
Apple, web, and desktop builds do not start this bridge until an intentionally
supported native surface is installed and tested.
Android now installs the first strict native adapter. It validates the complete
versioned map again in Kotlin, rejects unknown fields and impossible timer
states, and stores only that text-free snapshot in app-private preferences.
The Flutter lifecycle host starts synchronization only on Android, preserves a
running session by its authoritative deadline, and skips equivalent one-second
writes. Android home screens can now add a responsive, read-only FocusHaven
widget that shows the session kind, calm timer state, progress, and a live
system countdown. It reads only the validated private snapshot, performs no
periodic background work, and uses immutable start, pause, resume, reset, and
next-session controls. Each control enters through a non-exported Android
trampoline, is rechecked against the exact app-private snapshot, and queues one
text-free command. Flutter waits for timer restoration, claims a cold-start
command once, and still applies the stale, replay, and advertised-action gates
before any mutation. No widget code can directly change the timer or expose
task, reflection, mood, history, coach, or account data.
Every Android widget command now gives its immutable `PendingIntent` a distinct
identity derived from the advertised action and exact snapshot timestamp. A
launcher therefore cannot retain extras from an older rendered state. Warm
commands remain queued unless Flutter explicitly returns `true`, so a rejected
or unavailable handler cannot silently discard the person's action.
Cold-start recovery also bounds a persisted future deadline to the validated
session total before publishing. Clock rollback or damaged local timing data
therefore cannot invent extra focus time or strand phone widgets on stale state;
the recovered timer remains paused and explicitly awaits the person's choice.
A completed timer is now persisted as an explicit lifecycle state. Older
zero-second records with no deadline migrate to that same completed state on
cold start, while incompatible completion metadata is repaired locally. This
keeps the intended next-session action available after an app restart and lets
every native surface replace a stale snapshot with the authoritative completed
state instead of leaving the app stranded at an unstartable 00:00.

iOS now installs the same dedicated Flutter channel through a strict native
adapter. Swift revalidates every field, enum, duration, null, and UTC timestamp
before storing the text-free snapshot as private JSON data in an app-group
container shared only with FocusHaven extensions. The first read-only iPhone
Home Screen widget shows the session kind, calm state, progress, and live
system countdown without polling or private user text. Its medium layout offers
start, pause, resume, reset, discard, and next-session controls only when the
exact rendered state permits them. Each link carries a rotating private
capability, enters one app-group command inbox, and is rechecked against the
current snapshot before Flutter applies its stale, replay, and advertised-action
gates. Synchronization waits for timer restoration; the iOS 16 Lock Screen
families and iOS 16.1 Live Activity/Dynamic Island presentation are read-only,
and Live Activity commands remain disabled. A paired Apple Watch receives only
the latest bounded, text-free timer snapshot through WatchConnectivity. The
Watch app and its WidgetKit complication share only that validated snapshot
through the registered app-group container, and a valid incoming state reloads
the inline, circular, rectangular, and corner complication families.
Complications remain read-only and open the Watch app for any action. The
companion shows the current focus or
break, calm state, progress, and a live local countdown. It offers only the
start, pause, resume, reset, discard, or next-session actions advertised by the
exact displayed state. Every request is bounded, expires after one minute, and
is consumed once on the iPhone before Flutter independently applies its stale,
replay, and advertised-action gates. Destructive watch actions require an extra
confirmation. The watch stores no task, reflection, mood, history, coach, or
account data and cannot bypass phone-side timer authorization.
Both UIKit application and scene lifecycle callbacks now enter one shared
private-URL command handler. Cold scene connections queue the authenticated
command before Flutter attaches and request delivery again after connection;
application-level URL delivery provides the equivalent fallback when iOS does
not include the URL in scene connection options. The same snapshot identity,
single-use capability, pending-command expiry, and Flutter authorization gates
remain mandatory on both paths.
An accepted watch command now receives its text-free result before the
resulting snapshot is published back through the same native transport. That
publication remains serialized and best-effort, and a watch-state change
retries the latest pending snapshot when the companion becomes available. This
prevents the command reply and its follow-up state from waiting on each other
without weakening either authorization boundary.
System-surface snapshot timestamps are canonicalized to the millisecond
precision shared by Dart, Swift, Kotlin, and companion-device transports, so
exact stale and replay checks survive a native round trip without accepting a
different snapshot.

Wear OS now has the same privacy-first foundation as a separate non-standalone
watch app with the phone's package and signing identity. Android publishes one
urgent Data Layer item only when the validated timer state changes. The watch
accepts only the exact bounded contract, rejects unknown or impossible payloads,
and advances running time locally from the UTC deadline instead of waking for
one-second network updates. Its round-safe, accessible surface offers only the
actions allowed by the exact displayed state. Each request contains a random ID
and opaque snapshot token; the phone revalidates it, persistently rejects
replays, queues it through the shared Flutter authorization router, and returns
a text-free receipt. Reset and discard require confirmation, and the watch does
not claim a mutation before the phone publishes the resulting state. After that
state arrives, a bounded one-second input cooldown keeps a repeated tap from
falling through to the newly rendered action in the same button position. It
carries no task, reflection, mood, history, coach, or account data. macOS, web,
and every unsupported platform remain dormant.
The same exact schema-v2 snapshot now feeds a private Wear OS Tile and a
user-selected watch-face complication data source. A background Data Layer
listener validates and stores only the newest snapshot in app-private storage,
then requests bounded system-surface refreshes. The Tile shows the current
session, calm state, and remaining time; the complication supports short-text
and ranged-progress slots with a system-rendered live deadline. Both surfaces
are deliberately read-only and open the full Watch app for any timer action.
They never receive a command token or private task, journal, mood, queue,
coaching, history, or account content.

The Living Lantern turns only the current timer state and bounded, text-free
focus events into one ephemeral companion state. The dashboard presents the
same whole lantern while it is ready, steadily focusing, resting, celebrating,
or offering a gentle return. It never loses health, breaks, dies, or removes
progress after an interrupted attempt. Its state is derived locally, is never
persisted by itself, and cannot start, pause, reset, or otherwise control the
timer. The accessible visual contains no productivity score or competitive
progress mechanic.

The private Haven Journey turns the timer's existing cumulative completed-
session count into a lantern, campsite, cabin, garden, or sanctuary. It is
derived locally and never persisted as a separate profile, score, level, or
public rank. Short and long completed focus sessions are valued equally, while
pauses, resets, rest, missed days, and time away can never shrink the Haven or
remove something already built. The foundation is informational only and does
not start sessions, change the timer, or pressure the person toward another
milestone. The dashboard now presents the current place as one complete,
responsive scene with its compassionate explanation and a private, non-scoring
boundary note. It never displays a progress bar, next-stage countdown, missing
item, locked reward, or control that can alter a focus session.

The optional Haven Plan check-in turns the user's current energy, available
time, focus queue, and text-free local focus events into a transparent session
preview. Plans are created on-device, are never persisted by themselves, and
cannot start a timer until the user explicitly accepts the recommendation.

Smart Reset responds to an interrupted focus attempt with a smaller, private
restart suggestion. The running timer pauses while the user decides, cancelling
restores the prior session, and accepting the suggestion changes only that one
attempt rather than overwriting the user's normal focus duration.

After a completed focus session, an optional one-tap reflection lets the user
mark the session as too much, about right, or capable of a little more. The
signal is text-free, stored with private focus events, and can gently adjust a
future Haven Plan. Recovery patterns plus the user's current energy and
available time always take priority, and skipping the reflection never blocks
the next break.

The local Haven Rhythm engine turns repeated text-free focus events into one
plain-language observation at a time. It requires multiple signals before
describing a pattern, explains the evidence behind each observation, and says
when feedback is mixed or still incomplete. Insights are ephemeral and never
become a productivity score, diagnosis, or remote profile.

The dashboard surfaces that observation in a compact Haven Rhythm card. Its
headline stays visible without interrupting the timer; the explanation,
evidence, possible pace, and privacy note appear only when the user expands the
card. The card is informational and cannot start, schedule, or alter a session.

The private Focus Forecast cautiously observes when recent completed sessions
began in the device's local time. It requires several completed signals and a
clear repeated cluster before naming a possible window; sparse or mixed timing
stays explicitly uncertain. Interrupted attempts never count against any time
of day, and the forecast never claims to know the person's best performance,
predict success, schedule work, or rank one part of the day. The ephemeral
result contains no task, journal, mood, coaching, or account data.

The dashboard presents that observation in a compact Focus Forecast card. Its
headline stays visible while the supporting evidence, uncertainty boundary,
and on-device privacy note remain behind an explicit tap. The card is
informational: it cannot start the timer, create a schedule, or turn a possible
window into a required routine.

The private Haven Window foundation prepares for optional calendar assistance
without exposing calendar content to FocusHaven. Its bounded Flutter contract
can receive only connection status, a short availability range, and redacted
busy-time boundaries—never calendar names, event titles, notes, locations,
attendees, or account identities. It offers at most one opening when a clear
Focus Forecast overlaps genuinely free time. It never creates an event,
changes the timer, predicts success, or pressures the user when no opening
fits. Platforms without a separately reviewed native adapter keep the provider
unsupported and read nothing.

The Haven Window platform controller uses one strict native channel. Its iPhone
and Android hosts check existing calendar authorization at startup without
showing a permission prompt. Only the card's explicit review action can request
calendar access; FocusHaven then reads event time boundaries without creating
or changing events. Each native adapter merges, bounds, and limits those UTC
busy intervals before Flutter can receive them. Their payloads have no fields
for calendar names, event text, attendees, locations, notes, URLs, identifiers,
or account data. Oversized fragmentation fails closed as busy time, while
unknown fields, malformed timestamps, overlapping operations, and transport
failures are contained without retaining stale availability. Web and desktop
leave this bridge dormant until they have separately reviewed adapters.

The Flutter suggestion boundary independently verifies every redacted busy
interval again. A block that begins before or ends after its declared snapshot
range invalidates the whole snapshot instead of being ignored or influencing
an opening outside the native adapter's reviewed bounds.

The dashboard now includes a consent-first Haven Window card. While the native
bridge is dormant, it says calendar assistance is off and presents no inert
setup control. After a reviewed host checks existing authorization, the card
can offer only the action appropriate to that state: review calendar access,
recheck a denied choice, or refresh redacted availability. Its expanded details
state that event content stays outside FocusHaven and that the feature cannot
create events, start the timer, or turn a possible opening into an obligation.

The private Haven Window hold foundation can remember one opening only after
the user explicitly chooses it. It stores just the opening's bounded UTC start
and end times in local preferences and schedules one generic local
notification at the start. It never copies event content, creates or edits a
calendar event, automatically holds a suggestion, or reschedules anything
during app restoration. Expired and malformed holds are removed locally, and
releasing a hold cancels its notification. The expanded Haven Window card now
offers an explicit **Hold this window** action only when a valid opening is
available. A held opening is labeled as one private local reminder and can be
released from the same card. The surface never calls the calendar write APIs,
never describes the opening as reserved, and never starts the timer.

The gentle Haven Window arrival lifecycle derives one additional text-free
state from those same local UTC boundaries. At the held start time, the state
can say that the optional opening has arrived; at the end time, it expires and
removes its saved boundaries automatically. App restoration never reschedules
the notification, and the boundary clock cannot start a session, write to a
calendar, extend an opening, or infer whether the person used the time. This
keeps a stale hold from lingering while reserving every follow-through choice
for an explicit future action.

When that arrival state is visible, the Haven Window card still leaves the
timer untouched. It offers **Begin focus** only for a fresh, idle focus session
and offers **Let this window pass** as a consequence-free release. Beginning
first removes the private hold and then uses the existing timer start path;
paused, completed, resumed, break, or otherwise active sessions never receive
an invented start control. No choice writes to the calendar or reports whether
the opening was used.

If FocusHaven was suspended while a held boundary passed, the private hold
clock now reconciles immediately when the app returns to the foreground. That
catch-up reads only the already-saved UTC start and end boundaries: it does not
reread calendar availability, request permission, schedule another
notification, or treat reopening the app as evidence that focus happened.

The optional opening is also recalculated from a fresh local clock whenever
the app resumes or the private hold changes. FocusHaven therefore never keeps
offering a hold whose start boundary has already arrived: an opening beginning
exactly now advances to the next five-minute boundary or disappears if it no
longer fits. This refresh still uses only the existing redacted availability
snapshot and does not reread the calendar, request access, or run a background
clock.

Redacted calendar availability now has a short local freshness boundary. Once
its captured range is more than fifteen minutes old—or no longer covers a
future moment—FocusHaven removes every hold action and asks for an explicit
refresh instead of treating cached free time as current. The app never refreshes
that snapshot on its own, so returning from the background still cannot prompt
for access or silently reread the calendar.

The explicit hold action now repeats that freshness check at the instant of
the tap. If the dashboard has remained open while its redacted snapshot ages,
FocusHaven removes the opening before it can request notification permission,
schedule a reminder, or save local hold boundaries. The person may then choose
whether to refresh; no calendar read happens as a side effect of the failed
hold.

The hold service also rechecks the opening after the system notification
permission sheet closes. If that consent step stayed open until the proposed
start passed, FocusHaven stops before scheduling a reminder or saving any hold
boundaries. Granting notification access therefore never turns an expired
opening into a hold, and the app still does not reread the calendar or start
the timer as part of that check.

Reminder delivery has the same final boundary. After the native scheduler
returns, FocusHaven checks the local opening once more before saving it. If the
start passed while scheduling was in flight, the just-created reminder is
cancelled and no hold boundaries are persisted. This keeps a delayed platform
operation from manufacturing an already-arrived hold.

The local persistence commit is guarded too. FocusHaven rechecks the opening
after both UTC boundary writes complete but before publishing the hold to the
dashboard. If that final write crossed the proposed start, it cancels the
reminder and removes both keys, so restoration can never recover a hold that
was already stale when its save finished.

Both boundary writes must also report that they reached private local storage.
If either write is rejected, FocusHaven treats the entire commit as failed,
cancels the just-created reminder, clears both boundary keys, and never
publishes the hold. A partial platform write therefore cannot look like a
durable Haven Window in memory or return after an app restart.

Removal is verified with the same care. Releasing a held window cancels its
reminder and requires both private boundary removals to report success before
the dashboard says the hold is gone. If local storage rejects that cleanup,
the action fails honestly and keeps the held state available for another
release attempt instead of claiming that potentially restorable data vanished.

Expiration remains gentle even when local storage temporarily rejects cleanup.
The passed window disappears from the dashboard immediately, while FocusHaven
remembers only that private cleanup is still pending. The next foreground
resume retries removal without requesting access, scheduling a reminder, or
restoring the expired window to the interface.

## Focus Coach server

The optional remote Focus Coach runs through an authenticated Firebase callable
function. The OpenAI API key belongs only in Google Secret Manager and must
never be added to this repository or a Flutter build.

From the project root, install and test the server dependencies:

```sh
npm install --prefix functions
npm test --prefix functions
```

Configure the production secret interactively, then deploy the function:

```sh
firebase functions:secrets:set OPENAI_API_KEY
firebase deploy --only functions:focusCoach
```

The deployed callable fails closed unless the server-side
`REMOTE_COACHING_ENABLED` parameter is explicitly set to `true`. Leave it
`false` until App Check is configured for every supported production client,
server-enforced Pro entitlement verification and usage quotas are deployed,
and billing alerts are active. The callable requires App Check and consumes
tokens to reduce replay attempts. The server switch is an emergency kill
switch; the Flutter build flag below does not replace it.

Even when that switch is enabled, the callable requires server-issued
`focusHavenProPlan` and `focusHavenProExpiresAt` Firebase Auth claims for an
unexpired monthly or annual subscription. Client storage and purchase events
cannot mint these claims. Until trusted store receipt validation can issue and
revoke them, every remote coaching request remains denied.

The function also reserves usage through a Firestore transaction before each
provider call. Monthly and annual plans currently receive 120 enhanced replies
per UTC calendar month. The usage collection is outside client-readable paths,
uses hashed user identifiers, rejects malformed counters, and fails closed when
Firestore cannot verify the allowance. Provider failures may still consume a
reservation so concurrent retries cannot overspend the configured budget.
The same transaction also enforces a server-wide ceiling, which defaults to
1,000 enhanced replies per UTC month through the
`REMOTE_COACHING_GLOBAL_MONTHLY_LIMIT` parameter. This aggregate circuit
breaker applies across every account. A request rejected by it does not consume
the user's personal allowance and falls back locally without describing the
server's private budget state.
When the allowance is exhausted or the remote service cannot be used, the
client keeps the submitted message, answers through the private local coach,
and explains the handoff without exposing backend error details. Only the
server's explicit monthly-quota reason is shown as allowance exhaustion;
provider capacity failures remain temporary-service notices.

Normal builds keep the enhanced-coaching interface hidden so the local coach
remains accurate whether the paid backend is absent or deployed with its
server-side switch disabled. A deployed callable does not make enhanced
coaching available: the client release flag, server enablement gate, App Check,
verified entitlement, and quota checks must all pass. Before producing an
enabled build, register the Android, Apple, and web apps under Firebase App
Check. FocusHaven uses Play Integrity in Android releases, App Attest with
DeviceCheck fallback in Apple releases, and reCAPTCHA Enterprise on web. Debug
builds use Firebase debug providers; register their generated tokens only for
trusted development devices and never distribute a debug build.

App Check initialization is not tied to the enhanced-coaching feature flag.
Every supported build initializes the platform provider after Firebase so the
protected account-deletion callable is also covered when enhanced coaching is
off. The iOS Runner App Attest entitlement is pinned to the production
environment; the watch and widget extensions do not request that entitlement.
A release web build requires `FIREBASE_APP_CHECK_WEB_SITE_KEY`; if
attestation cannot initialize, protected Firebase actions fail honestly while
the rest of the app remains available.

The production App Attest correction is represented by clean commit
`1df910c1f2b3d36965393fa767850e6f885f5982`. Its controlled 1.0.0 (1)
distribution export has SHA-256
`951c01fda19c97a354766f6f8190b2c75509c9776571791bb91f26e0b414e633` and
completed Apple's validation-only workflow on August 28, 2026. Validation
was operator-observed in Xcode Organizer as completed with non-blocking
missing-dSYM warnings for the third-party
`FirebaseFirestoreInternal.framework`, `RecaptchaEnterpriseSDK.framework`,
and `absl.framework` binaries. No App Store build was delivered, no TestFlight
content was created or released, nothing was submitted for review, and the
Gate 4 production canary remains pending.

The Firebase CLI is pinned to project `focushaven-68c59` through
`.firebaserc`. Firebase Hosting serves the release output from `build/web` and
rewrites application routes to `/index.html`. Keeping this configuration in
source does not deploy the site; a production Hosting deployment remains a
separate, explicitly authorized release action.

Private coaching history is also commit-checked before it is treated as saved.
If local storage rejects the user's message, FocusHaven rolls the unsaved text
back, does not invoke either coach, and reports that the response could not be
completed. A coach reply is surfaced only after the bounded conversation has
been verified in local storage.

Enhanced AI consent is commit-checked before the active responder changes. A
rejected opt-in cannot enable the enhanced responder, while a rejected opt-out
keeps the prior consent state visible and asks the user to retry instead of
claiming that an unsaved preference took effect.

Private coaching deletion is verified per stored value. If history or consent
cannot be removed, FocusHaven keeps the uncleared state visible and reports that
cleanup is incomplete; values that were verifiably removed disappear without
waiting for the remaining cleanup to succeed.

Private coaching restoration also verifies every repair. Malformed history or
consent is only treated as removed after storage confirms deletion, and a
normalized conversation is only treated as repaired after its replacement is
verified. Failed repairs stay private, remain recoverable for another cleanup
attempt, and surface an honest local error instead of being silently ignored.

Private coaching deletion failures are contained per value. If one storage
operation throws, FocusHaven still attempts the remaining requested cleanup,
keeps any uncleared history or consent visible, and reports a retryable local
error rather than leaking the storage exception through the interface.

Enhanced-coaching consent changes also fail closed when local storage is
unavailable. An interrupted opt-in or opt-out keeps the last verified choice,
contains the storage failure, and presents the same safe retry path as a
rejected preference write.

Private coaching storage actions are serialized. A conversation send, consent
change, or local-data deletion already in progress prevents another action from
mutating the same private values until the first operation has finished.
That private-action state is surfaced to the coaching sheet so its message,
consent, and deletion controls remain disabled until the verified operation
finishes, even when it began outside the sheet.

The app-wide local-data deletion gate requires a verified coaching cleanup
before removing the remaining local stores or leaving the account screen. If
coaching history or consent is busy or cannot be removed, the action stays on
screen and reports an incomplete deletion so the user can retry.

In-flight coaching also stops at lifecycle boundaries. If its service is
disposed while the user's verified local save or a coach response is pending,
FocusHaven does not invoke a responder afterward or persist a reply that
arrived after disposal. The already verified user message remains private on
the device for the next service instance to restore.

The coaching composer preserves text that never reached verified local
storage. A rejected initial conversation write restores the uncommitted draft
for an explicit retry, while a user message that was saved before a responder
failure remains only in the conversation and is not duplicated in the input.

When a verified user message has no coach reply, the conversation exposes one
explicit response retry. The retry reuses the saved message and current
FocusHaven context, follows the same local and enhanced-coaching safety gates,
and commits only the missing reply instead of duplicating the user's text. An
unanswered message restored after restart remains retryable.

An unanswered saved message must be resolved before another message can be
submitted. FocusHaven keeps any newly typed draft in the composer, disables its
send action and contextual quick replies, and leaves the explicit response
retry available. This prevents a newer prompt from hiding or duplicating the
pending private coaching turn.

After the function, secret, App Check registrations, entitlement verification,
and quotas are available, enable the interface at build time:

```sh
flutter build web --release \
  --dart-define=ENABLE_REMOTE_COACHING=true \
  --dart-define=FIREBASE_APP_CHECK_WEB_SITE_KEY=your-recaptcha-enterprise-site-key
flutter build appbundle --release --dart-define=ENABLE_REMOTE_COACHING=true
```

Never enable this flag in a production build before the function is ready and
the independent server-side switch has been reviewed. If App Check cannot be
initialized, FocusHaven keeps the local coach available and does not construct
the remote responder.

The model defaults to `gpt-5.6-terra`. To change that non-secret deployment
parameter, set `OPENAI_MODEL` when prompted by the Firebase CLI. Provider
requests use the Responses API with response storage disabled. FocusHaven keeps
its local coaching responder available when the function, network, or provider
is unavailable. Enhanced coaching is off by default and requires an explicit
in-app disclosure and opt-in. Disabling response storage does not disable the
OpenAI API's default abuse-monitoring retention; keep the privacy policy aligned
with OpenAI's current [API data controls](https://developers.openai.com/api/docs/guides/your-data).

## Features

- Focus, short-break, long-break, and custom-duration sessions
- Pause, resume, reset, add-time, and persisted timer recovery
- Focus queue with editing, completion history, and task restoration
- Daily goals, streaks, session history, challenges, and milestones
- Privacy-safe focus events for future recovery and rhythm recommendations
- Transparent local Haven Plans shaped by available time and energy
- Distraction parking for thoughts that can wait until after a session
- Reflection journal with daily prompts and mood history
- Guided breathing, configurable reminders, and appearance themes
- Focus profile questionnaire with saved results
- Guest access with optional Google sign-in and Firebase cloud backup
- User-controlled deletion of local data and cloud backups
- Subscription-aware FocusHaven Pro foundation with legacy purchase restoration

## Future product roadmap

FocusHaven's future AI, voice, adaptive-focus, system-assistant, soundscape,
and Haven expansion work is deliberately separated from the shipped feature
list above. The authoritative planning and safety contracts are:

- [Product roadmap](docs/PRODUCT_ROADMAP.md) — current status, delivery order,
  and release gates
- [Haven AI and Action architecture](docs/HAVEN_AI_ACTION_ARCHITECTURE.md) —
  the typed-first proposal, policy, confirmation, and execution boundary
- [Voice privacy and command policy](docs/VOICE_PRIVACY_AND_COMMAND_POLICY.md) —
  tap-to-talk, transcript handling, confirmation, and forbidden actions

Phase 212 now implements **explicit tap-to-talk Voice-to-Coach**. FocusHaven
requests microphone and speech-recognition access only after an informed tap,
keeps no raw-audio history, and places recognized text into an editable draft.
The operating system or browser speech service may process audio on-device or
over a network. Nothing is sent to Focus Coach until the person taps **Send**;
local Focus Coach remains the default, while enhanced remote coaching remains
separately gated and disabled.

Phase 210 ships the first **typed Haven Action Engine**. From the timer
screen, **Haven actions** can locally review one bounded timer, navigation, or
Focus Queue request before execution. Stateful queue edits require an exact
visual confirmation; stale and replayed proposals fail closed; and mutations
remain owned by the existing timer and queue services. This surface stores no
raw command history and adds no microphone permission, speech dependency,
remote-model call, Firebase operation, or developer command path.
Its review card is announced as one accessible summary of the interpretation,
effect, risk, and available choices. Keyboard submission and **Change request**
keep the typed path editable, while every consumed proposal disappears after
success or rejection so it cannot remain available for another tap.

Phase 213 now implements **Safe Voice Commands** without giving speech new
authority. An informed tap starts the same bounded transcription service and
fills an editable Haven action draft. Speech does not create a proposal or run
anything: the person must separately tap **Review action**, inspect the
source-labelled proposal, and then choose **Run reviewed action** or **Confirm
exact action**. Typed and voice proposals share the same allowlist, current
state, expiry, argument bounds, protected-action rejection, exact confirmation,
and replay protection. Local Coach output and system intents are rejected as
proposal sources; general AI orchestration remains future work.

Phase 214A adds the first **local Haven planner foundation**. From the Focus
timer, **Plan a goal** turns only the goal and time the person enters into an
ephemeral, explainable draft. The draft lists its inputs, assumptions,
uncertainty, and affected local data, then requires an independent
**Accept**, **Edit**, or **Reject** choice for every possible task, session-size
suggestion, and free-time suggestion. Nothing changes while the draft is being
reviewed. Exact accepted queue items require one final visual confirmation and
are added one at a time through fresh state-bound Haven Action proposals and
the existing Focus Queue service. The planner never starts or reconfigures the
timer, reads or writes a calendar, replaces the queue, persists the goal, or
contacts remote AI. Remote goal decomposition remains future, separately
disclosed, opt-in work.

Phase 215A connects that reviewed planning work to one **local Plan-to-Focus
loop**. Choosing an existing Focus Queue task links only its exact local item
identity to the Focus timer; the queue remains the owner of task text and task
completion, while the timer remains the owner of session state. After a linked
Focus session completes, FocusHaven waits for the person to choose **Mark task
complete** or **Keep for later** before offering the next session. A renamed,
removed, completed, or otherwise mismatched task fails closed and is never
changed automatically. Cold-start restoration also withholds the next-session
control until the saved-link check finishes. Manual intention edits clear the
link, and no goal, task text, transcript, reflection, calendar data, remote
model call, account, or new permission is added by this loop.

Phase 215B adds one bounded **task-decision-to-reflection** connection. For a
linked Focus completion, the person first decides whether to **Mark task
complete** or **Keep for later**. Only after that exact queue decision settles
does FocusHaven offer the existing optional, text-free session-fit reflection.
The person may choose a fit or take the break without answering; skipping
stores nothing. Reflection remains owned by the timer event history, is bound
to the exact completed attempt, and rejects stale callbacks rather than
rewriting a later session. No task text, reflection copy, remote model call,
account, permission, backend, or deployment is added.

Phase 215C adds the next bounded **reflection-to-Rhythm** connection. After a
person saves a text-free session-fit reflection, an informational card explains
whether that exact completion is only a beginning, contributes to a repeated
local pattern, or remains secondary to recent recovery signals. The card is
rebuilt from the existing private focus-event history, stores nothing new, and
disappears outside that exact completed Focus boundary. It offers no control
and states that nothing changed automatically; the next session remains the
person's choice. Unanswered, stale, duplicate, or mismatched completion
evidence fails closed and shows no connection.

Phase 215D adds a separate **reflection-to-Forecast** connection. The exact
current text-free reflection is matched to the existing local Focus Forecast,
then a second informational card explains whether Forecast is still learning,
the completion sits inside or outside a possible timing window, or recent
timing remains flexible. The saved fit adds context only: it does not change
Forecast's completed-session timing rules, score a time, schedule work, adapt
the timer, or override current energy and availability. The connection is
ephemeral, has no button, states that a possible window is not a rule, and
fails closed for unanswered, stale, duplicate, or mismatched evidence.

Phase 215E connects an interrupted linked Focus attempt to the existing
**Smart Reset** recovery choice without creating another task or recovery
store. When the exact active queue identity still matches the timer intention,
HavenLoop issues one ephemeral, single-use recovery ticket containing only the
queue-item ID. The recovery sheet says that the link is preserved only while
the item remains active and unchanged; no task text enters the Smart Reset
plan. **Restart smaller**, **Reset without restarting**, and **Keep this
session** remain explicit user choices owned by the timer. After the choice,
the ticket is consumed and the queue and timer owners are checked again. A
renamed, removed, completed, superseded, replayed, or mismatched ticket fails
closed without changing the queue; ordinary unlinked Smart Reset remains
available.

Phase 215F adds one read-only **completion-to-Journey** connection after the
linked task decision is settled. The exact newest `FocusCompletionIdentity`
must appear once in the bounded text-free event history, and the visible
Journey state must match the existing cumulative completion count. The card
then explains either that this completion belongs equally inside the current
Haven place or that the existing count crossed one of Journey's established
place boundaries. It stores no task title, queue ID, reflection, transcript,
or second Journey state; it has no button and disappears outside that exact
completed Focus boundary. Stale, duplicate, unresolved, or inconsistent
evidence fails closed. This advisory changes nothing automatically, and Haven
Journey remains private, cumulative, and free of scores or streak pressure.

Because Phases 212 and 213 use native microphone and speech-recognition
capabilities, fresh Android and Apple release builds, real-device permission and
command checks, accessibility verification, store disclosures, and candidate
validation are required before distribution. Earlier validated artifacts do
not cover these capabilities.

## Languages and global releases

FocusHaven now has a generated Flutter localization foundation, with English as
the source catalog and the only production-supported runtime locale. Spanish is
an exact reviewed integration catalog; French, German, and Brazilian Portuguese
remain planned. None is advertised by the app or stores until every
user-visible string, accessibility label, error, permission explanation,
notification, widget/watch surface, voice path, policy, help resource, and
store listing required for that locale has been reviewed.

Adding a locale is a release decision, not a file-copy exercise. A production
locale must pass native and Flutter formatting checks, layout and large-text
tests, plural and placeholder review, human linguistic review, speech-locale
acceptance where applicable, and country-specific store/disclosure review.
The authoritative contract is the
[localization and global-release policy](docs/LOCALIZATION_AND_GLOBAL_RELEASE_POLICY.md).
Phases 215G-B1, B2, B3A, B3B, B3C, B4, and B5 now move the complete first-run onboarding, appearance
picker, custom-duration chrome, guided breathing, timer accessibility, and the
bounded timer dashboard/session-control presentation into that English
catalog. B2 covers session names and encouragement, timer actions and
saved-session recovery, focus-intention and queue entry points, daily
goal/challenge progress, recent
focus, locale-aware dashboard dates, and dashboard receipts and errors. It
preserves the exact English behavior and stored timer, task, queue, goal, and
history values. The
Phase 215G-B3A boundary additionally catalog-owns Focus Queue management and
completed-task history, Haven Plan's controls and preview chrome, Haven
Planner's local proposal and exact review presentation, and the Plan-to-Focus
task-decision card. User-authored
task titles and goals remain opaque placeholders. Generated planner items and
other service-originated planning copy remain B6-owned, so B3A does not claim
that every planning sentence is localized. English remains the only active
runtime locale. Phase 215G-B3B additionally catalog-owns the optional text-free
session reflection presentation, Haven Rhythm and Focus Forecast chrome and
advisory boundaries, Smart Reset presentation and actions, and Haven Journey
place, privacy, accessibility, and completion-advisory copy. Personal
reflection content never becomes a catalog key, and service-generated
restorative copy remains B6-owned runtime data.
Phase 215G-B3C additionally catalog-owns Haven Window and Focus Shield status
and action labels, permission and platform-truth presentation, privacy and
agency boundaries, locale-aware held-window time ranges, and Haven Window
fail-closed receipts. Haven Window suggestion text and Focus Shield state text
remain opaque B6-owned service values. This slice does not request a permission,
read or write a calendar, change a reminder or protection rule, start a bridge,
or activate another language.
Phase 215G-B4 additionally catalog-owns Focus Coach presentation, the
local/enhanced-AI state and consent boundary, Voice-to-Coach and safe-command
tap-to-talk presentation, stable permission and recognition notices, and Haven
action review, risk, semantics, and exact-confirmation presentation. Private
transcripts and user messages, Coach responses, interpreted proposal
explanations and effects, execution results, and service-generated errors stay
opaque runtime values with their existing owners. This slice does not record
audio, contact AI, request a permission, change speech recognition or action
policy, enable enhanced AI, or activate another language.
Phase 215G-B5 additionally catalog-owns account and authentication
presentation, backup and destructive-data confirmations, Pro and purchase
presentation, Reflection Journal and Focus Profile chrome, reminders,
milestones, Focus History, and the current privacy-policy launch action.
Private account identity, journal and reflection content, task names, store
prices, and service-returned values remain opaque. Stable mood and profile
identifiers remain unchanged in storage and are localized only when displayed.
This slice does not sign in, purchase, back up, restore, delete, request a
permission, schedule a reminder, launch a policy, or activate another
language.
Phase 215G-B6A additionally catalog-owns Flutter notification titles and
bodies, Flutter-created Android notification channel names and descriptions,
timer-completion notification copy, and the presentation of every stable
account-deletion outcome. Notification and channel IDs, schedules, time-zone
rules, permission behavior, timer state, and account-deletion status enums are
unchanged. Generated planner/restorative copy and coaching, action,
authentication, store, journal, export, and other service-owned results were
completed by the later B6 slices. English remains the only active locale.
Phase 215G-B6B1 additionally catalog-owns the stable local Haven Planner
validation, assumptions, uncertainty explanation, generated queue-item
templates, session-size suggestion, and no-calendar free-time suggestion.
User-authored goal text remains an opaque placeholder, planner proposal schema
and review behavior are unchanged, and the existing English fallback remains
the only active service catalog.

Phase 215G-B6B2 now catalog-owns the stable service-generated guidance from
Haven Rhythm, Focus Forecast, Smart Reset, Haven Journey, Haven Window, and
Focus Shield. Private reflection values, completion identities, calendar
availability boundaries, selected apps or websites, and other user-owned data
remain opaque runtime values rather than translation keys. The services keep
their deterministic rules, local ownership, validation thresholds, and
fail-closed behavior; English remains the only active locale.

Phase 215G-B6C1 now catalog-owns stable Haven action interpretation and effect
text, policy decisions, replay and exact-confirmation receipts, service
failure receipts, and successful execution receipts. User-authored queue
titles remain opaque placeholders. The English command grammar, bounded action
allowlist, protected-operation exclusions, proposal expiry, state tokens,
exact confirmation, replay protection, and existing timer, queue, and
navigation service ownership are unchanged. English remains the only active
locale.

Phase 215G-B6C2 now catalog-owns deterministic private Local-Coach responses,
stable remembered-challenge labels, enhanced-AI fallback notices, and coaching
response, preference, storage-repair, and private-cleanup errors. User-authored
messages, tasks, moods, profiles, and saved conversation content remain opaque
runtime placeholders. The selected catalog is attached only to in-memory local
response context and is excluded from Enhanced-AI prompt data. English signal
matching, responder selection, consent, fallback, persistence, and cleanup
behavior are unchanged. English remains the only active locale.

Phase 215G-B6C3 now catalog-owns the remaining authentication and store service
results, seven deterministic daily journal prompts, private Focus History
export copy, Haven Plan guidance, and Living Lantern guidance. Private account
identities, store prices, journal entries, moods, tasks, and focus-history
values remain opaque runtime values. Provider diagnostics are no longer
rendered as sign-in or store copy. Authentication, entitlement, purchase,
journal persistence, export, plan, lantern, timer, and queue behavior are
unchanged. English remains the only active locale.

The [extraction inventory](docs/LOCALIZATION_EXTRACTION_INVENTORY.md) defines the
completed Phase 215G-B English Flutter extraction. This is not a claim that an
additional language, native platform resource, policy, support surface, store
listing, screenshot set, or country release is localized. These phases do not
translate private content, change the person's language setting, activate a
planned locale, contact a translation service, deploy a build, or change a
store listing.

Phase 215G-C0 now freezes that complete English catalog for the first Spanish
translation intake and adds a fail-closed candidate-catalog auditor, an
inactive review record, and a Spanish terminology worksheet. It creates no
Spanish ARB candidate and does not activate or advertise Spanish. A complete
candidate must remain outside `lib/l10n` until structural parity and qualified
human review are recorded; voice/coaching, native, policy, support, store, and
country qualification remain later independent gates.

Phase 215G-C1A now adds the deterministic, fail-closed builder for a future
isolated Spanish candidate. The builder requires an exact locked source,
complete translation-key parity, preserved ICU placeholders, non-empty values,
and explicit rationales for intentional source-equal terms. It can write only
to `localization/candidates/app_es.arb` and refuses overwrite. This phase does
not create a translation bundle or Spanish candidate, contact a translation
provider, approve Spanish wording, or activate or advertise Spanish.

Phase 215G-C1B now records the complete machine-assisted Spanish draft as an
isolated candidate at `localization/candidates/app_es.arb`. The exact locked
English source and authorized local draft produced 980 candidate messages,
including 148 placeholder-bearing messages and 11 explicitly documented
source-equal invariants. The guarded builder and an independent structural
audit report no missing, extra, empty, metadata, placeholder-schema, or ICU
placeholder failures. The candidate is structurally ready for qualified human
review only. It remains outside `lib/l10n`; Spanish is not linguistically
approved, runtime activated, voice/coaching qualified, native/store qualified,
advertised, or publicly supported. No external translation provider or private
runtime data was used.

Phase 215G-C2A now prepares the deterministic, fail-closed builder for a future
qualified-human-review packet. The builder is pinned to the exact English and
Spanish catalog digests and the committed structural audit. It orders all 980
source/candidate pairs by critical, elevated, then standard review risk; keeps
placeholder schemas and message context with every entry; limits batches to 50
entries; and leaves every reviewer decision, replacement, and note empty. This
preparation slice creates no packet, assigns no reviewer, and does not start or
approve human review. Spanish remains outside `lib/l10n`, planned, and runtime
inactive.

Phase 215G-C2B now creates the one isolated review packet at
`localization/reviews/es/packets/review-packet.json` with SHA-256
`325231a14ff0dfe2b176f6267996292aa0575b5db16d3c084cf453bf5f75737e`.
An independent audit confirms all 980 locked source/candidate pairs, 148
placeholder-bearing entries, 11 source-equal invariants, critical-first risk
ordering, 20 batches of at most 50 entries, and 980 empty reviewer decisions.
The packet is unassigned and human review has not started. It does not approve
or activate Spanish, move the candidate into `lib/l10n`, contact a provider,
use private runtime data, or make a public support or country claim.

Phase 215G-C2C now prepares the deterministic, fail-closed reviewer-assignment
gate for that exact packet. A later authorization must name a real qualified
reviewer, document non-sensitive qualification and independence statements,
accept the exact general-international-Spanish scope, and preserve all catalog
locks. Assignment remains separate from review start: this phase creates no
authorization or assignment record, assigns nobody, leaves all 980 decisions
pending, and keeps `reviewStarted` false. Human review has not started, and
Spanish remains linguistically unapproved, outside `lib/l10n`, runtime
inactive, release unqualified, and unsupported publicly.

Phase 215G-C2D now records the completed private human validation of all 980
Spanish candidate messages. Every translation was accepted; no replacement,
source mutation, invalid decision, blocked message, or placeholder mismatch was
found. The workbook, reviewer identity, contact details, qualifications,
metadata, and notes are not committed. Git retains only anonymous aggregate
proof and exact source, candidate, packet, and sanitized-payload hashes. The
unused C2C assignment records remain absent. This validation checkpoint does
not move Spanish into `lib/l10n` or qualify runtime, voice/coaching, native,
store, country, or public-language support; Spanish remains runtime inactive.

Phase 215G-C3A now integrates a byte-identical copy of that reviewed Spanish
catalog into Flutter's generated-localization pipeline for isolated runtime and
widget testing. Generated delegates now cover English and Spanish, while the
production `MaterialApp` is deliberately wired to the separate English-only
`FocusHavenLocales.productionLocales` allowlist. Spanish therefore remains
runtime inactive for customers and is not advertised or claimed in stores.
Voice/coaching, native/store resources, accessibility layouts, signed builds,
and country-release qualification remain later independent gates. No reviewer
identity, workbook, private content, or translation-provider data is included.

Phase 215G-C3B adds an isolated Spanish critical-surface layout and
accessibility gate at a 320-pixel phone width with enlarged text. It covers
onboarding, Focus Coach, Haven Actions, and account/privacy controls, including
translated semantics and close controls. Onboarding is now vertically
scrollable so longer translations and accessibility text remain reachable.
Focus Coach now stacks its header details and composer controls when narrow
width or enlarged text would otherwise squeeze them into tall, unusable rows;
the complete sheet becomes vertically scrollable while the conversation keeps
a bounded viewport, so the composer and care boundary remain reachable.
This bounded gate does not activate Spanish or claim complete device,
screen-reader, voice, native/store, signed-build, or country qualification.

Phase 215G-C3C expands the isolated Spanish accessibility gate to the everyday
session path at a 320-pixel phone width and 1.6x text. It covers the timer
dashboard, Appearance, Custom Duration, Mindful Pause, Focus Queue, and
Completed Tasks; verifies translated controls and accessibility labels; keeps
synthetic user-authored task text opaque; and checks that primary actions remain
reachable without layout exceptions. Custom Duration and Mindful Pause now
scroll when translated or enlarged content exceeds the available height. The
reviewed Spanish catalog remains byte-identical to its candidate and the
production locale allowlist remains English-only. Voice/coaching, native/store,
signed-build, country, and public Spanish support remain separate later gates.

Phase 215G-C3D adds automated Spanish screen-reader preparation without
claiming physical-device acceptance. The Custom Duration minute and second
wheels now expose localized adjustable values with increase and decrease
actions. Mindful Pause exposes its changing Spanish breathing phase and phase
duration as a live region, while Appearance announces a failed update as a
live-region error. Automated tests exercise those values, roles, actions, and
announcements and preserve the reviewed catalog lock. Physical TalkBack and
VoiceOver acceptance, real-device Spanish runtime, voice/coaching,
native/store, signed-build, country, and production activation remain pending.

Phase 215G-C3E prepares a separate debug-only Spanish device-test target for
physical TalkBack acceptance. The target requires the explicit
`FOCUSHAVEN_SPANISH_DEVICE_TEST=true` compile-time authorization, rejects every
non-debug build, fixes the test locale to Spanish, and exposes only the exact
reviewed English and Spanish delegates. Normal builds still enter through
`main.dart` with the English-only production allowlist. This preparation does
not add a language selector or saved preference, activate or advertise
Spanish, change permissions or dependencies, or claim that physical acceptance
has passed.

The first Phase 215G-C3F physical TalkBack pass correctly remained unaccepted
after it found that the extended Local Coach button could cover the Cloud
Restore action at the end of the dashboard. The same shared layout defect was
then confirmed in English. The correction reserves scroll-end clearance below
the final actions, and narrow 320-pixel, 1.6x-text regression tests compare the
actual Restore and Coach button bounds in both languages. The corrected Spanish
APK then passed the complete bounded TalkBack checklist on the approved Moto,
including independently focusable **Restaurar** and **Coach de enfoque**
controls. The corrected normal APK was restored without clearing app data, and
its **Restore** and **Focus Coach** controls passed the same physical clearance
check. Android TalkBack acceptance is complete; physical iOS VoiceOver,
voice/coaching, native/store, signed-build, country, and production activation
remain separate pending gates.

## Architecture

The application uses Riverpod as its dependency and state-management boundary.
Service ownership is centralized in `lib/providers/app_providers.dart`, while
views consume narrow immutable snapshots so high-frequency timer updates do not
rebuild unrelated interface sections.

The service layer separates timer state, reminders, notifications,
authentication, cloud backup, queue data, journal data, themes, focus profiles,
and purchases from the UI. User-created focus data is stored locally by default;
cloud backup is optional and requires a non-anonymous signed-in account.

Reusable sheets, dialogs, and dashboard components live under `lib/widgets`.
Models live under `lib/models`, and platform integrations remain isolated in
`lib/services`.

## Requirements

- Flutter 3.44.8 on the stable channel
- Dart 3.12.2
- Xcode for iOS and macOS builds; the iOS app requires iOS 15 or later
- Android Studio and the Android SDK for Android builds

Shipping iPhone Focus Shield requires Apple approval for the Family Controls
distribution entitlement and a provisioning profile containing
`com.apple.developer.family-controls`. Development builds remain honest when
authorization or entitlement access is unavailable: no protection is claimed.

The production Apple identity uses `com.focushaven.app` for the iPhone app,
`com.focushaven.app.widget` for its home-screen widget, and
`com.focushaven.app.watchkitapp` for the companion watch app. The iPhone app
and widget exchange only their bounded private snapshot through
`group.com.focushaven.app`. Automatic signing is pinned to the registered
FocusHaven Apple development team; generated profiles must preserve these
explicit identifiers and capabilities.

## Run locally

Install the exact dependency versions recorded in `pubspec.lock`:

```bash
flutter pub get --enforce-lockfile
```

The iOS project uses Flutter's generated Swift Package Manager package for
plugins. Do not run `pod install`; CocoaPods is intentionally not part of the
iOS workspace and would duplicate Firebase modules already supplied by Swift
Package Manager.

List available devices and launch the appropriate target:

```bash
flutter devices
flutter run -d macos
```

Replace `macos` with an available Android, iOS, Chrome, or other supported
device identifier.

## Quality checks

Run the same core checks used by continuous integration:

```bash
flutter analyze
flutter test
flutter build web --release
```

The GitHub Actions workflow uses the locked dependencies and the project's
pinned Flutter version before analyzing, testing, and building the web release.
It also runs the Android phone and Wear OS Kotlin unit suites in a separate
unsigned job using Java 17 and the project's pinned Gradle 9.1.0 version. That
native job creates only ignored runner-local SDK metadata and has no access to
release keystores, Apple signing identities, store credentials, or private
server secrets.

## Release builds

```bash
flutter build appbundle --release
flutter build web --release
flutter build macos --release
```

Apple distribution additionally requires valid bundle registrations,
provisioning, and signing. Android release builds require the local signing
configuration referenced by `android/key.properties`.

## Firebase, purchases, and secrets

Platform Firebase client configuration is versioned with the application so
supported clients can connect to the FocusHaven Firebase project. Firebase
administrator credentials, service-account keys, signing keystores, passwords,
and other private server credentials must never be committed.

The grandfathered non-consumable product identifier is `focushaven_pro`.
Planned subscription identifiers are `focushaven_pro_monthly` and
`focushaven_pro_annual`. Store prices and introductory offers remain managed by
Apple and Google rather than hard-coded in the client.

Subscription checkout is not active yet. Monthly and annual purchase events
require trusted server verification and cannot create a local paid entitlement.
The legacy identifier remains available for existing lifetime-owner restoration.
Ordinary builds also disable new legacy lifetime purchases. The temporary
`ENABLE_LEGACY_LIFETIME_PURCHASES` compile-time flag exists only for controlled
store-transition testing; restoring an existing purchase remains available.

## Privacy

FocusHaven can be used without Google or Apple sign-in. Optional cloud data can
be deleted from the account controls, the complete signed-in account can be
deleted after provider reauthentication, and local data can be removed
separately from the app.
Focus-event history is bounded and excludes task names, journal text, mood
labels, and other user-authored content. It stays on the device unless the user
explicitly includes local FocusHaven data in an optional cloud backup.
See the [FocusHaven Privacy Policy](https://tyree1233.github.io/FocusHaven/PRIVACY_POLICY.html)
for details. Store disclosure work is tracked in the source-backed
[store privacy and permission matrix](docs/STORE_PRIVACY_DISCLOSURE_MATRIX.md),
including the remaining deployment and production-verification gates for complete
in-app/external account deletion. The implementation and public
[account-deletion resource](docs/ACCOUNT_DELETION.md) now exist, while Apple
provider activation and the App Check verifier-role prerequisite are complete;
the scoped deletion callable is deployed, and the non-destructive and
destructive production canaries remain explicit pre-submission gates. The
repository also defines an
ordered, no-secrets
[account-lifecycle production activation runbook](docs/ACCOUNT_LIFECYCLE_PRODUCTION_ACTIVATION.md)
that pins every Firebase command to project `focushaven-68c59`, records the
completed single-function deployment of `deleteFocusHavenAccount`, and keeps
each later production gate behind separate explicit approval and captured
evidence. The repository also defines an
enforceable [privacy-safe diagnostics policy](docs/DIAGNOSTICS_POLICY.md):
release clients do not include a third-party crash-reporting SDK or upload
app-owned crash reports, and developer/function diagnostics are restricted to
closed, content-free fields.
