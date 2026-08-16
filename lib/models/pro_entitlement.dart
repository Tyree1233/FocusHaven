enum ProPlan { free, monthly, annual, grandfatheredLifetime }

enum ProVerification { none, legacyLocal, server }

final class ProEntitlement {
  const ProEntitlement._({
    required this.plan,
    required this.verification,
    this.expiresAt,
    this.verifiedAt,
  });

  const ProEntitlement.free()
    : this._(plan: ProPlan.free, verification: ProVerification.none);

  const ProEntitlement.grandfatheredLifetime()
    : this._(
        plan: ProPlan.grandfatheredLifetime,
        verification: ProVerification.legacyLocal,
      );

  factory ProEntitlement.serverVerified({
    required ProPlan plan,
    required DateTime verifiedAt,
    DateTime? expiresAt,
  }) {
    if (plan == ProPlan.free) {
      throw ArgumentError.value(
        plan,
        'plan',
        'A verified plan must grant Pro.',
      );
    }
    final subscription = plan == ProPlan.monthly || plan == ProPlan.annual;
    if (subscription && expiresAt == null) {
      throw ArgumentError.value(
        expiresAt,
        'expiresAt',
        'A subscription must include an expiration.',
      );
    }
    if (!subscription && expiresAt != null) {
      throw ArgumentError.value(
        expiresAt,
        'expiresAt',
        'A lifetime entitlement cannot expire.',
      );
    }
    return ProEntitlement._(
      plan: plan,
      verification: ProVerification.server,
      expiresAt: expiresAt?.toUtc(),
      verifiedAt: verifiedAt.toUtc(),
    );
  }

  factory ProEntitlement.fromJson(Map<String, Object?> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported Pro entitlement version.');
    }
    final plan = ProPlan.values.where((value) => value.name == json['plan']);
    final verification = ProVerification.values.where(
      (value) => value.name == json['verification'],
    );
    if (plan.length != 1 || verification.length != 1) {
      throw const FormatException('Invalid Pro entitlement values.');
    }

    final expiresAt = _optionalUtcDate(json['expiresAt']);
    final verifiedAt = _optionalUtcDate(json['verifiedAt']);
    final parsedPlan = plan.single;
    final parsedVerification = verification.single;

    switch ((parsedPlan, parsedVerification)) {
      case (ProPlan.free, ProVerification.none):
        if (expiresAt != null || verifiedAt != null) {
          throw const FormatException(
            'Free access cannot contain grant dates.',
          );
        }
        return const ProEntitlement.free();
      case (ProPlan.grandfatheredLifetime, ProVerification.legacyLocal):
        if (expiresAt != null || verifiedAt != null) {
          throw const FormatException(
            'A legacy lifetime entitlement cannot contain grant dates.',
          );
        }
        return const ProEntitlement.grandfatheredLifetime();
      case (_, ProVerification.server):
        if (verifiedAt == null) {
          throw const FormatException(
            'A server entitlement must include its verification time.',
          );
        }
        try {
          return ProEntitlement.serverVerified(
            plan: parsedPlan,
            verifiedAt: verifiedAt,
            expiresAt: expiresAt,
          );
        } on ArgumentError catch (error) {
          throw FormatException(error.message?.toString() ?? 'Invalid grant.');
        }
      default:
        throw const FormatException('Invalid Pro entitlement combination.');
    }
  }

  final ProPlan plan;
  final ProVerification verification;
  final DateTime? expiresAt;
  final DateTime? verifiedAt;

  bool isActiveAt(DateTime time) {
    if (plan == ProPlan.free) return false;
    if (plan == ProPlan.grandfatheredLifetime) return true;
    final expiration = expiresAt;
    return expiration != null && expiration.isAfter(time.toUtc());
  }

  bool allowsPaidServicesAt(DateTime time) =>
      verification == ProVerification.server && isActiveAt(time);

  Map<String, Object?> toJson() => {
    'version': 1,
    'plan': plan.name,
    'verification': verification.name,
    if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
    if (verifiedAt != null) 'verifiedAt': verifiedAt!.toIso8601String(),
  };

  static DateTime? _optionalUtcDate(Object? value) {
    if (value == null) return null;
    if (value is! String) {
      throw const FormatException('Invalid Pro entitlement date.');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw const FormatException('Invalid Pro entitlement date.');
    }
    return parsed.toUtc();
  }

  @override
  bool operator ==(Object other) =>
      other is ProEntitlement &&
      other.plan == plan &&
      other.verification == verification &&
      other.expiresAt == expiresAt &&
      other.verifiedAt == verifiedAt;

  @override
  int get hashCode => Object.hash(plan, verification, expiresAt, verifiedAt);
}
