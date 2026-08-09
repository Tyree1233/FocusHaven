import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IAPService {
  static const _proKey = 'isProUser';
  static const proProductId = 'focushaven_pro';

  final InAppPurchase _iap;
  final StreamController<bool> _entitlementController =
      StreamController<bool>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool? _lastKnownIsPro;
  bool _isDisposed = false;

  IAPService({InAppPurchase? inAppPurchase})
    : _iap = inAppPurchase ?? InAppPurchase.instance {
    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: _handlePurchaseError,
    );
    unawaited(_loadInitialEntitlement());
  }

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
    unawaited(_processPurchaseUpdates(purchases));
  }

  Future<void> _processPurchaseUpdates(List<PurchaseDetails> purchases) async {
    try {
      for (final purchase in purchases) {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_proKey, true);
          _publishEntitlement(true);
        }
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
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
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_proKey) ?? false;
  }

  /// Reloads the persisted entitlement and publishes it to active listeners.
  Future<bool> refreshEntitlement() async {
    final isPro = await isProUser();
    _publishEntitlement(isPro);
    return isPro;
  }

  Future<String?> proPrice() async {
    final response = await _iap.queryProductDetails({proProductId});
    if (response.productDetails.isEmpty) return null;
    return response.productDetails.first.price;
  }

  Future<void> buyPro() async {
    final response = await _iap.queryProductDetails({proProductId});
    if (response.productDetails.isEmpty) {
      throw StateError('FocusHaven Pro is not available.');
    }
    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: response.productDetails.first,
      ),
    );
  }

  Future<void> restorePurchases() => _iap.restorePurchases();

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
