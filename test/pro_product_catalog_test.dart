import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/models/pro_entitlement.dart';
import 'package:focushaven/models/pro_product_catalog.dart';

void main() {
  test('keeps stable store product identifiers', () {
    expect(ProProductCatalog.legacyLifetimeProductId, 'focushaven_pro');
    expect(ProProductCatalog.monthlyProductId, 'focushaven_pro_monthly');
    expect(ProProductCatalog.annualProductId, 'focushaven_pro_annual');
    expect(ProProductCatalog.products.keys, hasLength(3));
  });

  test('classifies monthly and annual products as subscriptions', () {
    final monthly = ProProductCatalog.productFor(
      ProProductCatalog.monthlyProductId,
    );
    final annual = ProProductCatalog.productFor(
      ProProductCatalog.annualProductId,
    );

    expect(monthly?.plan, ProPlan.monthly);
    expect(monthly?.isSubscription, isTrue);
    expect(monthly?.requiresServerVerification, isTrue);
    expect(annual?.plan, ProPlan.annual);
    expect(annual?.isSubscription, isTrue);
    expect(annual?.requiresServerVerification, isTrue);
    expect(ProProductCatalog.subscriptionProductIds, {
      ProProductCatalog.monthlyProductId,
      ProProductCatalog.annualProductId,
    });
  });

  test('only the legacy product can restore local lifetime access', () {
    expect(
      ProProductCatalog.grantsLocalLifetimeAccess(
        ProProductCatalog.legacyLifetimeProductId,
      ),
      isTrue,
    );
    expect(
      ProProductCatalog.grantsLocalLifetimeAccess(
        ProProductCatalog.monthlyProductId,
      ),
      isFalse,
    );
    expect(
      ProProductCatalog.grantsLocalLifetimeAccess(
        ProProductCatalog.annualProductId,
      ),
      isFalse,
    );
  });

  test('unknown store products never grant access', () {
    expect(ProProductCatalog.productFor('unknown_product'), isNull);
    expect(
      ProProductCatalog.grantsLocalLifetimeAccess('unknown_product'),
      isFalse,
    );
  });
}
