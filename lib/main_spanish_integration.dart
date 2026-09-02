import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart' show Locale;

import 'l10n/focus_haven_locales.dart';
import 'main.dart' show runFocusHaven;

const _spanishDeviceTestAuthorized = bool.fromEnvironment(
  'FOCUSHAVEN_SPANISH_DEVICE_TEST',
);

/// Starts an isolated Spanish device-test build.
///
/// This target fails closed unless it is a debug build compiled with the exact
/// authorization flag. Normal application builds continue to use `main.dart`
/// and the English-only production locale allowlist.
Future<void> main() async {
  if (!kDebugMode || !_spanishDeviceTestAuthorized) {
    throw UnsupportedError(
      'Spanish device testing requires a debug build with '
      'FOCUSHAVEN_SPANISH_DEVICE_TEST=true.',
    );
  }

  await runFocusHaven(
    locale: const Locale('es'),
    supportedLocales: FocusHavenLocales.spanishDeviceTestLocales,
  );
}
