import 'dart:async';
import 'dart:convert';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pro_entitlement.dart';
import '../models/pro_product_catalog.dart';

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
  static const _legacyProKey = 'isProUser';
  static const _entitlementKey = 'proEntitlementV1';
  static const proProductId = ProProductCatalog.legacyLifetimeProductId;

  final IAPStoreBackend _store;
  final StreamController<ProEntitlement> _entitlementController =
      StreamController<ProEntitlement>.broadcast();
  final bool legacyLifetimePurchasesEnabled;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProEntitlement? _lastKnownEntitlement;
  bool _isDisposed = false;

  IAPService({
    InAppPurchase? inAppPurchase,
    IAPStoreBackend? storeBackend,
    this.legacyLifetimePurchasesEnabled = true,
  }) : assert(
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
  Stream<ProEntitlement> get proEntitlementChanges =>
      _entitlementController.stream;

  /// Compatibility stream for existing views that only need active access.
  Stream<bool> get entitlementChanges => proEntitlementChanges.map(
    (entitlement) => entitlement.isActiveAt(DateTime.now()),
  );

  /// The most recently loaded entitlement, or `null` until storage is read.
  ProEntitlement? get lastKnownEntitlement => _lastKnownEntitlement;

  /// Compatibility value for existing views that only need active access.
  bool? get lastKnownIsPro => _lastKnownEntitlement?.isActiveAt(DateTime.now());

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
            ProProductCatalog.grantsLocalLifetimeAccess(purchase.productID) &&
            (purchase.status == PurchaseStatus.purchased ||
                purchase.status == PurchaseStatus.restored);
        if (grantsPro) {
          const entitlement = ProEntitlement.grandfatheredLifetime();
          await _persistEntitlement(entitlement);
          _publishEntitlement(entitlement);
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

  void _publishEntitlement(ProEntitlement entitlement) {
    if (_isDisposed || _lastKnownEntitlement == entitlement) return;
    _lastKnownEntitlement = entitlement;
    _entitlementController.add(entitlement);
  }

  /// Loads the local access record.
  ///
  /// Shared preferences are not trusted to prove a paid server entitlement.
  /// Only free and grandfathered lifetime access can be restored here. Future
  /// subscription verification must arrive from a trusted server response.
  static Future<ProEntitlement> loadEntitlement() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.get(_entitlementKey);
    if (saved is String) {
      try {
        final decoded = jsonDecode(saved);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Invalid Pro entitlement record.');
        }
        final entitlement = ProEntitlement.fromJson(decoded);
        if (entitlement.verification == ProVerification.server) {
          throw const FormatException(
            'Server grants cannot be restored from local storage.',
          );
        }
        await preferences.remove(_legacyProKey);
        return entitlement;
      } on FormatException {
        await preferences.remove(_entitlementKey);
      }
    } else if (saved != null) {
      await preferences.remove(_entitlementKey);
    }

    final legacy = preferences.get(_legacyProKey);
    await preferences.remove(_legacyProKey);
    if (legacy == true) {
      const entitlement = ProEntitlement.grandfatheredLifetime();
      await _persistEntitlement(entitlement, preferences: preferences);
      return entitlement;
    }
    return const ProEntitlement.free();
  }

  static Future<bool> isProUser() async {
    final entitlement = await loadEntitlement();
    return entitlement.isActiveAt(DateTime.now());
  }

  static Future<void> _persistEntitlement(
    ProEntitlement entitlement, {
    SharedPreferences? preferences,
  }) async {
    final storage = preferences ?? await SharedPreferences.getInstance();
    await storage.setString(_entitlementKey, jsonEncode(entitlement.toJson()));
    await storage.remove(_legacyProKey);
  }

  /// Reloads and publishes the complete local entitlement record.
  Future<ProEntitlement> refreshProEntitlement() async {
    final entitlement = await loadEntitlement();
    _publishEntitlement(entitlement);
    return entitlement;
  }

  /// Reloads the persisted entitlement and publishes it to active listeners.
  Future<bool> refreshEntitlement() async {
    final entitlement = await refreshProEntitlement();
    return entitlement.isActiveAt(DateTime.now());
  }

  Future<String?> proPrice() async {
    if (_isDisposed || !legacyLifetimePurchasesEnabled) return null;
    final product = await _loadProProduct();
    return product?.price;
  }

  Future<void> buyPro() async {
    if (_isDisposed) {
      throw StateError('FocusHaven Pro purchasing is no longer available.');
    }
    if (!legacyLifetimePurchasesEnabled) {
      throw StateError('New lifetime purchases are no longer available.');
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
