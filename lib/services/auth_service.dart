import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends ChangeNotifier {
  User? user;

  String? _signInError;
  String? get signInError => _signInError;

  bool get isSignedIn => user != null && !user!.isAnonymous;
  String get displayName => user?.displayName ?? user?.email ?? 'Guest';

  AuthService() {
    try {
      FirebaseAuth.instance.authStateChanges().listen((currentUser) {
        user = currentUser;
        notifyListeners();
      });
      signInAnonymouslyIfNeeded();
    } catch (_) {
      // Authentication remains unavailable until Firebase is configured.
    }
  }

  Future<void> signInAnonymouslyIfNeeded() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
    } catch (_) {}
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      _signInError = null;
      final googleSignIn = GoogleSignIn();
      final googleUser =
          await googleSignIn.signInSilently() ?? await googleSignIn.signIn();
      if (googleUser == null) {
        _signInError =
            'Google sign-in was closed before an account was selected.';
        notifyListeners();
        debugPrint(
            'Google sign-in was cancelled before an account was selected.');
        return null;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      // Sign in directly so a prior anonymous guest session cannot block
      // returning to an existing Google account.
      return FirebaseAuth.instance.signInWithCredential(credential);
    } catch (error) {
      _signInError = error is FirebaseAuthException
          ? (error.message ?? error.code)
          : 'Google sign-in could not start: ${error.runtimeType}';
      notifyListeners();
      debugPrint('Google sign-in failed: $error');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (error) {
      debugPrint('Sign-out failed: $error');
    }
    // Keep the Google session so signing back into FocusHaven is reliable.
    await signInAnonymouslyIfNeeded();
  }
}
