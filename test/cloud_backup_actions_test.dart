import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/app_localizations.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/cloud_sync_service.dart';
import 'package:focushaven/services/iap_service.dart';
import 'package:focushaven/widgets/cloud_backup_actions.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _FakeStoreBackend implements IAPStoreBackend {
  final _purchases = StreamController<List<PurchaseDetails>>.broadcast();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _purchases.stream;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> productIdentifiers,
  ) async => ProductDetailsResponse(
    productDetails: const [],
    notFoundIDs: productIdentifiers.toList(),
  );

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async =>
      true;

  @override
  Future<void> restorePurchases() async {}

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}

  Future<void> dispose() => _purchases.close();
}

final class _FakeCloudBackend implements CloudSyncBackend {
  CloudSyncIdentity? identity = const CloudSyncIdentity(
    uid: 'account-123',
    isAnonymous: false,
  );
  Completer<void>? pendingSave;
  Completer<Object?>? pendingLoad;
  Object? loadedBackup;
  bool failSave = false;
  bool failLoad = false;
  int saveCalls = 0;
  int loadCalls = 0;
  Map<String, dynamic>? savedBackup;

  @override
  CloudSyncIdentity? get currentIdentity => identity;

  @override
  Future<void> saveBackup(String uid, Map<String, dynamic> backup) async {
    saveCalls += 1;
    if (failSave) throw StateError('upload failed');
    savedBackup = backup;
    final pending = pendingSave;
    if (pending != null) await pending.future;
  }

  @override
  Future<Object?> loadBackup(String uid) async {
    loadCalls += 1;
    if (failLoad) throw StateError('download failed');
    final pending = pendingLoad;
    return pending == null ? loadedBackup : pending.future;
  }

  @override
  Future<void> deleteBackup(String uid) async {}
}

Widget _app({
  required IAPService iapService,
  required CloudSyncService cloudService,
  required bool isSignedIn,
  required CloudBackupRestorer restoreBackup,
}) {
  return ProviderScope(
    overrides: [
      iapServiceProvider.overrideWithValue(iapService),
      cloudSyncServiceProvider.overrideWithValue(cloudService),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: Scaffold(
        body: CloudBackupActions(
          isSignedIn: isSignedIn,
          backup: const {'focusSeconds': 1500, 'focusHistory': <Object?>[]},
          restoreBackup: restoreBackup,
        ),
      ),
    ),
  );
}

IAPService _iapService(_FakeStoreBackend store) {
  final service = IAPService(storeBackend: store);
  addTearDown(() async {
    service.dispose();
    await store.dispose();
  });
  return service;
}

void _invokeTextButton(WidgetTester tester, String label) {
  tester
      .widget<TextButton>(find.widgetWithText(TextButton, label))
      .onPressed!
      .call();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('requires sign-in before starting cloud backup', (tester) async {
    SharedPreferences.setMockInitialValues({'isProUser': true});
    final store = _FakeStoreBackend();
    final iapService = _iapService(store);
    final cloudBackend = _FakeCloudBackend();

    await tester.pumpWidget(
      _app(
        iapService: iapService,
        cloudService: CloudSyncService(backend: cloudBackend),
        isSignedIn: false,
        restoreBackup: (_) => true,
      ),
    );
    await tester.pumpAndSettle();

    _invokeTextButton(tester, 'Back up');
    await tester.pumpAndSettle();

    expect(cloudBackend.saveCalls, 0);
    expect(
      find.text('Sign in with Google to back up your focus data'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('requires Pro before starting cloud restore', (tester) async {
    final store = _FakeStoreBackend();
    final iapService = _iapService(store);
    final cloudBackend = _FakeCloudBackend();

    await tester.pumpWidget(
      _app(
        iapService: iapService,
        cloudService: CloudSyncService(backend: cloudBackend),
        isSignedIn: true,
        restoreBackup: (_) => true,
      ),
    );
    await tester.pumpAndSettle();

    _invokeTextButton(tester, 'Restore');
    await tester.pumpAndSettle();

    expect(cloudBackend.loadCalls, 0);
    expect(find.text('Upgrade to Pro to restore cloud backup'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocks overlapping cloud backups and reports success', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'isProUser': true});
    final store = _FakeStoreBackend();
    final iapService = _iapService(store);
    final cloudBackend = _FakeCloudBackend()..pendingSave = Completer<void>();

    await tester.pumpWidget(
      _app(
        iapService: iapService,
        cloudService: CloudSyncService(backend: cloudBackend),
        isSignedIn: true,
        restoreBackup: (_) => true,
      ),
    );
    await tester.pumpAndSettle();

    final backupButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Back up'),
    );
    backupButton.onPressed!.call();
    backupButton.onPressed!.call();
    await tester.pump();
    await tester.pump();

    expect(cloudBackend.saveCalls, 1);
    expect(find.text('Backing up…'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Backing up…'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Restore'))
          .onPressed,
      isNull,
    );

    cloudBackend.pendingSave!.complete();
    await tester.pumpAndSettle();

    expect(cloudBackend.savedBackup, {
      'focusSeconds': 1500,
      'focusHistory': <Object?>[],
    });
    expect(find.text('Focus data backed up securely'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocks overlapping restores and applies downloaded data', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'isProUser': true});
    final store = _FakeStoreBackend();
    final iapService = _iapService(store);
    final cloudBackend = _FakeCloudBackend()
      ..pendingLoad = Completer<Object?>();
    Map<String, dynamic>? restoredBackup;

    await tester.pumpWidget(
      _app(
        iapService: iapService,
        cloudService: CloudSyncService(backend: cloudBackend),
        isSignedIn: true,
        restoreBackup: (backup) {
          restoredBackup = backup;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    final restoreButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Restore'),
    );
    restoreButton.onPressed!.call();
    restoreButton.onPressed!.call();
    await tester.pump();
    await tester.pump();

    expect(cloudBackend.loadCalls, 1);
    expect(find.text('Restoring…'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Back up'))
          .onPressed,
      isNull,
    );

    cloudBackend.pendingLoad!.complete({
      'focusSeconds': 900,
      'focusHistory': <Object?>[],
    });
    await tester.pumpAndSettle();

    expect(restoredBackup, {'focusSeconds': 900, 'focusHistory': <Object?>[]});
    expect(find.text('Focus data restored from cloud'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reports unavailable cloud restore without claiming it is empty',
    (tester) async {
      SharedPreferences.setMockInitialValues({'isProUser': true});
      final store = _FakeStoreBackend();
      final iapService = _iapService(store);
      final cloudBackend = _FakeCloudBackend()..failLoad = true;
      var restoreCalls = 0;

      await tester.pumpWidget(
        _app(
          iapService: iapService,
          cloudService: CloudSyncService(backend: cloudBackend),
          isSignedIn: true,
          restoreBackup: (_) {
            restoreCalls += 1;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();

      _invokeTextButton(tester, 'Restore');
      await tester.pumpAndSettle();

      expect(cloudBackend.loadCalls, 1);
      expect(restoreCalls, 0);
      expect(
        find.text(
          'Cloud restore is unavailable. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('No cloud backup found yet'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rejects malformed downloaded backup before restoration', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'isProUser': true});
    final store = _FakeStoreBackend();
    final iapService = _iapService(store);
    final cloudBackend = _FakeCloudBackend()..loadedBackup = 'not a backup map';
    var restoreCalls = 0;

    await tester.pumpWidget(
      _app(
        iapService: iapService,
        cloudService: CloudSyncService(backend: cloudBackend),
        isSignedIn: true,
        restoreBackup: (_) {
          restoreCalls += 1;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    _invokeTextButton(tester, 'Restore');
    await tester.pumpAndSettle();

    expect(cloudBackend.loadCalls, 1);
    expect(restoreCalls, 0);
    expect(
      find.text('That cloud backup could not be restored'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('contains failed cloud uploads and restores the controls', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'isProUser': true});
    final store = _FakeStoreBackend();
    final iapService = _iapService(store);
    final cloudBackend = _FakeCloudBackend()..failSave = true;

    await tester.pumpWidget(
      _app(
        iapService: iapService,
        cloudService: CloudSyncService(backend: cloudBackend),
        isSignedIn: true,
        restoreBackup: (_) => true,
      ),
    );
    await tester.pumpAndSettle();

    _invokeTextButton(tester, 'Back up');
    await tester.pumpAndSettle();

    expect(cloudBackend.saveCalls, 1);
    expect(
      find.text('Backup failed. Check your Firebase setup.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Back up'))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
}
