import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/services/cloud_sync_service.dart';

void main() {
  test('blocks cloud operations without an authenticated account', () async {
    final backend = _FakeCloudSyncBackend();
    final service = CloudSyncService(backend: backend);

    expect(await service.syncFocusData({'focusSeconds': 1500}), isFalse);
    expect(await service.fetchFocusData(), isNull);
    expect(await service.deleteFocusData(), isFalse);

    backend.identity = const CloudSyncIdentity(
      uid: 'guest-user',
      isAnonymous: true,
    );

    expect(await service.syncFocusData({'focusSeconds': 1500}), isFalse);
    expect(await service.fetchFocusData(), isNull);
    expect(await service.deleteFocusData(), isFalse);
    expect(backend.totalCalls, 0);
  });

  test('blocks accounts whose authenticated user ID is blank', () async {
    final backend = _FakeCloudSyncBackend(
      identity: const CloudSyncIdentity(uid: '  ', isAnonymous: false),
    );
    final service = CloudSyncService(backend: backend);

    expect(await service.syncFocusData({'focusSeconds': 1500}), isFalse);
    expect(await service.fetchFocusData(), isNull);
    expect(await service.deleteFocusData(), isFalse);
    expect(backend.totalCalls, 0);
  });

  test('uploads a detached snapshot to the authenticated user', () async {
    final backend = _FakeCloudSyncBackend.signedIn();
    final service = CloudSyncService(backend: backend);
    final history = <Map<String, dynamic>>[
      {'task': 'Write proposal', 'minutes': 25},
    ];
    final backup = <String, dynamic>{
      'focusSeconds': 1500,
      'focusHistory': history,
      'profile': <String, dynamic>{'style': 'Deep worker'},
    };

    expect(await service.syncFocusData(backup), isTrue);

    history.first['task'] = 'Changed later';
    history.add({'task': 'Another task'});
    (backup['profile'] as Map<String, dynamic>)['style'] = 'Changed later';

    expect(backend.savedUid, 'account-123');
    expect(backend.saveCalls, 1);
    expect(backend.savedBackup, {
      'focusSeconds': 1500,
      'focusHistory': [
        {'task': 'Write proposal', 'minutes': 25},
      ],
      'profile': {'style': 'Deep worker'},
    });
  });

  test('rejects non-portable backup values before upload', () async {
    final backend = _FakeCloudSyncBackend.signedIn();
    final service = CloudSyncService(backend: backend);

    expect(
      await service.syncFocusData({'createdAt': DateTime(2026, 8, 9)}),
      isFalse,
    );
    expect(await service.syncFocusData({'progress': double.nan}), isFalse);
    expect(backend.saveCalls, 0);
  });

  test('downloads a validated detached backup', () async {
    final storedHistory = <Object?>[
      <Object?, Object?>{'task': 'Plan tomorrow', 'minutes': 25},
    ];
    final backend = _FakeCloudSyncBackend.signedIn(
      loadedBackup: <Object?, Object?>{
        'focusSeconds': 1500,
        'focusHistory': storedHistory,
      },
    );
    final service = CloudSyncService(backend: backend);

    final backup = await service.fetchFocusData();

    expect(backend.loadedUid, 'account-123');
    expect(backup, {
      'focusSeconds': 1500,
      'focusHistory': [
        {'task': 'Plan tomorrow', 'minutes': 25},
      ],
    });

    (backup!['focusHistory'] as List<Object?>).clear();
    expect(storedHistory, hasLength(1));
  });

  test('rejects malformed downloaded backup data', () async {
    final backend = _FakeCloudSyncBackend.signedIn(
      loadedBackup: <Object?, Object?>{
        'focusHistory': <Object?>[
          <Object?, Object?>{1: 'non-string key'},
        ],
      },
    );
    final service = CloudSyncService(backend: backend);

    expect(await service.fetchFocusData(), isNull);

    backend.loadedBackup = 'not a backup map';
    expect(await service.fetchFocusData(), isNull);
  });

  test('reports distinct cloud backup download outcomes', () async {
    final backend = _FakeCloudSyncBackend();
    final service = CloudSyncService(backend: backend);

    var result = await service.fetchFocusDataResult();
    expect(result.status, CloudBackupFetchStatus.unauthenticated);
    expect(result.backup, isNull);

    backend.identity = const CloudSyncIdentity(
      uid: 'account-123',
      isAnonymous: false,
    );
    result = await service.fetchFocusDataResult();
    expect(result.status, CloudBackupFetchStatus.notFound);
    expect(result.backup, isNull);

    backend.loadedBackup = 'not a backup map';
    result = await service.fetchFocusDataResult();
    expect(result.status, CloudBackupFetchStatus.invalid);
    expect(result.backup, isNull);

    backend.loadedBackup = <Object?, Object?>{
      'focusSeconds': 1500,
      'focusHistory': <Object?>[],
    };
    result = await service.fetchFocusDataResult();
    expect(result.status, CloudBackupFetchStatus.found);
    expect(result.backup, {'focusSeconds': 1500, 'focusHistory': <Object?>[]});

    backend.shouldThrow = true;
    result = await service.fetchFocusDataResult();
    expect(result.status, CloudBackupFetchStatus.unavailable);
    expect(result.backup, isNull);
  });

  test('deletes only the authenticated users backup', () async {
    final backend = _FakeCloudSyncBackend.signedIn();
    final service = CloudSyncService(backend: backend);

    expect(await service.deleteFocusData(), isTrue);
    expect(backend.deleteCalls, 1);
    expect(backend.deletedUid, 'account-123');
  });

  test('contains backend failures without reporting success', () async {
    final backend = _FakeCloudSyncBackend.signedIn()..shouldThrow = true;
    final service = CloudSyncService(backend: backend);

    expect(await service.syncFocusData({'focusSeconds': 1500}), isFalse);
    expect(await service.fetchFocusData(), isNull);
    expect(await service.deleteFocusData(), isFalse);
  });
}

final class _FakeCloudSyncBackend implements CloudSyncBackend {
  _FakeCloudSyncBackend({this.identity});

  _FakeCloudSyncBackend.signedIn({this.loadedBackup})
    : identity = const CloudSyncIdentity(
        uid: 'account-123',
        isAnonymous: false,
      );

  CloudSyncIdentity? identity;

  Object? loadedBackup;
  bool shouldThrow = false;
  int saveCalls = 0;
  int loadCalls = 0;
  int deleteCalls = 0;
  String? savedUid;
  String? loadedUid;
  String? deletedUid;
  Map<String, dynamic>? savedBackup;

  int get totalCalls => saveCalls + loadCalls + deleteCalls;

  @override
  CloudSyncIdentity? get currentIdentity => identity;

  @override
  Future<void> saveBackup(String uid, Map<String, dynamic> backup) async {
    saveCalls += 1;
    if (shouldThrow) throw StateError('save failed');
    savedUid = uid;
    savedBackup = backup;
  }

  @override
  Future<Object?> loadBackup(String uid) async {
    loadCalls += 1;
    if (shouldThrow) throw StateError('load failed');
    loadedUid = uid;
    return loadedBackup;
  }

  @override
  Future<void> deleteBackup(String uid) async {
    deleteCalls += 1;
    if (shouldThrow) throw StateError('delete failed');
    deletedUid = uid;
  }
}
