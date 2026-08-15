abstract final class FeatureFlags {
  static const remoteCoachingEnabled = bool.fromEnvironment(
    'ENABLE_REMOTE_COACHING',
    defaultValue: false,
  );

  const FeatureFlags._();
}
