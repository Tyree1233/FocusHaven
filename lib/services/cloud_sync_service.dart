import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

@immutable
final class CloudSyncIdentity {
  const CloudSyncIdentity({required this.uid, required this.isAnonymous});

  final String uid;
  final bool isAnonymous;
}

enum CloudBackupFetchStatus {
  found,
  notFound,
  unauthenticated,
  invalid,
  unavailable,
}

@immutable
final class CloudBackupFetchResult {
  const CloudBackupFetchResult._(this.status, this.backup);

  const CloudBackupFetchResult.notFound()
    : this._(CloudBackupFetchStatus.notFound, null);

  const CloudBackupFetchResult.unauthenticated()
    : this._(CloudBackupFetchStatus.unauthenticated, null);

  const CloudBackupFetchResult.invalid()
    : this._(CloudBackupFetchStatus.invalid, null);

  const CloudBackupFetchResult.unavailable()
    : this._(CloudBackupFetchStatus.unavailable, null);

  factory CloudBackupFetchResult.found(Map<String, dynamic> backup) =>
      CloudBackupFetchResult._(CloudBackupFetchStatus.found, backup);

  final CloudBackupFetchStatus status;
  final Map<String, dynamic>? backup;
}

abstract interface class CloudSyncBackend {
  CloudSyncIdentity? get currentIdentity;

  Future<void> saveBackup(String uid, Map<String, dynamic> backup);

  Future<Object?> loadBackup(String uid);

  Future<void> deleteBackup(String uid);
}

final class FirebaseCloudSyncBackend implements CloudSyncBackend {
  FirebaseCloudSyncBackend({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  @override
  CloudSyncIdentity? get currentIdentity {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    return CloudSyncIdentity(uid: user.uid, isAnonymous: user.isAnonymous);
  }

  @override
  Future<void> saveBackup(String uid, Map<String, dynamic> backup) async {
    await _firestore.collection('users').doc(uid).set({
      'focusBackup': backup,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<Object?> loadBackup(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    return snapshot.data()?['focusBackup'];
  }

  @override
  Future<void> deleteBackup(String uid) async {
    final document = _firestore.collection('users').doc(uid);
    if (!(await document.get()).exists) return;

    await document.update({
      'focusBackup': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

class CloudSyncService {
  CloudSyncService({this.backend});

  final CloudSyncBackend? backend;
  CloudSyncBackend? _defaultBackend;

  Future<bool> syncFocusData(Map<String, dynamic> backup) async {
    try {
      final identity = _authenticatedIdentity;
      if (identity == null) return false;

      final safeBackup = _copyBackup(backup);
      if (safeBackup == null) return false;

      await _resolvedBackend.saveBackup(identity.uid, safeBackup);
      return true;
    } catch (error) {
      debugPrint('Cloud backup upload failed: ${error.runtimeType}');
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchFocusData() async =>
      (await fetchFocusDataResult()).backup;

  Future<CloudBackupFetchResult> fetchFocusDataResult() async {
    try {
      final identity = _authenticatedIdentity;
      if (identity == null) {
        return const CloudBackupFetchResult.unauthenticated();
      }

      final backup = await _resolvedBackend.loadBackup(identity.uid);
      if (backup == null) {
        return const CloudBackupFetchResult.notFound();
      }
      if (backup is! Map) {
        return const CloudBackupFetchResult.invalid();
      }

      final safeBackup = _copyBackup(backup);
      if (safeBackup == null) {
        return const CloudBackupFetchResult.invalid();
      }
      return CloudBackupFetchResult.found(safeBackup);
    } catch (error) {
      debugPrint('Cloud backup download failed: ${error.runtimeType}');
      return const CloudBackupFetchResult.unavailable();
    }
  }

  Future<bool> deleteFocusData() async {
    try {
      final identity = _authenticatedIdentity;
      if (identity == null) return false;

      await _resolvedBackend.deleteBackup(identity.uid);
      return true;
    } catch (error) {
      debugPrint('Cloud backup deletion failed: ${error.runtimeType}');
      return false;
    }
  }

  CloudSyncBackend get _resolvedBackend =>
      backend ?? (_defaultBackend ??= FirebaseCloudSyncBackend());

  CloudSyncIdentity? get _authenticatedIdentity {
    final identity = _resolvedBackend.currentIdentity;
    if (identity == null ||
        identity.isAnonymous ||
        identity.uid.trim().isEmpty) {
      return null;
    }
    return identity;
  }

  static const Object _invalidBackupValue = Object();

  Map<String, dynamic>? _copyBackup(Map<Object?, Object?> backup) {
    final copy = <String, dynamic>{};
    for (final entry in backup.entries) {
      final key = entry.key;
      if (key is! String) return null;

      final value = _copyBackupValue(entry.value);
      if (identical(value, _invalidBackupValue)) return null;
      copy[key] = value;
    }
    return copy;
  }

  Object? _copyBackupValue(Object? value) {
    if (value == null || value is String || value is bool || value is int) {
      return value;
    }
    if (value is double) {
      return value.isFinite ? value : _invalidBackupValue;
    }
    if (value is List) {
      final copy = <Object?>[];
      for (final item in value) {
        final copiedItem = _copyBackupValue(item);
        if (identical(copiedItem, _invalidBackupValue)) {
          return _invalidBackupValue;
        }
        copy.add(copiedItem);
      }
      return copy;
    }
    if (value is Map) {
      final copiedMap = _copyBackup(value);
      return copiedMap ?? _invalidBackupValue;
    }
    return _invalidBackupValue;
  }
}
