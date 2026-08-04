# FocusHaven

A Flutter focus-timer app for the web, iPhone, and Android. It includes onboarding, a 25-minute timer, Firebase-backed timer settings for Pro users, and the FocusHaven brand asset.

## Get started

Install the [Flutter SDK](https://docs.flutter.dev/get-started/install), then generate the platform folders and fetch packages:

```bash
flutter create . --platforms=android,ios,web
flutter pub get
flutter run -d chrome
```

Use `flutter run -d ios` or `flutter run -d android` to launch a device or simulator.

## Firebase setup

Firebase packages are included, but credentials are intentionally not committed. Configure your Firebase project before running the app:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This generates `lib/firebase_options.dart` and the platform configuration files. Then update `lib/main.dart` to initialize Firebase with the generated options before releasing.
