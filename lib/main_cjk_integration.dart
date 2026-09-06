import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/widgets.dart' show Locale;

import 'l10n/focus_haven_locales.dart';
import 'main.dart' show runFocusHaven;

const _cjkCoverageTestAuthorized = bool.fromEnvironment(
  'FOCUSHAVEN_CJK_COVERAGE_TEST',
);
const _cjkCoverageLocale = String.fromEnvironment('FOCUSHAVEN_CJK_LOCALE');
const _allowedCjkCoverageLocales = <String>{'ja', 'ko'};

/// Starts an isolated Japanese or Korean CJK-coverage build.
///
/// This entry point fails closed in release builds and unless it is compiled
/// with the exact authorization flag and one of the two reviewed locale
/// identifiers. Debug and profile modes are permitted for physical coverage.
/// Normal application builds continue to use `main.dart` and the production
/// locale registry, so neither integration locale appears in the app picker.
Future<void> main() async {
  if (kReleaseMode ||
      !_cjkCoverageTestAuthorized ||
      !_allowedCjkCoverageLocales.contains(_cjkCoverageLocale)) {
    throw UnsupportedError(
      'CJK coverage testing requires a non-release build with '
      'FOCUSHAVEN_CJK_COVERAGE_TEST=true and '
      'FOCUSHAVEN_CJK_LOCALE=ja or ko.',
    );
  }

  await runFocusHaven(
    locale: Locale(_cjkCoverageLocale),
    supportedLocales: FocusHavenLocales.cjkCoverageTestLocales,
  );
}
