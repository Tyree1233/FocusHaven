import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import '../config/feature_flags.dart';

abstract interface class AppCheckBackend {
  Future<void> activate({
    required bool useDebugProviders,
    required bool isWeb,
    String? webSiteKey,
  });
}

final class FirebaseAppCheckBackend implements AppCheckBackend {
  FirebaseAppCheckBackend([FirebaseAppCheck? appCheck])
    : _appCheck = appCheck ?? FirebaseAppCheck.instance;

  final FirebaseAppCheck _appCheck;

  @override
  Future<void> activate({
    required bool useDebugProviders,
    required bool isWeb,
    String? webSiteKey,
  }) {
    final webProvider = !isWeb
        ? null
        : useDebugProviders
        ? WebDebugProvider()
        : ReCaptchaV3Provider(webSiteKey!);
    return _appCheck.activate(
      providerWeb: webProvider,
      providerAndroid: useDebugProviders
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: useDebugProviders
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  }
}

Future<bool> initializeProtectedFirebaseAppCheck({
  bool isWeb = kIsWeb,
  bool useDebugProviders = kDebugMode,
  String webSiteKey = FeatureFlags.firebaseAppCheckWebSiteKey,
  AppCheckBackend? backend,
}) async {
  final normalizedWebSiteKey = webSiteKey.trim();
  if (isWeb && !useDebugProviders && normalizedWebSiteKey.isEmpty) {
    throw StateError(
      'FIREBASE_APP_CHECK_WEB_SITE_KEY is required for protected Firebase calls on web.',
    );
  }

  await (backend ?? FirebaseAppCheckBackend()).activate(
    useDebugProviders: useDebugProviders,
    isWeb: isWeb,
    webSiteKey: isWeb && !useDebugProviders ? normalizedWebSiteKey : null,
  );
  return true;
}
