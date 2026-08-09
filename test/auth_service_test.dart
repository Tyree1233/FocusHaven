import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<void> cleanUp(AuthService service, _FakeAuthBackend backend) async {
    service.dispose();
    await settle();
    await backend.close();
  }

  test('starts guest auth and releases its state subscription', () async {
    final backend = _FakeAuthBackend();
    final service = AuthService(
      authBackend: backend,
      googleAuthBackend: _FakeGoogleAuthBackend(null),
    );
    await service.initialized;

    expect(backend.anonymousSignInCalls, 1);
    expect(backend.hasStateListener, isTrue);

    service.dispose();
    await settle();

    expect(backend.hasStateListener, isFalse);
    await backend.close();
  });

  test('cancelled Google selection exposes a stable error', () async {
    final backend = _FakeAuthBackend();
    final googleBackend = _FakeGoogleAuthBackend(null);
    final service = AuthService(
      authBackend: backend,
      googleAuthBackend: googleBackend,
    );
    addTearDown(() => cleanUp(service, backend));
    await service.initialized;

    final credential = await service.signInWithGoogle();

    expect(credential, isNull);
    expect(googleBackend.authenticationCalls, 1);
    expect(backend.credentialSignInCalls, 0);
    expect(
      service.signInError,
      'Google sign-in was closed before an account was selected.',
    );
  });

  test('Google tokens are handed to the Firebase auth backend', () async {
    final backend = _FakeAuthBackend();
    final googleBackend = _FakeGoogleAuthBackend(
      const GoogleAuthTokens(
        accessToken: 'access-token',
        idToken: 'identity-token',
      ),
    );
    final service = AuthService(
      authBackend: backend,
      googleAuthBackend: googleBackend,
    );
    addTearDown(() => cleanUp(service, backend));
    await service.initialized;

    await service.signInWithGoogle();

    expect(googleBackend.authenticationCalls, 1);
    expect(backend.credentialSignInCalls, 1);
    expect(backend.lastCredential?.providerId, 'google.com');
    expect(backend.lastCredential?.accessToken, 'access-token');
    expect(service.signInError, isNull);
  });

  test('sign out clears errors and restores the guest session', () async {
    final backend = _FakeAuthBackend();
    final service = AuthService(
      authBackend: backend,
      googleAuthBackend: _FakeGoogleAuthBackend(null),
    );
    addTearDown(() => cleanUp(service, backend));
    await service.initialized;

    await service.signInWithGoogle();
    expect(service.signInError, isNotNull);

    await service.signOut();

    expect(backend.signOutCalls, 1);
    expect(backend.anonymousSignInCalls, 2);
    expect(service.signInError, isNull);
  });

  test(
    'reports sign-out failures without replacing the signed-in user',
    () async {
      final cachedUser = _FakeUser();
      final backend = _FakeAuthBackend(currentUser: cachedUser)
        ..shouldFailSignOut = true;
      final service = AuthService(
        authBackend: backend,
        googleAuthBackend: _FakeGoogleAuthBackend(null),
      );
      addTearDown(() => cleanUp(service, backend));
      await service.initialized;

      await expectLater(
        service.signOut(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'FocusHaven could not sign out of this account.',
          ),
        ),
      );

      expect(backend.signOutCalls, 1);
      expect(backend.anonymousSignInCalls, 0);
      expect(service.user, same(cachedUser));
      expect(service.isSignedIn, isTrue);
    },
  );

  test('publishes the cached signed-in user during initialization', () async {
    final cachedUser = _FakeUser();
    final backend = _FakeAuthBackend(currentUser: cachedUser);
    final service = AuthService(
      authBackend: backend,
      googleAuthBackend: _FakeGoogleAuthBackend(null),
    );
    addTearDown(() => cleanUp(service, backend));

    await service.initialized;

    expect(service.user, same(cachedUser));
    expect(service.isSignedIn, isTrue);
    expect(service.displayName, 'Tyree');
    expect(backend.anonymousSignInCalls, 0);
    expect(backend.hasStateListener, isTrue);
  });

  test('account operations are ignored after disposal', () async {
    final backend = _FakeAuthBackend();
    final googleBackend = _FakeGoogleAuthBackend(
      const GoogleAuthTokens(accessToken: 'ignored'),
    );
    final service = AuthService(
      authBackend: backend,
      googleAuthBackend: googleBackend,
    );
    await service.initialized;

    service.dispose();
    await settle();
    await service.signInAnonymouslyIfNeeded();
    final credential = await service.signInWithGoogle();
    await service.signOut();

    expect(credential, isNull);
    expect(backend.anonymousSignInCalls, 1);
    expect(backend.credentialSignInCalls, 0);
    expect(backend.signOutCalls, 0);
    expect(googleBackend.authenticationCalls, 0);
    expect(backend.hasStateListener, isFalse);
    await backend.close();
  });
}

final class _FakeAuthBackend implements AuthBackend {
  _FakeAuthBackend({this.currentUser});

  final StreamController<User?> _authStates = StreamController<User?>.broadcast(
    sync: true,
  );

  @override
  User? currentUser;

  int anonymousSignInCalls = 0;
  int credentialSignInCalls = 0;
  int signOutCalls = 0;
  AuthCredential? lastCredential;
  bool shouldFailSignOut = false;

  bool get hasStateListener => _authStates.hasListener;

  @override
  Stream<User?> authStateChanges() => _authStates.stream;

  @override
  Future<void> signInAnonymously() async {
    anonymousSignInCalls += 1;
  }

  @override
  Future<UserCredential?> signInWithCredential(
    AuthCredential credential,
  ) async {
    credentialSignInCalls += 1;
    lastCredential = credential;
    return null;
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    if (shouldFailSignOut) throw StateError('sign-out unavailable');
    currentUser = null;
  }

  Future<void> close() => _authStates.close();
}

final class _FakeGoogleAuthBackend implements GoogleAuthBackend {
  _FakeGoogleAuthBackend(this.tokens);

  final GoogleAuthTokens? tokens;
  int authenticationCalls = 0;

  @override
  Future<GoogleAuthTokens?> authenticate() async {
    authenticationCalls += 1;
    return tokens;
  }
}

final class _FakeUser implements User {
  @override
  bool get isAnonymous => false;

  @override
  String? get displayName => 'Tyree';

  @override
  String? get email => 'tyree@example.com';

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}
