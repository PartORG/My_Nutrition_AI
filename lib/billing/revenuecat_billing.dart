import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'billing.dart';

/// Real subscriptions via RevenueCat (anonymous user: no login, per phone).
/// Entitlements `basic`, `medium`, `pro`; packages `<tier>_<monthly|yearly>`.
/// Setup: docs/BILLING_SETUP.md. Not exercised until the accounts exist.
class RevenueCatBilling implements Billing {
  RevenueCatBilling(this._apiKey);
  final String _apiKey;
  final _tier = ValueNotifier(Tier.free);
  final _packages = <String, Package>{};
  List<String> _activeProducts = const [];

  @override
  ValueListenable<Tier> get tier => _tier;
  @override
  bool get isDev => false;

  @override
  Future<void> init() async {
    await Purchases.configure(PurchasesConfiguration(_apiKey));
    Purchases.addCustomerInfoUpdateListener(_apply);
    _apply(await Purchases.getCustomerInfo());
  }

  void _apply(CustomerInfo info) {
    final active = info.entitlements.active.keys.toSet();
    _activeProducts = info.activeSubscriptions;
    _tier.value = Tier.values.lastWhere((t) => t == Tier.free || active.contains(t.name));
  }

  @override
  Future<List<Offer>> offers() async {
    final current = (await Purchases.getOfferings()).current;
    final offers = <Offer>[];
    for (final p in current?.availablePackages ?? <Package>[]) {
      final parsed = parseOfferId(p.identifier);
      if (parsed == null) continue;
      _packages[p.identifier] = p;
      offers.add((
        id: p.identifier,
        tier: parsed.tier,
        yearly: parsed.yearly,
        price: p.storeProduct.priceString,
        trial: p.storeProduct.introductoryPrice?.price == 0,
      ));
    }
    return offers;
  }

  @override
  Future<bool> buy(Offer offer) async {
    final package = _packages[offer.id]!;
    // Changing plans replaces the old subscription instead of adding a second
    // one: upgrades now with the unused time credited, downgrades at renewal.
    // On Play a monthly→yearly switch of the same tier is a replacement too
    // (another base plan); buying the plan you already have is a no-op.
    final old = _activeProducts.firstOrNull;
    if (old == package.storeProduct.identifier) return true;
    final change = old == null
        ? null
        : StoreProductChangeInfo(
            old,
            replacementMode: offer.tier.index < _tier.value.index
                ? StoreReplacementMode.deferred
                : StoreReplacementMode.withTimeProration,
          );
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package, productChangeInfo: change));
      _apply(result.customerInfo);
      return true;
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) == PurchasesErrorCode.purchaseCancelledError) return false;
      rethrow;
    }
  }

  @override
  Future<void> restore() async => _apply(await Purchases.restorePurchases());
}
