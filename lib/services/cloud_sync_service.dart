import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CloudSyncService {
  Future<void> syncTimerSettings(int secondsRemaining) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'secondsRemaining': secondsRemaining,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<int?> fetchTimerSettings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      return snapshot.data()?['secondsRemaining'] as int?;
    } catch (_) {
      return null;
    }
  }
}
