import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_state.dart';
import '../billing/billing.dart';
import '../l10n/app_localizations.dart';
import 'nutrients.dart';
import 'kit.dart';
import 'theme.dart';

/// Rebuilds with the current tier; shows nothing while billing loads.
class TierBuilder extends ConsumerWidget {
  const TierBuilder({super.key, required this.builder});
  final Widget Function(BuildContext context, Tier tier) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billing = ref.watch(billingProvider).value;
    if (billing == null) return const SizedBox.shrink();
    return ValueListenableBuilder(valueListenable: billing.tier, builder: (context, tier, _) => builder(context, tier));
  }
}

/// A paid feature the user doesn't have yet: what it is, and a way to the plans.
class LockedCard extends StatelessWidget {
  const LockedCard({super.key, required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title, body;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Panel(
      color: context.colors.mint,
      border: false,
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: context.colors.primary, size: 32),
        const SizedBox(height: 10),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(body, style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PaywallScreen())),
          child: Text(l.seePlans),
        ),
      ]),
    );
  }
}

String tierName(Tier t, AppLocalizations l) =>
    {Tier.free: l.tierFree, Tier.basic: l.tierBasic, Tier.medium: l.tierMedium, Tier.pro: l.tierPro}[t]!;

/// Basic · Medium · Pro, monthly or yearly. Price and renewal terms are always
/// visible next to the button (Play policy).
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  var _yearly = true;
  Tier? _pick; // null = the default: Pro (the trial) unless that's the current tier
  Future<List<Offer>>? _offers;
  bool _busy = false;

  Future<void> _buy(Billing billing, Offer offer) async {
    final l = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      if (await billing.buy(offer) && mounted) Navigator.of(context).pop();
    } on Object {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.purchaseFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final billing = ref.watch(billingProvider).value;
    if (billing == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    _offers ??= billing.offers();
    final features = {
      Tier.basic: [l.featBasic1, l.featBasic2, l.featBasic3, l.featBasic4],
      Tier.medium: [l.featMedium1, l.featMedium2, l.featMedium3, l.featMedium4],
      Tier.pro: [l.featPro1, l.featPro2, l.featPro3, l.featPro4],
    };
    return ValueListenableBuilder(
      valueListenable: billing.tier,
      builder: (context, current, _) => FutureBuilder(
        future: _offers,
        builder: (context, snap) {
          final offers = snap.data ?? const <Offer>[];
          Offer? offerFor(Tier t) => offers.where((o) => o.tier == t && o.yearly == _yearly).firstOrNull;
          final pick = _pick ?? (current == Tier.pro ? null : Tier.pro);
          final chosen = pick == null || pick == current ? null : offerFor(pick);
          final price = chosen == null ? null : (chosen.yearly ? l.perYear(chosen.price) : l.perMonth(chosen.price));
          final action = chosen == null
              ? null
              : chosen.trial && current == Tier.free
                  ? l.startTrial
                  : current == Tier.free
                      ? l.subscribe
                      : chosen.tier.index > current.index
                          ? l.upgrade
                          : l.switchPlan;
          return Scaffold(
            body: SafeArea(
              child: ListView(padding: const EdgeInsets.only(bottom: 16), children: [
                ScreenHeader(
                  title: l.plansTitle,
                  back: true,
                  trailing: Text(l.currentTier(tierName(current, l)), style: TextStyle(fontSize: 15, color: c.muted)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (billing.isDev)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Panel(color: c.mint, border: false, child: Text(l.devBillingBanner)),
                      ),
                    PillTabs<bool>(
                      values: const [false, true],
                      selected: _yearly,
                      label: (y) => y ? l.yearly : l.monthly,
                      onChanged: (y) => setState(() => _yearly = y),
                    ),
                    const SizedBox(height: 14),
                    for (final tier in [Tier.basic, Tier.medium, Tier.pro])
                      if (offerFor(tier) case final offer?)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TierCard(
                            tier: tier,
                            offer: offer,
                            features: features[tier]!,
                            current: current == tier,
                            selected: pick == tier,
                            onTap: current == tier ? null : () => setState(() => _pick = tier),
                          ),
                        ),
                    if (snap.connectionState == ConnectionState.waiting)
                      const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                    else if (offers.isEmpty)
                      Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(l.plansUnavailable))),
                    Text(l.subscriptionTerms, style: TextStyle(color: c.muted, fontSize: 13)),
                    legalLinks(context),
                    if (billing case DevBilling dev when current != Tier.free)
                      TextButton(onPressed: () => dev.setTier(Tier.free), child: Text(l.devBackToFree)),
                  ]),
                ),
              ]),
            ),
            bottomNavigationBar: DecoratedBox(
              decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    // The full price is always next to the button, with the trial spelled out.
                    if (price != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(chosen!.trial && current == Tier.free ? l.trialThen(price) : price,
                            textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, color: c.ink2)),
                      ),
                    if (action != null)
                      FilledButton(onPressed: _busy ? null : () => _buy(billing, chosen!), child: Text(action)),
                    TextButton(onPressed: _busy ? null : billing.restore, child: Text(l.restorePurchases)),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.tier,
    required this.offer,
    required this.features,
    required this.current,
    required this.selected,
    required this.onTap,
  });
  final Tier tier;
  final Offer offer;
  final List<String> features;
  final bool current, selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final pro = tier == Tier.pro;
    final fg = pro ? c.background : c.ink;
    final price = offer.yearly ? l.perYear(offer.price) : l.perMonth(offer.price);
    return Semantics(
      selected: selected,
      button: onTap != null,
      child: Material(
        color: pro ? c.dark : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: selected ? c.primary : (pro ? c.dark : c.border), width: selected ? 2.5 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(tierName(tier, l), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: fg)),
                if (offer.trial && !current) Tag(l.trialBadge, tone: TagTone.gold),
                if (current) Tag(l.currentPlan, tone: TagTone.mint),
              ]),
              const SizedBox(height: 4),
              Text(price, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: fg)),
              const SizedBox(height: 8),
              Text(features.join(' · '), style: TextStyle(fontSize: 15, height: 1.4, color: fg.withValues(alpha: pro ? .85 : 1))),
            ]),
          ),
        ),
      ),
    );
  }
}
