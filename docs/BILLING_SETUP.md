# Billing setup (do once, when you have the accounts)

The app already contains the RevenueCat integration (`lib/billing/revenuecat_billing.dart`). It turns on
when the build gets a RevenueCat key; nothing else in the code changes.

| Build | Billing |
|---|---|
| `--dart-define=REVENUECAT_KEY=goog_…` | Real Google Play subscriptions via RevenueCat |
| `--dart-define=DEV_BILLING=true` | Developer tier switch, no payment (for testing tiers) |
| neither | Free only; "Plans aren't available in this build" |

**Never upload a build with `DEV_BILLING=true` to Play**: it lets anyone pick Pro for free.

## 1. Google Play Console (developer account, one-time $25)

1. Create the app with package name **`io.github.partorg.myfoodmind`**.
2. Upload a signed App Bundle to **Internal testing** (billing only works for apps that exist in Play).
   - Release signing: create an upload key; `android/app/build.gradle.kts` still signs release with the
     debug key and must be changed before this step (M7).
3. **Monetize → Subscriptions**: create three subscriptions, each with two auto-renewing base plans:

   | Subscription id | Base plan ids | Note |
   |---|---|---|
   | `basic` | `monthly`, `yearly` | |
   | `medium` | `monthly`, `yearly` | |
   | `pro` | `monthly`, `yearly` | add a **free trial offer, 7 days, new customers only**, on both base plans |

   Prices are set here (the app shows whatever the store returns). Plan: yearly ≈ 40% below 12× monthly.
4. **Setup → License testing**: add your Google account as a license tester (test purchases are free and
   renew every few minutes).
5. Create a **service account** with financial-data access and download its JSON key (for RevenueCat).

## 2. RevenueCat (free under $2.5k/month revenue)

1. New project → add an **Android app** with package `io.github.partorg.myfoodmind`; upload the service
   account JSON from step 1.5.
2. **Products**: import the six Play products (`basic:monthly`, `basic:yearly`, `medium:…`, `pro:…`).
3. **Entitlements** (ids exactly): `basic`, `medium`, `pro`. Attach cumulatively, so a higher tier also
   carries the lower ones (`basic ⊂ medium ⊂ pro`):
   - `basic` ← all six products
   - `medium` ← medium and pro products
   - `pro` ← pro products
4. **Offerings**: make the `default` offering current, with six packages whose **identifiers are exactly**
   `basic_monthly`, `basic_yearly`, `medium_monthly`, `medium_yearly`, `pro_monthly`, `pro_yearly`
   (custom package identifiers; the app parses `<tier>_<period>`).
5. Copy the **public Android SDK key** (`goog_…`). It is meant to ship inside the app.

## 3. Test (M4 "done when": sandbox buy / upgrade / restore)

```
flutter build appbundle --release --dart-define=REVENUECAT_KEY=goog_…
```
Upload to Internal testing, install from the Play test link on the phone, then:

- [ ] Free → Basic monthly: purchase sheet shows the price; Week/Month unlock; chat has no daily limit.
- [ ] Basic → Pro yearly: one subscription remains (Play → Payments & subscriptions), unused time credited.
- [ ] Pro → Medium: takes effect at the next renewal (deferred), not immediately.
- [ ] Pro trial: "7 days free, then …" shown; a tester account gets the trial once.
- [ ] Uninstall/reinstall → Me → Plans → **Restore purchases** → tier comes back.
- [ ] Cancel in Play → tier drops to Free after expiry.
