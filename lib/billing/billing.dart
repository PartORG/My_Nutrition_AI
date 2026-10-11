import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';

/// Ordered: a higher tier includes everything below it (basic ⊂ medium ⊂ pro).
enum Tier {
  free,
  basic,
  medium,
  pro;

  bool includes(Tier other) => index >= other.index;

  /// How far back History reaches, today included. Older logs stay on the phone, only
  /// hidden, so a downgrade loses nothing and an upgrade shows them again.
  int get historyDays => const [30, 90, 240, 365][index];
}

/// One purchasable plan. [id] is the store package id (see docs/BILLING_SETUP.md).
typedef Offer = ({String id, Tier tier, bool yearly, String price, bool trial});

/// Package ids follow `<tier>_<monthly|yearly>`, e.g. `pro_yearly`.
({Tier tier, bool yearly})? parseOfferId(String id) {
  final m = RegExp(r'^(basic|medium|pro)_(monthly|yearly)$').firstMatch(id);
  return m == null ? null : (tier: Tier.values.byName(m[1]!), yearly: m[2] == 'yearly');
}

/// Subscriptions are per phone (one Google account), shared by all profiles.
abstract interface class Billing {
  /// Current tier; screens listen to it, gates read it.
  ValueListenable<Tier> get tier;

  /// No real payments (developer tier switch).
  bool get isDev;

  Future<void> init();
  Future<List<Offer>> offers();

  /// True when the purchase went through (false: cancelled by the user).
  Future<bool> buy(Offer offer);
  Future<void> restore();
}

/// Stand-in until the store and RevenueCat accounts exist: "buying" switches
/// the tier, kept in profiles.db so it survives restarts.
class DevBilling implements Billing {
  DevBilling(this._db);
  final Database _db;
  final _tier = ValueNotifier(Tier.free);

  @override
  ValueListenable<Tier> get tier => _tier;
  @override
  bool get isDev => true;

  @override
  Future<void> init() async {
    final v = _db.select("SELECT value FROM settings WHERE key = 'dev_tier'").firstOrNull?['value'];
    _tier.value = v == null ? Tier.free : Tier.values.byName(v as String);
  }

  /// Sample prices so the paywall looks real; the store sets the real ones.
  static const _prices = {
    Tier.basic: ('€3.99', '€29.99'),
    Tier.medium: ('€6.99', '€49.99'),
    Tier.pro: ('€9.99', '€69.99'),
  };

  @override
  Future<List<Offer>> offers() async => [
        for (final e in _prices.entries)
          for (final yearly in [false, true])
            (
              id: '${e.key.name}_${yearly ? 'yearly' : 'monthly'}',
              tier: e.key,
              yearly: yearly,
              price: yearly ? e.value.$2 : e.value.$1,
              trial: e.key == Tier.pro,
            )
      ];

  @override
  Future<bool> buy(Offer offer) async {
    setTier(offer.tier);
    return true;
  }

  /// Developer-only: also allows going back to Free.
  void setTier(Tier t) {
    _db.execute("INSERT OR REPLACE INTO settings (key, value) VALUES ('dev_tier', ?)", [t.name]);
    _tier.value = t;
  }

  @override
  Future<void> restore() async {}
}

/// A build with neither REVENUECAT_KEY nor DEV_BILLING: Free only. Never let a
/// build without a store fall back to the dev switch (anyone could pick Pro).
class UnavailableBilling implements Billing {
  @override
  final ValueListenable<Tier> tier = ValueNotifier(Tier.free);
  @override
  bool get isDev => false;
  @override
  Future<void> init() async {}
  @override
  Future<List<Offer>> offers() async => const [];
  @override
  Future<bool> buy(Offer offer) async => false;
  @override
  Future<void> restore() async {}
}
