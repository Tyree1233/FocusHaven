abstract final class FeatureFlags {
  // Opt-in preview; localized source and release/device acceptance pending.
  static const soundscapesPreview = bool.fromEnvironment(
    'ENABLE_SOUNDSCAPES_PREVIEW',
    defaultValue: false,
  );

  static const remoteCoachingEnabled = bool.fromEnvironment(
    'ENABLE_REMOTE_COACHING',
    defaultValue: false,
  );

  static const legacyLifetimePurchasesEnabled = bool.fromEnvironment(
    'ENABLE_LEGACY_LIFETIME_PURCHASES',
    defaultValue: false,
  );

  static const firebaseAppCheckWebSiteKey = String.fromEnvironment(
    'FIREBASE_APP_CHECK_WEB_SITE_KEY',
    defaultValue: '',
  );

  const FeatureFlags._();
}
