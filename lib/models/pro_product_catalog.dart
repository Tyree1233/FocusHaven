import 'pro_entitlement.dart';

final class ProStoreProduct {
  const ProStoreProduct({
    required this.id,
    required this.plan,
    required this.requiresServerVerification,
  });

  final String id;
  final ProPlan plan;
  final bool requiresServerVerification;

  bool get isSubscription => plan == ProPlan.monthly || plan == ProPlan.annual;

  bool get grantsLocalLifetimeAccess =>
      plan == ProPlan.grandfatheredLifetime && !requiresServerVerification;
}

abstract final class ProProductCatalog {
  static const legacyLifetimeProductId = 'focushaven_pro';
  static const monthlyProductId = 'focushaven_pro_monthly';
  static const annualProductId = 'focushaven_pro_annual';

  static const legacyLifetime = ProStoreProduct(
    id: legacyLifetimeProductId,
    plan: ProPlan.grandfatheredLifetime,
    requiresServerVerification: false,
  );

  static const monthly = ProStoreProduct(
    id: monthlyProductId,
    plan: ProPlan.monthly,
    requiresServerVerification: true,
  );

  static const annual = ProStoreProduct(
    id: annualProductId,
    plan: ProPlan.annual,
    requiresServerVerification: true,
  );

  static const products = <String, ProStoreProduct>{
    legacyLifetimeProductId: legacyLifetime,
    monthlyProductId: monthly,
    annualProductId: annual,
  };

  static const subscriptionProductIds = <String>{
    monthlyProductId,
    annualProductId,
  };

  static ProStoreProduct? productFor(String productId) => products[productId];

  static bool grantsLocalLifetimeAccess(String productId) =>
      productFor(productId)?.grantsLocalLifetimeAccess ?? false;

  const ProProductCatalog._();
}
