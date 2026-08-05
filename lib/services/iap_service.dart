import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IAPService {
  static const _proKey = 'isProUser';
  static const proProductId = 'focushaven_pro';
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  IAPService() {
    _initialize();
  }

  Future<void> _initialize() async {
    if (!await _iap.isAvailable()) return;
    _subscription = _iap.purchaseStream.listen((purchases) async {
      for (final purchase in purchases) {
        if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_proKey, true);
        }
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    });
  }

  static Future<bool> isProUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_proKey) ?? false;
  }

  Future<String?> proPrice() async {
    final response = await _iap.queryProductDetails({proProductId});
    if (response.productDetails.isEmpty) return null;
    return response.productDetails.first.price;
  }

  Future<void> buyPro() async {
    final response = await _iap.queryProductDetails({proProductId});
    if (response.productDetails.isEmpty) throw StateError('FocusHaven Pro is not available.');
    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: response.productDetails.first),
    );
  }

  Future<void> restorePurchases() => _iap.restorePurchases();

  void dispose() => _subscription?.cancel();
}
