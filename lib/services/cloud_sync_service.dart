import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CloudSyncService {
  Future<bool> syncFocusData(Map<String, dynamic> backup) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) return false;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'focusBackup': backup,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (_) {}
    return false;
  }

  Future<Map<String, dynamic>?> fetchFocusData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) return null;
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final backup = snapshot.data()?['focusBackup'];
      return backup is Map<String, dynamic> ? backup : null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteFocusData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) return false;

      final document =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      if (!(await document.get()).exists) return true;

      await document.update({
        'focusBackup': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
