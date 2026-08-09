import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

abstract interface class AuthBackend {
  Stream<User?> authStateChanges();
  User? get currentUser;
  Future<void> signInAnonymously();
  Future<UserCredential?> signInWithCredential(AuthCredential credential);
  Future<void> signOut();
}

final class FirebaseAuthBackend implements AuthBackend {
  FirebaseAuthBackend({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  @override
  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  @override
  User? get currentUser => _firebaseAuth.currentUser;

  @override
  Future<void> signInAnonymously() async {
    await _firebaseAuth.signInAnonymously();
  }

  @override
  Future<UserCredential?> signInWithCredential(AuthCredential credential) =>
      _firebaseAuth.signInWithCredential(credential);

  @override
  Future<void> signOut() => _firebaseAuth.signOut();
}

@immutable
final class GoogleAuthTokens {
  const GoogleAuthTokens({this.accessToken, this.idToken});

  final String? accessToken;
  final String? idToken;
}

abstract interface class GoogleAuthBackend {
  Future<GoogleAuthTokens?> authenticate();
}

final class GoogleSignInBackend implements GoogleAuthBackend {
  GoogleSignIn? _googleSignIn;

  @override
  Future<GoogleAuthTokens?> authenticate() async {
    final googleSignIn = _googleSignIn ??= GoogleSignIn();
    final googleUser =
        await googleSignIn.signInSilently() ?? await googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    return GoogleAuthTokens(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
  }
}

class AuthService extends ChangeNotifier {
  User? user;
  StreamSubscription<User?>? _authSubscription;
  bool _isDisposed = false;
  final AuthBackend? authBackend;
  final GoogleAuthBackend? googleAuthBackend;

  AuthBackend? _defaultAuthBackend;
  GoogleAuthBackend? _defaultGoogleAuthBackend;

  String? _signInError;
  String? get signInError => _signInError;

  bool get isSignedIn => user != null && !user!.isAnonymous;
  String get displayName => user?.displayName ?? user?.email ?? 'Guest';

  AuthService({this.authBackend, this.googleAuthBackend}) {
    try {
      final backend = _resolvedAuthBackend;
      _authSubscription = backend.authStateChanges().listen(
        (currentUser) {
          if (_isDisposed) return;
          user = currentUser;
          notifyListeners();
        },
        onError: (Object error) {
          debugPrint('Authentication state stream failed: $error');
        },
      );
      unawaited(signInAnonymouslyIfNeeded());
    } catch (_) {
      // Authentication remains unavailable until Firebase is configured.
    }
  }

  Future<void> signInAnonymouslyIfNeeded() async {
    try {
      final backend = _resolvedAuthBackend;
      if (backend.currentUser == null) {
        await backend.signInAnonymously();
      }
    } catch (_) {}
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      _setSignInError(null);
      final googleBackend = _resolvedGoogleAuthBackend;
      final googleAuth = await googleBackend.authenticate();
      if (googleAuth == null) {
        _setSignInError(
          'Google sign-in was closed before an account was selected.',
        );
        debugPrint(
          'Google sign-in was cancelled before an account was selected.',
        );
        return null;
      }
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      // Sign in directly so a prior anonymous guest session cannot block
      // returning to an existing Google account.
      final backend = _resolvedAuthBackend;
      return backend.signInWithCredential(credential);
    } catch (error) {
      _setSignInError(
        error is FirebaseAuthException
            ? (error.message ?? error.code)
            : 'Google sign-in could not start: ${error.runtimeType}',
      );
      debugPrint('Google sign-in failed: $error');
      return null;
    }
  }

  Future<void> signOut() async {
    _setSignInError(null);
    try {
      final backend = _resolvedAuthBackend;
      await backend.signOut();
    } catch (error) {
      debugPrint('Sign-out failed: $error');
    }
    // Keep the Google session so signing back into FocusHaven is reliable.
    await signInAnonymouslyIfNeeded();
  }

  AuthBackend get _resolvedAuthBackend =>
      authBackend ?? (_defaultAuthBackend ??= FirebaseAuthBackend());

  GoogleAuthBackend get _resolvedGoogleAuthBackend =>
      googleAuthBackend ??
      (_defaultGoogleAuthBackend ??= GoogleSignInBackend());

  void _setSignInError(String? error) {
    if (_isDisposed || _signInError == error) return;
    _signInError = error;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    final authSubscription = _authSubscription;
    if (authSubscription != null) {
      unawaited(authSubscription.cancel());
    }
    super.dispose();
  }
}
