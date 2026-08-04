# FocusHaven

A calm, cross-platform focus timer for macOS, iOS, Android, and the web.

## Included MVP functionality

- Branded onboarding and a 25-minute focus timer
- Start, pause, reset, add-time, and locally persisted timer state
- Anonymous Firebase auth with optional Google sign-in
- Pro-gated Firestore timer sync
- In-app-purchase and notification scaffolding
- Automated Flutter analysis and test workflow

## Run locally

```bash
flutter pub get
flutter run -d macos
```

Use `flutter run -d chrome`, `flutter run -d ios`, or `flutter run -d android` when the relevant device is available.

## Firebase and purchases

Firebase credentials and store product IDs are not committed. Before release, configure Firebase with `flutterfire configure`, replace the `focushaven_pro` placeholder product ID, and add server-side purchase verification.
