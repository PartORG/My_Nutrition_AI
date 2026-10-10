import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_state.dart';
import '../billing/billing.dart';
import '../l10n/app_localizations.dart';
import 'nutrients.dart';
import 'theme.dart';

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
    final billing = ref.watch(billingProvider).value;
    if (billing == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    _offers ??= billing.offers();
    final features = {
      Tier.basic: [l.featBasic1, l.featBasic2, l.featBasic3],
      Tier.medium: [l.featMedium1, l.featMedium2, l.featMedium3],
      Tier.pro: [l.featPro1, l.featPro2, l.featPro3],
    };
    return Scaffold(
      appBar: AppBar(title: Text(l.plansTitle)),
      body: ValueListenableBuilder(
        valueListenable: billing.tier,
        builder: (context, current, _) => FutureBuilder(
          future: _offers,
          builder: (context, snap) {
            final offers = snap.data ?? const <Offer>[];
            return ListView(padding: const EdgeInsets.all(16), children: [
              if (billing.isDev)
                Card(
                  color: context.colors.cardGreen,
                  child: Padding(padding: const EdgeInsets.all(12), child: Text(l.devBillingBanner)),
                ),
              Center(
                child: SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text(l.monthly)),
                    ButtonSegment(value: true, label: Text(l.yearly)),
                  ],
                  selected: {_yearly},
                  onSelectionChanged: (s) => setState(() => _yearly = s.single),
                ),
              ),
              const SizedBox(height: 8),
              for (final tier in [Tier.basic, Tier.medium, Tier.pro])
                if (offers.where((o) => o.tier == tier && o.yearly == _yearly).firstOrNull case final offer?)
                  _TierCard(
                    tier: tier,
                    offer: offer,
                    features: features[tier]!,
                    current: current == tier,
                    action: current == tier
                        ? null
                        : current == Tier.free
                            ? l.subscribe
                            : tier.index > current.index
                                ? l.upgrade
                                : l.switchPlan,
                    onBuy: _busy ? null : () => _buy(billing, offer),
                  ),
              if (snap.connectionState == ConnectionState.waiting)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
              else if (offers.isEmpty)
                Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(l.plansUnavailable))),
              const SizedBox(height: 8),
              Text(l.subscriptionTerms, style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
              TextButton(onPressed: _busy ? null : billing.restore, child: Text(l.restorePurchases)),
              legalLinks(context),
              if (billing case DevBilling dev when current != Tier.free)
                TextButton(onPressed: () => dev.setTier(Tier.free), child: Text(l.devBackToFree)),
            ]);
          },
        ),
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
    required this.action,
    required this.onBuy,
  });
  final Tier tier;
  final Offer offer;
  final List<String> features;
  final bool current;
  final String? action;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final price = offer.yearly ? l.perYear(offer.price) : l.perMonth(offer.price);
    return Card(
      shape: current
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16), side: BorderSide(color: context.colors.primary, width: 2))
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(tierName(tier, l), style: Theme.of(context).textTheme.titleLarge),
            if (current) Chip(label: Text(l.currentPlan), visualDensity: VisualDensity.compact),
          ]),
          const SizedBox(height: 6),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Icon(Icons.check_circle, size: 18, color: context.colors.primaryLight),
                const SizedBox(width: 8),
                Expanded(child: Text(f)),
              ]),
            ),
          const SizedBox(height: 10),
          // The full price is always next to the button, with the trial spelled out.
          Text(offer.trial && !current ? l.trialThen(price) : price,
              style: TextStyle(fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
          if (action != null) ...[
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: onBuy, child: Text(action!))),
          ],
        ]),
      ),
    );
  }
}
