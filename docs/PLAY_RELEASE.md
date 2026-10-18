# Play release runbook (M7)

Billing products and RevenueCat: `docs/BILLING_SETUP.md`. Trademark: `docs/TRADEMARK.md`.

## 1. Upload key (once, on your machine — never commit it)

```sh
mkdir -p ~/keys/myfoodmind
keytool -genkeypair -v -keystore ~/keys/myfoodmind/upload.jks -alias upload \
  -keyalg RSA -keysize 4096 -validity 10000
```

Create `android/key.properties` (git-ignored):

```properties
storeFile=/home/<you>/keys/myfoodmind/upload.jks
storePassword=…
keyAlias=upload
keyPassword=…
```

Back up `upload.jks` and the passwords (password manager + offline copy). Enrol in **Play App Signing**
(default for new apps): Google holds the app key, so a lost upload key can be reset via Play support.
Without `key.properties` release builds fall back to the debug key — fine locally, rejected by Play.

## 2. Build

The two EmbeddingGemma files must be in `assets/models/` (git-ignored, bundled into the app):
`embeddinggemma-300M_seq256.tflite`, `embeddinggemma_sentencepiece.model`.

```sh
flutter build appbundle --release --target-platform android-arm64 \
  --dart-define=REVENUECAT_KEY=goog_…        # omit until RevenueCat exists: Free-only build
```

Bump `version:` in `pubspec.yaml` (`0.1.0+N`, N = versionCode) for every upload.
Never upload a `DEV_BILLING=true` build.

## 3. Internal testing (M7 "done when")

Play Console → create app "My Nutrition AI", default language English, app, free (with in-app purchases).

1. Testing → Internal testing → create release → upload the `.aab` → testers list (your Google account).
2. Fill **App content** (below) — the release can't roll out before it's complete.
3. Open the opt-in link on the phone, install from Play, then check:
   - first start, create profile, log a meal, Today shows it;
   - Chat → Download (Wi-Fi) → progress → chat works; airplane mode → restart → chat still works;
   - camera (Pro via a licence-tester purchase, see BILLING_SETUP);
   - Me → Licenses and AI models, Privacy policy, Terms open.

## 4. Device catalog

Release → Device catalog → **Exclude devices: RAM < 6 GB** (6144 MB rule) — the in-app RAM check stays as
the backstop. ABI: the bundle is arm64-v8a only (32-bit and x86 phones are excluded automatically;
`android/app/build.gradle.kts` strips other ABIs' plugin libraries — check `unzip -l` shows only
`lib/arm64-v8a` after a dependency update).

## 5. App content answers

| Item | Answer |
|---|---|
| Privacy policy | `https://partorg.github.io/My_Nutrition_AI/privacy.html` (not written yet: `site/` and the Pages workflow were removed on 2026-10-18) |
| Ads | No ads |
| App access | All features available without login. For review: Pro needs a subscription → provide a licence-tester note or promo code |
| Target audience | 18+ only |
| Content rating (IARC) | Reference: no violence/sex/gambling; "users can interact" = No (no user-to-user); shares location = No |
| News app / COVID / Government | No |
| Financial features | None |
| **Health apps** | Declare: *Nutrition and weight management*; *Disease and condition management* (Medium: conditions, symptom and reading journal) — as tracking/logging, not diagnosis. Not a medical device. |
| Foreground service | `dataSync` (background_downloader): "user-initiated download of the 2.4 GB on-device AI model; progress notification; stops when done". Demo video: tap Download in Chat |
| Data safety | Below |

## 6. Data safety form

Basis: Play counts data as **collected** only when it leaves the device. Profiles, meals, chats, health
journal, camera frames, voice and the AI all stay on the phone, so they are *not* collected. Android Auto
Backup is the user's own Google backup (end-to-end encrypted with a screen lock) — not collected by the
developer. The doctor report and the "report response" email are user-initiated sharing through other apps.
The model download (Hugging Face) sends no user data. ML Kit was removed in M7 because it sends usage
diagnostics. Barcode scanning was removed (Oct 2026): its product data missed most European packets.
Health Connect (Oct 2026) is **read only** (weight, steps) and stays on the device, so still not collected —
but Play requires the **Health Connect permissions declaration** in App content (READ_WEIGHT: keep daily
goals current; READ_STEPS: show steps on Today) and the privacy policy section "Health Connect and Apple
Health". iOS: switch on the HealthKit capability in Xcode (Runner → Signing & Capabilities) before an iOS build.

| Question | Answer |
|---|---|
| Does the app collect or share user data? | **Yes** (only purchase history, via Google Play billing / RevenueCat) |
| Encrypted in transit | Yes |
| Users can request deletion | Yes — email (RevenueCat purchase records); everything else is deleted on the device |
| Financial info → **Purchase history** | Collected: Yes · Shared: No (RevenueCat is a service provider) · Processed ephemerally: No · Required (the plan check runs for every user) · Purpose: **App functionality** |
| Everything else (location, personal info, health and fitness, messages, photos, audio, files, calendar, contacts, app activity, web browsing, app info and performance, device or other IDs) | Not collected |

RevenueCat uses an **anonymous app user ID** (no custom ID, no email), so "Device or other IDs" stays
"Not collected" per RevenueCat's guidance. If that ever changes (login, custom IDs), revisit this form.
Recheck the form whenever a dependency adds network access (`grep -i "INTERNET\|analytics\|firebase" build/app/outputs/logs/manifest-merger-release-report.txt`).

## 7. Store listing (draft)

- Short description (80): *Nutrition assistant with on-device AI. Your food and health data stay on your phone.*
- Full description: what it does; tiers; "AI runs on your phone, no account, no ads, no analytics"; "2.4 GB
  AI download on first chat, Wi-Fi recommended"; wellness disclaimer; Gemma notice
  ("Gemma is provided under and subject to the Gemma Terms of Use found at ai.google.dev/gemma/terms").
- Category: Health & Fitness. Contact email: peredereev.ievgen@gmail.com. Website: the Pages URL.
- Screenshots: phone, 4–8, with dummy data only (never a real profile).
