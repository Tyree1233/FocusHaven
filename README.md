# FocusHaven

FocusHaven is a calm, local-first focus timer and wellbeing companion for
Android, iOS, macOS, and the web.

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
