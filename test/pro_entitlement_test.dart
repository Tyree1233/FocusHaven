import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/models/pro_entitlement.dart';

void main() {
  final now = DateTime.utc(2026, 8, 15, 12);

  test('free access never grants Pro or paid services', () {
    const entitlement = ProEntitlement.free();

    expect(entitlement.isActiveAt(now), isFalse);
    expect(entitlement.allowsPaidServicesAt(now), isFalse);
    expect(entitlement.plan, ProPlan.free);
    expect(entitlement.verification, ProVerification.none);
  });

  test('grandfathered lifetime access remains local-only', () {
    const entitlement = ProEntitlement.grandfatheredLifetime();

    expect(entitlement.isActiveAt(now), isTrue);
    expect(entitlement.allowsPaidServicesAt(now), isFalse);
    expect(entitlement.plan, ProPlan.grandfatheredLifetime);
    expect(entitlement.verification, ProVerification.legacyLocal);
  });

  test('verified subscriptions expire at their exact boundary', () {
    final expiration = now.add(const Duration(days: 30));
    final entitlement = ProEntitlement.serverVerified(
      plan: ProPlan.monthly,
      verifiedAt: now,
      expiresAt: expiration,
    );

    expect(
      entitlement.isActiveAt(expiration.subtract(const Duration(seconds: 1))),
      isTrue,
    );
    expect(entitlement.allowsPaidServicesAt(expiration), isFalse);
    expect(
      entitlement.isActiveAt(expiration.add(const Duration(seconds: 1))),
      isFalse,
    );
  });

  test('verified annual access permits paid services before expiration', () {
    final entitlement = ProEntitlement.serverVerified(
      plan: ProPlan.annual,
      verifiedAt: now,
      expiresAt: now.add(const Duration(days: 365)),
    );

    expect(entitlement.isActiveAt(now), isTrue);
    expect(entitlement.allowsPaidServicesAt(now), isTrue);
  });

  test('verified lifetime access can authorize paid services', () {
    final entitlement = ProEntitlement.serverVerified(
      plan: ProPlan.grandfatheredLifetime,
      verifiedAt: now,
    );

    expect(entitlement.isActiveAt(now), isTrue);
    expect(entitlement.allowsPaidServicesAt(now), isTrue);
    expect(entitlement.expiresAt, isNull);
  });

  test('subscription and lifetime constructors reject invalid dates', () {
    expect(
      () =>
          ProEntitlement.serverVerified(plan: ProPlan.monthly, verifiedAt: now),
      throwsArgumentError,
    );
    expect(
      () => ProEntitlement.serverVerified(
        plan: ProPlan.grandfatheredLifetime,
        verifiedAt: now,
        expiresAt: now.add(const Duration(days: 1)),
      ),
      throwsArgumentError,
    );
    expect(
      () => ProEntitlement.serverVerified(plan: ProPlan.free, verifiedAt: now),
      throwsArgumentError,
    );
  });

  test('serialized verified entitlements round trip in UTC', () {
    final entitlement = ProEntitlement.serverVerified(
      plan: ProPlan.annual,
      verifiedAt: DateTime.parse('2026-08-15T07:00:00-05:00'),
      expiresAt: DateTime.parse('2027-08-15T07:00:00-05:00'),
    );

    final restored = ProEntitlement.fromJson(entitlement.toJson());

    expect(restored, entitlement);
    expect(restored.verifiedAt, DateTime.utc(2026, 8, 15, 12));
    expect(restored.expiresAt, DateTime.utc(2027, 8, 15, 12));
  });

  test('free and grandfathered entitlements round trip', () {
    expect(
      ProEntitlement.fromJson(const ProEntitlement.free().toJson()),
      const ProEntitlement.free(),
    );
    expect(
      ProEntitlement.fromJson(
        const ProEntitlement.grandfatheredLifetime().toJson(),
      ),
      const ProEntitlement.grandfatheredLifetime(),
    );
  });

  test('damaged or unsafe serialized grants are rejected', () {
    for (final value in <Map<String, Object?>>[
      {},
      {'version': 2, 'plan': 'free', 'verification': 'none'},
      {'version': 1, 'plan': 'unknown', 'verification': 'none'},
      {
        'version': 1,
        'plan': 'monthly',
        'verification': 'legacyLocal',
        'expiresAt': '2026-09-15T12:00:00Z',
      },
      {'version': 1, 'plan': 'monthly', 'verification': 'server'},
      {
        'version': 1,
        'plan': 'grandfatheredLifetime',
        'verification': 'server',
        'verifiedAt': 'not-a-date',
      },
      {
        'version': 1,
        'plan': 'free',
        'verification': 'none',
        'verifiedAt': '2026-08-15T12:00:00Z',
      },
    ]) {
      expect(() => ProEntitlement.fromJson(value), throwsFormatException);
    }
  });
}
