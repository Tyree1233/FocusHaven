import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class IAPStoreBackend {
  Stream<List<PurchaseDetails>> get purchaseStream;

  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> productIdentifiers,
  );

  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});

  Future<void> restorePurchases();

  Future<void> completePurchase(PurchaseDetails purchase);
}

final class PluginIAPStoreBackend implements IAPStoreBackend {
  PluginIAPStoreBackend([InAppPurchase? inAppPurchase])
    : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance;

  final InAppPurchase _inAppPurchase;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      _inAppPurchase.purchaseStream;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> productIdentifiers,
  ) => _inAppPurchase.queryProductDetails(productIdentifiers);

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

  @override
  Future<void> restorePurchases() => _inAppPurchase.restorePurchases();

  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _inAppPurchase.completePurchase(purchase);
}

class IAPService {
  static const _proKey = 'isProUser';
  static const proProductId = 'focushaven_pro';

  final IAPStoreBackend _store;
  final StreamController<bool> _entitlementController =
      StreamController<bool>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool? _lastKnownIsPro;
  bool _isDisposed = false;

  IAPService({InAppPurchase? inAppPurchase, IAPStoreBackend? storeBackend})
    : assert(
        inAppPurchase == null || storeBackend == null,
        'Provide either inAppPurchase or storeBackend, not both.',
      ),
      _store = storeBackend ?? PluginIAPStoreBackend(inAppPurchase) {
    _subscription = _store.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: _handlePurchaseError,
    );
    initialized = _loadInitialEntitlement();
  }

  /// Completes after the persisted entitlement has been loaded.
  late final Future<void> initialized;

  /// Emits whenever the locally recognized Pro entitlement changes.
  ///
  /// The stream is intentionally separate from store availability and pricing
  /// so views that only care about access do not rebuild for store operations.
  Stream<bool> get entitlementChanges => _entitlementController.stream;

  /// The most recently loaded entitlement, or `null` until storage is read.
  bool? get lastKnownIsPro => _lastKnownIsPro;

  Future<void> _loadInitialEntitlement() async {
    try {
      await refreshEntitlement();
    } catch (error, stackTrace) {
      _handlePurchaseError(error, stackTrace);
    }
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) {
    if (_isDisposed) return;
    unawaited(_processPurchaseUpdates(purchases));
  }

  Future<void> _processPurchaseUpdates(List<PurchaseDetails> purchases) async {
    try {
      for (final purchase in purchases) {
        if (_isDisposed) return;

        final grantsPro =
            purchase.productID == proProductId &&
            (purchase.status == PurchaseStatus.purchased ||
                purchase.status == PurchaseStatus.restored);
        if (grantsPro) {
          final preferences = await SharedPreferences.getInstance();
          await preferences.setBool(_proKey, true);
          _publishEntitlement(true);
        }
        if (purchase.pendingCompletePurchase && !_isDisposed) {
          await _store.completePurchase(purchase);
        }
      }
    } catch (error, stackTrace) {
      _handlePurchaseError(error, stackTrace);
    }
  }

  void _handlePurchaseError(Object error, StackTrace stackTrace) {
    if (!_isDisposed) {
      _entitlementController.addError(error, stackTrace);
    }
  }

  void _publishEntitlement(bool isPro) {
    if (_isDisposed || _lastKnownIsPro == isPro) return;
    _lastKnownIsPro = isPro;
    _entitlementController.add(isPro);
  }

  static Future<bool> isProUser() async {
    final preferences = await SharedPreferences.getInstance();
    final savedEntitlement = preferences.get(_proKey);
    if (savedEntitlement is bool) return savedEntitlement;
    if (savedEntitlement != null) {
      await preferences.remove(_proKey);
    }
    return false;
  }

  /// Reloads the persisted entitlement and publishes it to active listeners.
  Future<bool> refreshEntitlement() async {
    final isPro = await isProUser();
    _publishEntitlement(isPro);
    return isPro;
  }

  Future<String?> proPrice() async {
    if (_isDisposed) return null;
    final product = await _loadProProduct();
    return product?.price;
  }

  Future<void> buyPro() async {
    if (_isDisposed) {
      throw StateError('FocusHaven Pro purchasing is no longer available.');
    }

    final product = await _loadProProduct();
    if (product == null) {
      throw StateError('FocusHaven Pro is not available.');
    }
    final started = await _store.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
    if (!started) {
      throw StateError('The FocusHaven Pro purchase could not be started.');
    }
  }

  Future<void> restorePurchases() async {
    if (_isDisposed) return;
    await _store.restorePurchases();
  }

  Future<ProductDetails?> _loadProProduct() async {
    final response = await _store.queryProductDetails({proProductId});
    final error = response.error;
    if (error != null) {
      throw StateError(
        'The store could not load FocusHaven Pro: ${error.message}',
      );
    }

    for (final product in response.productDetails) {
      if (product.id == proProductId) return product;
    }
    return null;
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    unawaited(_entitlementController.close());
  }
}
