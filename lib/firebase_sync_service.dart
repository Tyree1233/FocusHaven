
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CloudSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> syncTimerSettings(int secondsRemaining) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'secondsRemaining': secondsRemaining,
          'updatedAt': FieldValue.serverTimestamp()
        }, SetOptions(merge: true));
      }
    } catch (_) {
      // Cloud sync is optional until Firebase is configured and a user signs in.
    }
  }

  Future<int?> fetchTimerSettings() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()!.containsKey('secondsRemaining')) {
          return doc.data()!['secondsRemaining'];
        }
      }
    } catch (_) {
      // No cloud value is available when Firebase has not been configured.
    }
    return null;
  }
}
