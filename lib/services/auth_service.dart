import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'privacy_safe_diagnostics.dart';

abstract interface class AuthBackend {
  Stream<User?> authStateChanges();
  User? get currentUser;
  Set<String> get currentProviderIds;
  Future<void> signInAnonymously();
  Future<UserCredential?> signInWithCredential(AuthCredential credential);
  Future<UserCredential?> signInWithProvider(AuthProvider provider);
  Future<void> reauthenticateWithCredential(AuthCredential credential);
  Future<String?> reauthenticateWithProvider(AuthProvider provider);
  Future<void> revokeTokenWithAuthorizationCode(String authorizationCode);
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
  Set<String> get currentProviderIds =>
      _firebaseAuth.currentUser?.providerData
          .map((provider) => provider.providerId)
          .toSet() ??
      const <String>{};

  @override
  Future<void> signInAnonymously() async {
    await _firebaseAuth.signInAnonymously();
  }

  @override
  Future<UserCredential?> signInWithCredential(AuthCredential credential) =>
      _firebaseAuth.signInWithCredential(credential);

  @override
  Future<UserCredential?> signInWithProvider(AuthProvider provider) =>
      _firebaseAuth.signInWithProvider(provider);

  @override
  Future<void> reauthenticateWithCredential(AuthCredential credential) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('No authenticated account is available.');
    }
    await user.reauthenticateWithCredential(credential);
  }

  @override
  Future<String?> reauthenticateWithProvider(AuthProvider provider) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('No authenticated account is available.');
    }
    final credential = await user.reauthenticateWithProvider(provider);
    return credential.additionalUserInfo?.authorizationCode;
  }

  @override
  Future<void> revokeTokenWithAuthorizationCode(String authorizationCode) =>
      _firebaseAuth.revokeTokenWithAuthorizationCode(authorizationCode);

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

enum AccountReauthenticationStatus {
  verified,
  cancelled,
  unauthenticated,
  unsupportedProvider,
  unavailable,
}

@immutable
final class AccountReauthenticationResult {
  const AccountReauthenticationResult._(
    this.status, {
    this.appleAuthorizationCode,
  });

  const AccountReauthenticationResult.verified({String? appleAuthorizationCode})
    : this._(
        AccountReauthenticationStatus.verified,
        appleAuthorizationCode: appleAuthorizationCode,
      );

  const AccountReauthenticationResult.cancelled()
    : this._(AccountReauthenticationStatus.cancelled);

  const AccountReauthenticationResult.unauthenticated()
    : this._(AccountReauthenticationStatus.unauthenticated);

  const AccountReauthenticationResult.unsupportedProvider()
    : this._(AccountReauthenticationStatus.unsupportedProvider);

  const AccountReauthenticationResult.unavailable()
    : this._(AccountReauthenticationStatus.unavailable);

  final AccountReauthenticationStatus status;
  final String? appleAuthorizationCode;
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
  final bool? appleSignInSupported;

  AuthBackend? _defaultAuthBackend;
  GoogleAuthBackend? _defaultGoogleAuthBackend;

  String? _signInError;
  String? get signInError => _signInError;

  bool get isSignedIn => user != null && !user!.isAnonymous;
  String get displayName => user?.displayName ?? user?.email ?? 'Guest';

  AuthService({
    this.authBackend,
    this.googleAuthBackend,
    this.appleSignInSupported,
  }) {
    initialized = _initialize();
  }

  /// Completes after cached auth state is read and its listener is attached.
  late final Future<void> initialized;

  Future<void> _initialize() {
    try {
      final backend = _resolvedAuthBackend;
      user = backend.currentUser;
      _authSubscription = backend.authStateChanges().listen(
        (currentUser) {
          if (_isDisposed || user == currentUser) return;
          user = currentUser;
          notifyListeners();
        },
        onError: (Object error) {
          if (!_isDisposed) {
            PrivacySafeDiagnostics.report(
              FocusHavenDiagnosticEvent.authenticationStream,
              error: error,
            );
          }
        },
      );
      unawaited(signInAnonymouslyIfNeeded());
    } catch (_) {
      // Authentication remains unavailable until Firebase is configured.
    }
    return Future<void>.value();
  }

  Future<void> signInAnonymouslyIfNeeded() async {
    if (_isDisposed) return;
    try {
      final backend = _resolvedAuthBackend;
      if (backend.currentUser == null) {
        await backend.signInAnonymously();
      }
    } catch (_) {}
  }

  Future<UserCredential?> signInWithGoogle() async {
    if (_isDisposed) return null;
    try {
      _setSignInError(null);
      final googleBackend = _resolvedGoogleAuthBackend;
      final googleAuth = await googleBackend.authenticate();
      if (_isDisposed) return null;
      if (googleAuth == null) {
        _setSignInError(
          'Google sign-in was closed before an account was selected.',
        );
        PrivacySafeDiagnostics.report(
          FocusHavenDiagnosticEvent.googleSignInCancelled,
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
      PrivacySafeDiagnostics.report(
        FocusHavenDiagnosticEvent.googleSignIn,
        error: error,
      );
      return null;
    }
  }

  bool get supportsAppleSignIn =>
      appleSignInSupported ??
      (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS));

  Future<UserCredential?> signInWithApple() async {
    if (_isDisposed) return null;
    if (!supportsAppleSignIn) {
      _setSignInError('Sign in with Apple is unavailable on this device.');
      return null;
    }
    try {
      _setSignInError(null);
      return await _resolvedAuthBackend.signInWithProvider(AppleAuthProvider());
    } catch (error) {
      if (_isProviderCancellation(error)) {
        _setSignInError(
          'Apple sign-in was closed before an account was selected.',
        );
        PrivacySafeDiagnostics.report(
          FocusHavenDiagnosticEvent.appleSignInCancelled,
        );
        return null;
      }
      _setSignInError(
        error is FirebaseAuthException
            ? (error.message ?? error.code)
            : 'Apple sign-in could not start: ${error.runtimeType}',
      );
      PrivacySafeDiagnostics.report(
        FocusHavenDiagnosticEvent.appleSignIn,
        error: error,
      );
      return null;
    }
  }

  Future<AccountReauthenticationResult>
  reauthenticateForAccountDeletion() async {
    if (_isDisposed) {
      return const AccountReauthenticationResult.unavailable();
    }
    final backend = _resolvedAuthBackend;
    final currentUser = backend.currentUser;
    if (currentUser == null || currentUser.isAnonymous) {
      return const AccountReauthenticationResult.unauthenticated();
    }

    try {
      final providerIds = backend.currentProviderIds;
      if (providerIds.contains('apple.com')) {
        final authorizationCode = (await backend.reauthenticateWithProvider(
          AppleAuthProvider(),
        ))?.trim();
        if (authorizationCode == null || authorizationCode.isEmpty) {
          PrivacySafeDiagnostics.report(
            FocusHavenDiagnosticEvent.accountReauthentication,
            error: StateError(
              'Apple reauthentication did not provide a revocation code.',
            ),
          );
          return const AccountReauthenticationResult.unavailable();
        }
        return AccountReauthenticationResult.verified(
          appleAuthorizationCode: authorizationCode,
        );
      }
      if (providerIds.contains('google.com')) {
        final googleAuth = await _resolvedGoogleAuthBackend.authenticate();
        if (googleAuth == null) {
          return const AccountReauthenticationResult.cancelled();
        }
        await backend.reauthenticateWithCredential(
          GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          ),
        );
        return const AccountReauthenticationResult.verified();
      }
      return const AccountReauthenticationResult.unsupportedProvider();
    } catch (error) {
      if (_isProviderCancellation(error)) {
        return const AccountReauthenticationResult.cancelled();
      }
      PrivacySafeDiagnostics.report(
        FocusHavenDiagnosticEvent.accountReauthentication,
        error: error,
      );
      return const AccountReauthenticationResult.unavailable();
    }
  }

  Future<void> revokeAppleAuthorization(String authorizationCode) async {
    if (_isDisposed) throw StateError('Authentication is unavailable.');
    if (authorizationCode.trim().isEmpty) {
      throw ArgumentError.value(
        authorizationCode,
        'authorizationCode',
        'An Apple authorization code is required.',
      );
    }
    await _resolvedAuthBackend.revokeTokenWithAuthorizationCode(
      authorizationCode,
    );
  }

  Future<void> establishGuestAfterAccountDeletion() async {
    if (_isDisposed) return;
    try {
      await _resolvedAuthBackend.signOut();
    } catch (error) {
      PrivacySafeDiagnostics.report(
        FocusHavenDiagnosticEvent.accountDeletionSessionReset,
        error: error,
      );
    }
    if (_isDisposed) return;
    await signInAnonymouslyIfNeeded();
  }

  Future<void> signOut() async {
    if (_isDisposed) return;
    _setSignInError(null);
    try {
      final backend = _resolvedAuthBackend;
      await backend.signOut();
    } catch (error, stackTrace) {
      PrivacySafeDiagnostics.report(
        FocusHavenDiagnosticEvent.signOut,
        error: error,
      );
      Error.throwWithStackTrace(
        StateError('FocusHaven could not sign out of this account.'),
        stackTrace,
      );
    }
    if (_isDisposed) return;
    // Keep the Google session so signing back into FocusHaven is reliable.
    await signInAnonymouslyIfNeeded();
  }

  AuthBackend get _resolvedAuthBackend =>
      authBackend ?? (_defaultAuthBackend ??= FirebaseAuthBackend());

  GoogleAuthBackend get _resolvedGoogleAuthBackend =>
      googleAuthBackend ??
      (_defaultGoogleAuthBackend ??= GoogleSignInBackend());

  static bool _isProviderCancellation(Object error) {
    if (error is! FirebaseAuthException) return false;
    return const <String>{
      'canceled',
      'cancelled',
      'popup-closed-by-user',
      'web-context-cancelled',
    }.contains(error.code);
  }

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
