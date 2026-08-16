abstract final class FeatureFlags {
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
