# FocusHaven

FocusHaven is a calm, local-first focus timer and wellbeing companion for
Android, iOS, macOS, and the web.

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

Normal builds keep the enhanced-coaching interface hidden so the local coach
remains accurate when the paid backend has not been deployed. After the
function and secret are available, enable the interface at build time:

```sh
flutter build web --release --dart-define=ENABLE_REMOTE_COACHING=true
flutter build appbundle --release --dart-define=ENABLE_REMOTE_COACHING=true
```

Never enable this flag in a production build before the function is ready and
the independent server-side switch has been reviewed.

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
- Distraction parking for thoughts that can wait until after a session
- Reflection journal with daily prompts and mood history
- Guided breathing, configurable reminders, and appearance themes
- Focus profile questionnaire with saved results
- Guest access with optional Google sign-in and Firebase cloud backup
- User-controlled deletion of local data and cloud backups
- FocusHaven Pro lifetime purchase and purchase restoration

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
- Xcode for iOS and macOS builds
- Android Studio and the Android SDK for Android builds

## Run locally

Install the exact dependency versions recorded in `pubspec.lock`:

```bash
flutter pub get --enforce-lockfile
```

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

The non-consumable product identifier is `focushaven_pro`. The matching product
must be configured and approved in each supported store before real purchases
can be completed.

## Privacy

FocusHaven can be used without Google sign-in. Optional cloud data can be
deleted from the account controls, and local data can be removed from the app.
See the [FocusHaven Privacy Policy](https://tyree1233.github.io/FocusHaven/PRIVACY_POLICY.html)
for details.
