import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/providers/app_providers.dart';
import 'package:focushaven/services/iap_service.dart';
import 'package:focushaven/widgets/pro_sheet.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeIapPlatform extends InAppPurchasePlatform {
  _FakeIapPlatform({this.product});

  final ProductDetails? product;
  final _purchases = StreamController<List<PurchaseDetails>>.broadcast();
  Completer<bool>? pendingPurchase;
  Completer<void>? pendingRestore;
  var buyCalls = 0;
  var restoreCalls = 0;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _purchases.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    final availableProduct = product;
    return ProductDetailsResponse(
      productDetails: availableProduct == null ? [] : [availableProduct],
      notFoundIDs: availableProduct == null ? identifiers.toList() : [],
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    buyCalls += 1;
    final pending = pendingPurchase;
    if (pending != null) {
      return pending.future;
    }
    return true;
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreCalls += 1;
    final pending = pendingRestore;
    if (pending != null) {
      await pending.future;
    }
  }

  Future<void> dispose() => _purchases.close();
}

ProductDetails _product() => ProductDetails(
  id: IAPService.proProductId,
  title: 'FocusHaven Pro',
  description: 'Lifetime access',
  price: r'$4.99',
  rawPrice: 4.99,
  currencyCode: 'USD',
  currencySymbol: r'$',
);

Widget _app(IAPService service, {required bool isPro}) {
  return _appWithEntitlement(service, Stream.value(isPro));
}

Widget _appWithEntitlement(IAPService service, Stream<bool> entitlement) {
  return ProviderScope(
    overrides: [
      iapServiceProvider.overrideWithValue(service),
      proEntitlementProvider.overrideWith((ref) => entitlement),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: const Scaffold(body: ProSheet()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  final inAppPurchase = InAppPurchase.instance;
  debugDefaultTargetPlatformOverride = null;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows benefits and safely handles an unavailable product', (
    tester,
  ) async {
    final platform = _FakeIapPlatform();
    InAppPurchasePlatform.instance = platform;
    final service = IAPService(inAppPurchase: inAppPurchase);
    addTearDown(() async {
      service.dispose();
      await platform.dispose();
    });

    await tester.pumpWidget(_app(service, isPro: false));
    await tester.pumpAndSettle();

    expect(find.text('FocusHaven Pro'), findsOneWidget);
    expect(find.text('Secure cloud backup'), findsOneWidget);
    expect(find.text('Restore on another device'), findsOneWidget);
    expect(find.text('One-time lifetime unlock'), findsOneWidget);
    expect(find.text('Pro is not available yet'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);

    final unlockButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Pro is not available yet'),
    );
    expect(unlockButton.onPressed, isNull);

    final restoreAction = find.widgetWithText(TextButton, 'Restore purchases');
    await tester.ensureVisible(restoreAction);
    await tester.pumpAndSettle();
    final restoreButton = tester.widget<TextButton>(restoreAction);
    restoreButton.onPressed!.call();
    await tester.pumpAndSettle();
    expect(platform.restoreCalls, 1);
    expect(
      find.text('Checking the store for previous purchases'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('starts the lifetime purchase when pricing is available', (
    tester,
  ) async {
    final platform = _FakeIapPlatform(product: _product());
    InAppPurchasePlatform.instance = platform;
    final service = IAPService(inAppPurchase: inAppPurchase);
    addTearDown(() async {
      service.dispose();
      await platform.dispose();
    });

    await tester.pumpWidget(_app(service, isPro: false));
    await tester.pumpAndSettle();

    expect(find.text(r'Unlock Pro for $4.99'), findsOneWidget);
    await tester.tap(find.text(r'Unlock Pro for $4.99'));
    await tester.pump();

    expect(platform.buyCalls, 1);
    expect(
      find.text('Complete your purchase in the store window'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocks duplicate purchases and contains store failures', (
    tester,
  ) async {
    final platform = _FakeIapPlatform(product: _product());
    platform.pendingPurchase = Completer<bool>();
    InAppPurchasePlatform.instance = platform;
    final service = IAPService(inAppPurchase: inAppPurchase);
    addTearDown(() async {
      service.dispose();
      await platform.dispose();
    });

    await tester.pumpWidget(_app(service, isPro: false));
    await tester.pumpAndSettle();

    final purchaseAction = find.widgetWithText(
      FilledButton,
      r'Unlock Pro for $4.99',
    );
    final purchaseButton = tester.widget<FilledButton>(purchaseAction);
    purchaseButton.onPressed!.call();
    purchaseButton.onPressed!.call();
    await tester.pump();

    expect(platform.buyCalls, 1);
    expect(tester.widget<FilledButton>(purchaseAction).onPressed, isNull);
    final restoreAction = find.widgetWithText(TextButton, 'Restore purchases');
    expect(tester.widget<TextButton>(restoreAction).onPressed, isNull);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.arrow_back))
          .onPressed,
      isNotNull,
    );

    platform.pendingPurchase!.completeError(Exception('store unavailable'));
    await tester.pumpAndSettle();

    expect(
      find.text('The store could not start this purchase right now'),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(purchaseAction).onPressed, isNotNull);
    expect(tester.widget<TextButton>(restoreAction).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocks duplicate restores and contains store failures', (
    tester,
  ) async {
    final platform = _FakeIapPlatform();
    platform.pendingRestore = Completer<void>();
    InAppPurchasePlatform.instance = platform;
    final service = IAPService(inAppPurchase: inAppPurchase);
    addTearDown(() async {
      service.dispose();
      await platform.dispose();
    });

    await tester.pumpWidget(_app(service, isPro: false));
    await tester.pumpAndSettle();

    final restoreAction = find.widgetWithText(TextButton, 'Restore purchases');
    await tester.ensureVisible(restoreAction);
    await tester.pumpAndSettle();
    final restoreButton = tester.widget<TextButton>(restoreAction);
    restoreButton.onPressed!.call();
    restoreButton.onPressed!.call();
    await tester.pump();

    expect(platform.restoreCalls, 1);
    expect(tester.widget<TextButton>(restoreAction).onPressed, isNull);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.arrow_back))
          .onPressed,
      isNotNull,
    );

    platform.pendingRestore!.completeError(Exception('store unavailable'));
    await tester.pumpAndSettle();

    expect(
      find.text('Previous purchases could not be checked right now'),
      findsOneWidget,
    );
    expect(tester.widget<TextButton>(restoreAction).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps purchase actions hidden while entitlement loads', (
    tester,
  ) async {
    final platform = _FakeIapPlatform(product: _product());
    InAppPurchasePlatform.instance = platform;
    final service = IAPService(inAppPurchase: inAppPurchase);
    final entitlement = StreamController<bool>();
    addTearDown(() async {
      service.dispose();
      await entitlement.close();
      await platform.dispose();
    });

    await tester.pumpWidget(_appWithEntitlement(service, entitlement.stream));
    await tester.pumpAndSettle();

    expect(find.text('Checking Pro status'), findsOneWidget);
    expect(find.text(r'Unlock Pro for $4.99'), findsNothing);
    expect(find.text('Restore purchases'), findsNothing);
    final loadingButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Checking Pro status'),
    );
    expect(loadingButton.onPressed, isNull);
    expect(platform.buyCalls, 0);
    expect(platform.restoreCalls, 0);

    entitlement.add(true);
    await tester.pumpAndSettle();

    expect(find.text('FocusHaven Pro is active'), findsOneWidget);
    expect(find.text('Checking Pro status'), findsNothing);
    expect(find.text('Restore purchases'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows active entitlement without purchase or restore actions', (
    tester,
  ) async {
    final platform = _FakeIapPlatform(product: _product());
    InAppPurchasePlatform.instance = platform;
    final service = IAPService(inAppPurchase: inAppPurchase);
    addTearDown(() async {
      service.dispose();
      await platform.dispose();
    });

    await tester.pumpWidget(_app(service, isPro: true));
    await tester.pumpAndSettle();

    expect(find.text('FocusHaven Pro is active'), findsOneWidget);
    expect(find.text('Restore purchases'), findsNothing);
    final activeButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'FocusHaven Pro is active'),
    );
    expect(activeButton.onPressed, isNull);
    expect(platform.buyCalls, 0);
    expect(platform.restoreCalls, 0);
    expect(tester.takeException(), isNull);
  });
}
