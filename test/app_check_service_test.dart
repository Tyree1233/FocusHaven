import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/services/app_check_service.dart';

void main() {
  test('ordinary builds do not initialize App Check', () async {
    final backend = _RecordingAppCheckBackend();

    final initialized = await initializeRemoteCoachingAppCheck(
      remoteCoachingEnabled: false,
      isWeb: true,
      useDebugProviders: false,
      webSiteKey: '',
      backend: backend,
    );

    expect(initialized, isFalse);
    expect(backend.calls, 0);
  });

  test('enabled release web builds require a site key', () async {
    final backend = _RecordingAppCheckBackend();

    await expectLater(
      initializeRemoteCoachingAppCheck(
        remoteCoachingEnabled: true,
        isWeb: true,
        useDebugProviders: false,
        webSiteKey: '   ',
        backend: backend,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('FIREBASE_APP_CHECK_WEB_SITE_KEY'),
        ),
      ),
    );
    expect(backend.calls, 0);
  });

  test('enabled release web builds normalize the configured key', () async {
    final backend = _RecordingAppCheckBackend();

    final initialized = await initializeRemoteCoachingAppCheck(
      remoteCoachingEnabled: true,
      isWeb: true,
      useDebugProviders: false,
      webSiteKey: '  public-site-key  ',
      backend: backend,
    );

    expect(initialized, isTrue);
    expect(backend.calls, 1);
    expect(backend.lastUseDebugProviders, isFalse);
    expect(backend.lastIsWeb, isTrue);
    expect(backend.lastWebSiteKey, 'public-site-key');
  });

  test('debug web builds use debug attestation without a site key', () async {
    final backend = _RecordingAppCheckBackend();

    final initialized = await initializeRemoteCoachingAppCheck(
      remoteCoachingEnabled: true,
      isWeb: true,
      useDebugProviders: true,
      webSiteKey: '',
      backend: backend,
    );

    expect(initialized, isTrue);
    expect(backend.calls, 1);
    expect(backend.lastUseDebugProviders, isTrue);
    expect(backend.lastIsWeb, isTrue);
    expect(backend.lastWebSiteKey, isNull);
  });

  test('enabled native release builds use production attestation', () async {
    final backend = _RecordingAppCheckBackend();

    final initialized = await initializeRemoteCoachingAppCheck(
      remoteCoachingEnabled: true,
      isWeb: false,
      useDebugProviders: false,
      webSiteKey: '',
      backend: backend,
    );

    expect(initialized, isTrue);
    expect(backend.calls, 1);
    expect(backend.lastUseDebugProviders, isFalse);
    expect(backend.lastIsWeb, isFalse);
    expect(backend.lastWebSiteKey, isNull);
  });

  test('backend failures keep initialization from reporting success', () async {
    final backend = _RecordingAppCheckBackend(error: StateError('unavailable'));

    await expectLater(
      initializeRemoteCoachingAppCheck(
        remoteCoachingEnabled: true,
        isWeb: false,
        useDebugProviders: false,
        backend: backend,
      ),
      throwsA(isA<StateError>()),
    );
    expect(backend.calls, 1);
  });
}

final class _RecordingAppCheckBackend implements AppCheckBackend {
  _RecordingAppCheckBackend({this.error});

  final Object? error;
  int calls = 0;
  bool? lastUseDebugProviders;
  bool? lastIsWeb;
  String? lastWebSiteKey;

  @override
  Future<void> activate({
    required bool useDebugProviders,
    required bool isWeb,
    String? webSiteKey,
  }) async {
    calls += 1;
    lastUseDebugProviders = useDebugProviders;
    lastIsWeb = isWeb;
    lastWebSiteKey = webSiteKey;
    final failure = error;
    if (failure != null) throw failure;
  }
}
