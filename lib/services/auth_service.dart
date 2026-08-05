import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends ChangeNotifier {
  User? user;

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
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser?.isAnonymous ?? false) {
        return currentUser!.linkWithCredential(credential);
      }
      return FirebaseAuth.instance.signInWithCredential(credential);
    } catch (error) {
      debugPrint('Google sign-in failed: $error');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
      await signInAnonymouslyIfNeeded();
    } catch (error) {
      debugPrint('Sign-out failed: $error');
    }
  }
}
