# MyFoodMind

**A private, on-device AI nutrition assistant for Android.**

MyFoodMind plans meals, logs food, tracks nutrients and answers nutrition questions through an
AI chat. The language model, the embeddings and all personal data stay on the phone. There are no
accounts, no cloud inference and no analytics SDK.

[![android](https://github.com/PartORG/myfoodmind/actions/workflows/android.yml/badge.svg)](https://github.com/PartORG/myfoodmind/actions/workflows/android.yml)
[Latest release](https://github.com/PartORG/myfoodmind/releases/latest) ·
[Privacy policy & terms](https://partorg.github.io/myfoodmind/)

---

## Features

- **AI chat:** Gemma 4 runs locally with native tool calling. The model routes requests and
  phrases the answers. Code computes the numbers and the database supplies the facts, so nutrition
  values and recipes appear as cards from the database, never as model-generated text.
- **Food logging:** search about 50,000 foods, 166,000 recipes and 263,000 packaged products, or
  log by chat or voice.
- **Daily goals:** calorie and macro targets from Mifflin-St Jeor × activity, adjusted for your goal
  (lose, maintain or gain), with a manual override for every value. Micronutrients: calcium, iron,
  magnesium, potassium and vitamins C, D and B12.
- **Dashboards:** Today, Week (with a weekly review) and Month views, a weight card on Today and
  Me (latest weight, 30-day change, quick log), water tracking, fasting, streaks and an Android
  home-screen widget.
- **Meal plan and shopping list:** plan the week and turn the plan into a shopping list.
- **Allergies and conditions:** recipes containing your allergens are always filtered out.
  Conditions (type 2 diabetes, high blood pressure, gout, ALS, multiple sclerosis) come from
  published clinical guidelines: they cap daily limits (they only ever *tighten*), hide recipes
  with foods the guidelines say to avoid, and back the assistant's health answers with cited
  passages. See [Medical data](#medical-data).
- **Health journal:** symptoms and readings on a timeline, plus a PDF/CSV export for your doctor.
  The app records data and never interprets it.
- **Camera:** photo and live modes. Gemma 4 vision names the foods and estimates portions, and
  EfficientDet-Lite0 draws live boxes and acts as a fallback. Everything detected goes through a
  review screen before it is logged. No photo is ever stored.
- **Health Connect / Apple Health:** reads weight and steps.
- **Memory you control:** the assistant remembers facts only after you confirm them. You can view,
  edit or delete everything it knows about you.
- **Multiple profiles:** each profile is protected by a PIN or biometrics and has its own database.
- **Languages:** English, Ukrainian, German and French, chosen in Settings or the app bar (or
  follow the phone). The assistant answers in the chosen language.
- **Safety:** a medical disclaimer under the chat input, on every health-information card and in
  Settings → About. The assistant never diagnoses or advises on medicines, and a keyword check
  shows helpline information before the model runs when a message suggests a crisis.

### Plans

| Tier | Adds |
|---|---|
| **Free** | 15 chat messages a day, recipe search, logging, allergen filtering, Today dashboard, profiles, reminders |
| **Basic** | Unlimited chat, Week/Month dashboards, micronutrients, streaks, weight trend |
| **Medium** | Conditions, health journal, timeline, doctor export |
| **Pro** | Camera recognition (7-day free trial) |

One subscription per phone unlocks all of its profiles. Billing runs through RevenueCat (see
[`docs/BILLING_SETUP.md`](docs/BILLING_SETUP.md)).

## Medical data

The medical part of `nutri.db` is curated by hand in [`db/medical.sql`](db/medical.sql) from
clinical guidelines (ADA Standards of Care 2026, Diabetes Canada, Diabetes UK, NICE NG17/18/28/42/
69/136/219/220, ESC 2024 hypertension, Hypertension Canada 2025, NHLBI DASH, ACR 2012/2020 gout,
ESPEN 2018 neurology, EAN 2024 ALS, MND Association, MS Society, HealthLinkBC, AED, RCPsych MEED,
US and Canadian dietary guidelines). Every row names its guideline; passages are paraphrased, not
copied.

| Condition | Daily limits | Recipes hidden (foods to avoid) |
|---|---|---|
| Type 2 diabetes | sodium ≤ 2,300 mg, sugar ≤ 50 g | sugar-sweetened drinks |
| High blood pressure | sodium ≤ 2,000 mg, sugar ≤ 50 g | – |
| Gout | – | organ meats, sugar-sweetened drinks |
| ALS | – (needs *more* energy: covered in passages) | – |
| Multiple sclerosis | – | – |

Only foods a guideline says to **avoid** are hidden; foods it says to *limit* are explained in the
passages instead. 51 passages cover these conditions plus eating disorders (refeeding risk, warning
signs) and general healthy eating; the assistant's `condition_info` tool shows the best two with
their source. The guideline PDFs themselves are not in this repository (publisher copyright).

To change the medical data, edit `db/medical.sql` and apply it to an existing database in under a
second (the full build applies it too):

```bash
python3 tool/build_medical.py assets/nutri.db
```

When the data changes, bump `data_version` in `db/medical.sql` **and** `nutriDataVersion` in
`lib/data/nutri_db.dart`: phones replace their installed `nutri.db` once when the app expects a newer
version, then re-upload the file to the `build-inputs` release.

## Privacy

- All inference runs on the device through [`flutter_edge_ai`](https://pub.dev/packages/flutter_edge_ai)
  (LiteRT-LM, GPU with a CPU fallback).
- Personal data lives in per-profile SQLite databases on the phone. Android Auto Backup includes
  only the profile data, never the models or caches.
- There is no analytics or crash-reporting SDK. Network access is limited to the one-time model
  download and the optional product database download, both started by the user.

## Requirements

| | |
|---|---|
| Device | Android 10 (API 29) or later, arm64, **6 GB RAM or more** |
| Chat model | Gemma 4 E2B (2.6 GB), downloaded in the app on first use; Gemma 4 E4B is optional on 8 GB phones |
| Build | Flutter 3.47 (stable), Dart 3.13, JDK 17, Android SDK |

## Getting started

```bash
git clone git@github.com:PartORG/myfoodmind.git
cd myfoodmind
flutter pub get
```

Two large assets are git-ignored and have to be in place before a build:

| File | Source |
|---|---|
| `assets/nutri.db` (≈290 MB) | built with `uv run tool/build_real_nutri_db.py <data-dir> assets/nutri.db` (medical tables from `db/medical.sql`), or downloaded from the [`build-inputs`](https://github.com/PartORG/myfoodmind/releases/tag/build-inputs) release |
| `assets/models/embeddinggemma-300M_seq256.tflite`, `assets/models/embeddinggemma_sentencepiece.model` | EmbeddingGemma (Gemma terms, gated on Hugging Face), or the `build-inputs` release |

```bash
gh release download build-inputs --pattern nutri.db --dir assets
gh release download build-inputs --pattern 'embeddinggemma*' --dir assets/models
```

Run on a connected device:

```bash
flutter run --release --dart-define=DEV_BILLING=true   # developer tier switch, no payments
```

### Build flags

| Flag | Effect |
|---|---|
| *(none)* | Free-only build |
| `--dart-define=DEV_BILLING=true` | Developer tier switch for testing the paid features |
| `--dart-define=REVENUECAT_KEY=goog_…` | Real Google Play subscriptions |

### Release builds

The CI release APK is built with `DEV_BILLING=true` for now (no RevenueCat yet).

```bash
flutter build apk --release --target-platform android-arm64        # sideloadable APK
flutter build appbundle --release --target-platform android-arm64  # Play Store
```

Builds are arm64 only. Signing reads `android/key.properties` (git-ignored); without that file,
release builds fall back to the debug key. For the Play Store steps, see
[`docs/PLAY_RELEASE.md`](docs/PLAY_RELEASE.md).

## Testing

```bash
flutter test                                    # host tests (fake model, test/nutri_test.db)
flutter test integration_test/agent_eval_test.dart   # on a phone: tool-calling accuracy of the real model
cd tool && uv run --with pytest --with duckdb --with openpyxl pytest   # nutri.db builders and medical data
```

The host tests cover the agent and its tools, memory, goal formulas, migrations, billing tiers and
the camera review flow. They also run every main screen at 200 % text size in all four languages.
When `assets/nutri.db` is present, `test/real_nutri_db_test.dart` checks the real database too,
including its medical data and `data_version`.

## CI/CD

[`.github/workflows/android.yml`](.github/workflows/android.yml) runs on every push to `main`. It
reads `version:` from `pubspec.yaml`, and if no release `v<version>` exists yet, it builds a signed
arm64 APK and publishes it as a GitHub Release. **To ship a new version, bump `version:` in
`pubspec.yaml` and push.**

Repository secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
`ANDROID_KEY_PASSWORD`. The large assets come from the `build-inputs` release. To change one, run
`gh release upload build-inputs <file> --clobber`. The build fails if that `nutri.db` has an older
`data_version` than the app's `nutriDataVersion`, so stale data never ships.

## Project structure

```
lib/
  agent/      chat agent, tools, memory, crisis check, Gemma adapter
  billing/    tiers and RevenueCat
  data/       nutri.db / user.db access, goals, diary, conditions, plans, Health Connect
  ui/         screens (Today, Chat, Log, Me, camera, settings, …)
  vision/     EfficientDet detector and Gemma photo naming
  l10n/       .arb translations (en, uk, de, fr) and generated localizations
db/           nutri.db schema, test fixture data and the curated medical data (medical.sql)
tool/         Python builders for nutri.db (incl. build_medical.py) and the products database
test/         host tests
integration_test/  on-device evaluation and latency tests
docs/         plan and decisions, data sources, billing and Play release guides
site/         privacy policy and terms (GitHub Pages)
```

[`docs/PLAN.md`](docs/PLAN.md) records the architecture and product decisions and is binding.
[`docs/DATA_SOURCES.md`](docs/DATA_SOURCES.md) documents how `nutri.db` is built and what it keeps.

## Disclaimer

MyFoodMind and its AI assistant give general information about food and nutrition. They are not a
medical device and do not diagnose, treat, cure or prevent any disease. Nothing in the app,
including the assistant's answers, condition limits and health information, replaces advice from a
doctor, dietitian or other qualified health professional, and the on-device AI can make mistakes.
Talk to your doctor before changing your diet, medicines or treatment, especially with a medical
condition, in pregnancy, or with a current or past eating disorder. In an emergency, call your local
emergency number.

## License

Copyright © 2026 Ievgen Perederieiev. All rights reserved. Third-party model terms are in
[`assets/licenses/models.txt`](assets/licenses/models.txt).
