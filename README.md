# FocusHaven

FocusHaven is a calm, local-first focus timer and wellbeing companion for
Android, iOS, macOS, and the web.

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

Future home-screen widgets, lock-screen experiences, notifications, and watch
companions share one versioned system-focus snapshot. The contract contains
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
gates. Synchronization waits for timer restoration; Lock Screen and Live
Activity commands remain disabled until their separately authorized transports
exist. A paired Apple Watch receives only the latest bounded, text-free timer
snapshot through WatchConnectivity. Its companion shows the current focus or
break, calm state, progress, and a live local countdown. It offers only the
start, pause, resume, reset, discard, or next-session actions advertised by the
exact displayed state. Every request is bounded, expires after one minute, and
is consumed once on the iPhone before Flutter independently applies its stale,
replay, and advertised-action gates. Destructive watch actions require an extra
confirmation. The watch stores no task, reflection, mood, history, coach, or
account data and cannot bypass phone-side timer authorization.

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
not claim a mutation before the phone publishes the resulting state. It carries
no task, reflection, mood, history, coach, or account data. macOS, web, and every
unsupported platform remain dormant.

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
remains accurate when the paid backend has not been deployed. Before producing
an enabled build, register the Android, Apple, and web apps under Firebase
App Check. FocusHaven uses Play Integrity in Android releases, App Attest with
DeviceCheck fallback in Apple releases, and reCAPTCHA v3 on web. Debug builds
use Firebase debug providers; register their generated tokens only for trusted
development devices and never distribute a debug build.

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

After the function, secret, App Check registrations, entitlement verification,
and quotas are available, enable the interface at build time:

```sh
flutter build web --release \
  --dart-define=ENABLE_REMOTE_COACHING=true \
  --dart-define=FIREBASE_APP_CHECK_WEB_SITE_KEY=your-recaptcha-v3-site-key
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

FocusHaven can be used without Google sign-in. Optional cloud data can be
deleted from the account controls, and local data can be removed from the app.
Focus-event history is bounded and excludes task names, journal text, mood
labels, and other user-authored content. It stays on the device unless the user
explicitly includes local FocusHaven data in an optional cloud backup.
See the [FocusHaven Privacy Policy](https://tyree1233.github.io/FocusHaven/PRIVACY_POLICY.html)
for details.
