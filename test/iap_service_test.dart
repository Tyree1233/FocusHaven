import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/iap_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _FakeStoreBackend implements IAPStoreBackend {
  final _purchaseUpdates = StreamController<List<PurchaseDetails>>.broadcast();
  final _completedPurchases = StreamController<PurchaseDetails>.broadcast();

  List<ProductDetails> products = [];
  IAPError? queryError;
  bool purchaseStarted = true;
  int queryCalls = 0;
  int buyCalls = 0;
  int restoreCalls = 0;
  PurchaseParam? lastPurchaseParam;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _purchaseUpdates.stream;

  Stream<PurchaseDetails> get completedPurchases => _completedPurchases.stream;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> productIdentifiers,
  ) async {
    queryCalls += 1;
    return ProductDetailsResponse(
      productDetails: List<ProductDetails>.of(products),
      notFoundIDs:
          products.any((product) => product.id == IAPService.proProductId)
          ? []
          : productIdentifiers.toList(),
      error: queryError,
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    buyCalls += 1;
    lastPurchaseParam = purchaseParam;
    return purchaseStarted;
  }

  @override
  Future<void> restorePurchases() async {
    restoreCalls += 1;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    _completedPurchases.add(purchase);
  }

  void emit(List<PurchaseDetails> purchases) {
    _purchaseUpdates.add(purchases);
  }

  Future<void> dispose() async {
    await _purchaseUpdates.close();
    await _completedPurchases.close();
  }
}

ProductDetails _product(String id, {String price = r'$4.99'}) => ProductDetails(
  id: id,
  title: 'Product $id',
  description: 'Test product',
  price: price,
  rawPrice: 4.99,
  currencyCode: 'USD',
  currencySymbol: r'$',
);

PurchaseDetails _purchase({
  required String productId,
  required PurchaseStatus status,
  bool pendingCompletePurchase = false,
}) {
  final purchase = PurchaseDetails(
    purchaseID: 'purchase-$productId',
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local',
      serverVerificationData: 'server',
      source: 'test',
    ),
    transactionDate: '1',
    status: status,
  );
  purchase.pendingCompletePurchase = pendingCompletePurchase;
  return purchase;
}

IAPService _createService(_FakeStoreBackend backend) {
  final service = IAPService(storeBackend: backend);
  addTearDown(() async {
    service.dispose();
    await backend.dispose();
  });
  return service;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'loads the persisted entitlement before initialization completes',
    () async {
      SharedPreferences.setMockInitialValues({'isProUser': true});
      final backend = _FakeStoreBackend();
      final service = _createService(backend);

      await service.initialized;

      expect(service.lastKnownIsPro, isTrue);
      expect(await IAPService.isProUser(), isTrue);
    },
  );

  test('repairs malformed persisted entitlement as inactive', () async {
    SharedPreferences.setMockInitialValues({'isProUser': 'true'});
    final backend = _FakeStoreBackend();
    final service = _createService(backend);

    await service.initialized;

    expect(service.lastKnownIsPro, isFalse);
    expect(await service.refreshEntitlement(), isFalse);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('isProUser'), isFalse);
    expect(backend.queryCalls, 0);
    expect(backend.restoreCalls, 0);
  });

  test('returns only the exact FocusHaven Pro product price', () async {
    final backend = _FakeStoreBackend()
      ..products = [
        _product('unrelated_product', price: r'$1.99'),
        _product(IAPService.proProductId, price: r'$4.99'),
      ];
    final service = _createService(backend);
    await service.initialized;

    expect(await service.proPrice(), r'$4.99');
    expect(backend.queryCalls, 1);
  });

  test('returns no price when the Pro product is unavailable', () async {
    final backend = _FakeStoreBackend()
      ..products = [_product('unrelated_product')];
    final service = _createService(backend);
    await service.initialized;

    expect(await service.proPrice(), isNull);
  });

  test('reports store query failures instead of hiding them', () async {
    final backend = _FakeStoreBackend()
      ..queryError = IAPError(
        source: 'test',
        code: 'store-unavailable',
        message: 'Store unavailable',
      );
    final service = _createService(backend);
    await service.initialized;

    await expectLater(service.proPrice(), throwsA(isA<StateError>()));
  });

  test('starts a purchase with the exact Pro product', () async {
    final backend = _FakeStoreBackend()
      ..products = [
        _product('unrelated_product'),
        _product(IAPService.proProductId),
      ];
    final service = _createService(backend);
    await service.initialized;

    await service.buyPro();

    expect(backend.buyCalls, 1);
    expect(
      backend.lastPurchaseParam?.productDetails.id,
      IAPService.proProductId,
    );
  });

  test('rejects a purchase the platform cannot start', () async {
    final backend = _FakeStoreBackend()
      ..products = [_product(IAPService.proProductId)]
      ..purchaseStarted = false;
    final service = _createService(backend);
    await service.initialized;

    await expectLater(service.buyPro(), throwsA(isA<StateError>()));
    expect(backend.buyCalls, 1);
  });

  test('grants and completes the exact purchased Pro product', () async {
    final backend = _FakeStoreBackend();
    final service = _createService(backend);
    await service.initialized;
    final purchase = _purchase(
      productId: IAPService.proProductId,
      status: PurchaseStatus.purchased,
      pendingCompletePurchase: true,
    );
    final entitlement = service.entitlementChanges.firstWhere((isPro) => isPro);
    final completed = backend.completedPurchases.firstWhere(
      (candidate) => identical(candidate, purchase),
    );

    backend.emit([purchase]);

    expect(await entitlement, isTrue);
    expect(await completed, same(purchase));
    expect(service.lastKnownIsPro, isTrue);
    expect(await IAPService.isProUser(), isTrue);
  });

  test('does not grant Pro for a different purchased product', () async {
    final backend = _FakeStoreBackend();
    final service = _createService(backend);
    await service.initialized;
    final unrelatedPurchase = _purchase(
      productId: 'unrelated_product',
      status: PurchaseStatus.purchased,
      pendingCompletePurchase: true,
    );
    final processingBarrier = _purchase(
      productId: IAPService.proProductId,
      status: PurchaseStatus.canceled,
      pendingCompletePurchase: true,
    );
    final completed = backend.completedPurchases.firstWhere(
      (candidate) => identical(candidate, processingBarrier),
    );

    backend.emit([unrelatedPurchase, processingBarrier]);
    await completed;

    expect(service.lastKnownIsPro, isFalse);
    expect(await IAPService.isProUser(), isFalse);
  });

  test(
    'restore requests reach the store while the service is active',
    () async {
      final backend = _FakeStoreBackend();
      final service = _createService(backend);
      await service.initialized;

      await service.restorePurchases();

      expect(backend.restoreCalls, 1);
    },
  );

  test('store operations are safe after disposal', () async {
    final backend = _FakeStoreBackend()
      ..products = [_product(IAPService.proProductId)];
    final service = _createService(backend);
    await service.initialized;
    service.dispose();

    await service.restorePurchases();

    expect(backend.restoreCalls, 0);
    expect(await service.proPrice(), isNull);
    await expectLater(service.buyPro(), throwsA(isA<StateError>()));
    expect(backend.buyCalls, 0);
  });

  test(
    'Riverpod exposes initialized entitlement and follows purchases',
    () async {
      SharedPreferences.setMockInitialValues({'isProUser': false});
      final backend = _FakeStoreBackend();
      final service = _createService(backend);
      final container = ProviderContainer(
        overrides: [iapServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final proUpdate = Completer<bool>();
      final subscription = container.listen(proEntitlementProvider, (
        previous,
        next,
      ) {
        next.whenData((isPro) {
          if (isPro && !proUpdate.isCompleted) {
            proUpdate.complete(isPro);
          }
        });
      }, fireImmediately: true);
      addTearDown(subscription.close);

      expect(await container.read(proEntitlementProvider.future), isFalse);
      expect(container.read(iapServiceProvider), same(service));
      await Future<void>.delayed(Duration.zero);

      final purchase = _purchase(
        productId: IAPService.proProductId,
        status: PurchaseStatus.purchased,
      );
      backend.emit([purchase]);

      expect(
        await proUpdate.future.timeout(const Duration(seconds: 1)),
        isTrue,
      );
      expect(container.read(proEntitlementProvider).value, isTrue);
    },
  );
}
