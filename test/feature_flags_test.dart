import 'package:flutter_test/flutter_test.dart';

import 'package:focushaven/config/feature_flags.dart';

void main() {
  test('remote coaching stays hidden in ordinary builds', () {
    expect(FeatureFlags.remoteCoachingEnabled, isFalse);
  });

  test('legacy lifetime checkout stays hidden in ordinary builds', () {
    expect(FeatureFlags.legacyLifetimePurchasesEnabled, isFalse);
  });
}
