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
    await settle();

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
    await settle();

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
    await settle();

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
    await settle();

    await service.signInWithGoogle();
    expect(service.signInError, isNotNull);

    await service.signOut();

    expect(backend.signOutCalls, 1);
    expect(backend.anonymousSignInCalls, 2);
    expect(service.signInError, isNull);
  });
}

final class _FakeAuthBackend implements AuthBackend {
  final StreamController<User?> _authStates = StreamController<User?>.broadcast(
    sync: true,
  );

  @override
  User? currentUser;

  int anonymousSignInCalls = 0;
  int credentialSignInCalls = 0;
  int signOutCalls = 0;
  AuthCredential? lastCredential;

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
