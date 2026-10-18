# My Nutrition AI

**A private, on-device AI nutrition assistant for Android.**

My Nutrition AI plans meals, logs food, tracks nutrients and answers nutrition questions through an
AI chat. The language model, the embeddings and all personal data stay on the phone. There are no
accounts, no cloud inference and no analytics SDK.

[![android](https://github.com/PartORG/My_Nutrition_AI/actions/workflows/android.yml/badge.svg)](https://github.com/PartORG/My_Nutrition_AI/actions/workflows/android.yml)
[Latest release](https://github.com/PartORG/My_Nutrition_AI/releases/latest) ·
[Privacy policy & terms](https://partorg.github.io/My_Nutrition_AI/)

---

## Features

- **AI chat:** Gemma 4 runs locally with native tool calling. The model routes requests and
  phrases the answers. Code computes the numbers and the database supplies the facts, so nutrition
  values and recipes appear as cards from the database, never as model-generated text.
- **Talk to the assistant:** tap the mic in the chat and speak; Gemma 4 itself writes down what you said (no
  offline speech pack needed), and the answer is read aloud in a woman's or a man's voice (Settings → Voice; the
  phone's own offline voices). The recording is deleted as soon as it is written down.
- **Eva and you:** the assistant is drawn as Eva, the developer's miniature schnauzer (chat, tab bar, unlock
  screen). Your own picture is a woman, man or neutral (they/them) icon on a colour you pick, or a photo from
  your phone (Settings → Your picture).
- **Home-screen widget:** small, medium and large sizes with today's calories (opt-in), a Log button and a mic:
  say what you ate and the chat shows the meal card to check and save.
- **Food logging:** search about 61,000 foods (US, NZ, French and UK government tables), 171,000 recipes, 620 dishes and 263,000 packaged
  products, or log by chat or voice. Tap "+" on a meal to log straight into it, or repeat yesterday's
  meal in one tap.
- **Daily goals:** calorie and macro targets from Mifflin-St Jeor × activity, adjusted for your goal
  (lose, maintain or gain), with a manual override for every value. Micronutrients: calcium, iron,
  magnesium, potassium and vitamins C, D and B12.
- **Dashboards:** Today, Week (with a weekly review), Month and Year views, water tracking, fasting,
  streaks and an Android home-screen widget. Totals that include estimates are marked "≈". A weight
  trend screen shows a smoothed trend line over 1, 3, 6 or 12 months, so a heavy morning isn't
  mistaken for a real change.
- **History:** meals day by day and the recipes you cooked (how often, when last), for a date range
  you pick; tap a recipe to open it.
- **Plan, recipes and shopping:** plan the week and swap any meal. The recipe box holds what you
  saved, cooked or rated 4★+, searches every recipe, and suggests recipes from what's in your
  fridge. The shopping list is grouped by aisle and shows which recipe each item is for.
- **Recipes and Cook mode:** a servings stepper scales the amounts and nutrition. Add a recipe to
  the plan, log a serving, or cook it step by step: the screen stays on, each step shows the
  ingredients it uses, and a timer starts when the step names a time.
- **Allergies and conditions:** recipes containing your allergens are always filtered out.
  Conditions (type 2 diabetes, high blood pressure, gout, ALS, multiple sclerosis) come from
  published clinical guidelines: they cap daily limits (they only ever *tighten*), hide recipes
  with foods the guidelines say to avoid, and back the assistant's health answers with cited
  passages. See [Medical data](#medical-data).
- **Health journal:** symptoms and readings on a timeline, plus a PDF/CSV export for your doctor.
  The app records data and never interprets it.
- **Camera:** photo and live modes, or a photo from the gallery. Gemma 4 vision names the foods and
  estimates portions, and EfficientDet-Lite0 draws live boxes and acts as a fallback. Everything
  detected goes through a review screen before it is logged. No photo is ever stored.
- **Fix what the AI got wrong:** on the chat meal card and the photo review, tap a food to swap it,
  remove it, add one, or change the amount (also by half servings) before saving. Every log can be
  undone, and a meal on Today can be changed later (food, amount or meal).
- **Health Connect / Apple Health:** reads weight, steps and burnt calories (active calories, or for Google Fit,
  which writes only totals, the total minus your resting burn so far). Burnt calories show as
  a second ring on Today, next to the calories left, and are never added to the goal. Steps refresh
  while the app is open; disconnect from the steps tile or in Settings.
- **Memory you control:** the assistant remembers facts only after you confirm them. You can view,
  edit or delete everything it knows about you.
- **One profile per phone:** unlocked by fingerprint, with a PIN as the fallback. You can change the
  PIN in Settings. Signing up with Google is optional (see Build flags), and the account can be linked
  or unlinked later. Nothing leaves the phone.
- **Languages:** English, Ukrainian, German and French, chosen in Settings or the app bar (or
  follow the phone). The assistant answers in the chosen language.
- **Safety:** a medical disclaimer under the chat input, on every health-information card and in
  Settings → About. The assistant never diagnoses or advises on medicines, and a keyword check
  shows helpline information before the model runs when a message suggests a crisis.

### Plans

| Tier | Adds |
|---|---|
| **Free** | 30 chat messages a day, recipe search, logging, allergen filtering, Today/Week/Month dashboards with weight trend, fingerprint/PIN lock, meal reminders, 30 days of history |
| **Basic** | Unlimited chat, meal plan and shopping list, water reminders, micronutrients, streaks, 3 months of history |
| **Medium** | Conditions, health journal, timeline, doctor export, 8 months of history |
| **Pro** | Camera recognition, Year dashboard, 12 months of history (7-day free trial) |

History limits only what you can browse: older logs stay on the phone and come back when you upgrade.

One subscription per phone. Billing runs through RevenueCat (see
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

## Food data and vitamins

`nutri.db` holds about 61,400 foods, 171,000 recipes, 620 dishes and 263,000 packaged products. The
generic foods come from government tables first: USDA SR28, FoodData Central (FNDDS survey foods and
Foundation foods, from the public-domain [bulk downloads](https://fdc.nal.usda.gov/download-datasets)),
NZ FOODfiles, the French ANSES-CIQUAL 2025 table and the UK's McCance and Widdowson's CoFID 2021 (European
foods and dishes, all seven micronutrients). Every food row records its `source`, and the app prefers these tables when two
names match equally well. The EU tables list carbohydrate without fibre; the build adds the fibre back,
so every `carbs_g` is a total as in USDA (calories stay as published).

Vitamins and minerals (calcium, iron, magnesium, potassium, vitamins C, D and B12) cover:

- **Foods:** about two thirds have calcium and iron. All 30 everyday foods the meal parser picks
  ("rice", "egg", "milk", "chicken liver"…) have the full set.
- **Recipes:** values are summed from the ingredients. About 99 % of recipes have values for every
  ingredient.
- **Dishes:** McDonald's items take calcium, iron and vitamin C from their own labels. Each dish is
  then matched to a USDA FNDDS food of the same name for the rest (155 of 620). Generic dishes also
  link to a recipe of the same title, which you can open and rate (88).
- **Products:** whatever the Open Food Facts label states (about half of the bundled 2019 products give
  calcium, iron and vitamin C; about 15 % of the 2 million in the optional download do).

A value outside a believable range in a non-government source is stored as unknown, never shown.
Meals logged before an update get their vitamins filled in once from the food or dish of the same name.

Raw data lives next to the repository (`nutrition-ai-assistant/data/`). The three FoodData Central
releases go in `raw_fdc/{survey,foundation,sr_legacy}/`, CIQUAL's XML files in `raw_eu/ciqual/` and
CoFID's workbook in `raw_eu/cofid/`; the build script's docstring has the links. The file must stay
under 400 MB (`MAX_DB_BYTES`, checked by the build and by `test/real_nutri_db_test.dart`).

## Translated ingredient names

Recipe ingredients (the ~2,100 foods used in recipes) show in Ukrainian, German and French from
[`db/food_names.tsv`](db/food_names.tsv): one row per food with its English name and the three
translations, machine-translated by [TranslateGemma](https://ollama.com/library/translategemma) 4B
and open to review. A reviewed cell is never overwritten; fix a name by editing the file. The recipe
card says "Ingredient names machine-translated" whenever it shows one.

Recipe steps are translated on the phone, free, when the user taps **Translate steps**: the on-device
Gemma model writes them a few lines at a time (numbers, units and temperatures kept as written), the
card labels them as machine-translated with **Show original** one tap away, and each recipe's
translation is saved in the profile's `user.db`, so it's done once. It runs between chat turns, since
one model serves one conversation at a time on a phone.

```bash
ollama pull translategemma:4b
python3 tool/food_names.py translate assets/nutri.db  # fills missing names; resumable
python3 tool/food_names.py apply assets/nutri.db      # writes the food_names table (the full build does too)
```

A food renamed in a rebuild makes its row stale: `apply` skips it and `translate` redoes it.

## Privacy

- All inference runs on the device through [`flutter_edge_ai`](https://pub.dev/packages/flutter_edge_ai)
  (LiteRT-LM, GPU with a CPU fallback).
- Personal data lives in per-profile SQLite databases on the phone. Android Auto Backup includes
  only the profile data, never the models or caches.
- Voice stays on the phone: chat recordings are a temporary file that Gemma 4 writes down and the app then
  deletes; spoken answers use only the phone's installed offline voices.
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
git clone git@github.com:PartORG/My_Nutrition_AI.git
cd My_Nutrition_AI
flutter pub get
```

Two large assets are git-ignored and have to be in place before a build:

| File | Source |
|---|---|
| `assets/nutri.db` (≈310 MB) | built with `uv run tool/build_real_nutri_db.py <data-dir> assets/nutri.db` (medical tables from `db/medical.sql`), or downloaded from the [`build-inputs`](https://github.com/PartORG/My_Nutrition_AI/releases/tag/build-inputs) release |
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
| `--dart-define=GOOGLE_CLIENT_ID=….apps.googleusercontent.com` | "Continue with Google" at sign-up and "Sign in with Google" on the lock screen. Needs an Android OAuth client (package name + SHA-1 of the signing key) and a Web client in Google Cloud Console; pass the **Web** client id. Android only for now |
| `--dart-define=AGENT_THINKING=true` | Gemma 4 thinks before answering. Slower; compare with the eval first |

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
#   --dart-define=PROMPT=legacy   the v0.6 prompt + reply tool, as the baseline
#   --dart-define=THINKING=true   with Gemma 4 thinking
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
  ui/         screens (Today, Chat, Log, Me, camera, settings, …), voice (Gemma speech-to-text, TTS), avatars
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

My Nutrition AI and its AI assistant give general information about food and nutrition. They are not a
medical device and do not diagnose, treat, cure or prevent any disease. Nothing in the app,
including the assistant's answers, condition limits and health information, replaces advice from a
doctor, dietitian or other qualified health professional, and the on-device AI can make mistakes.
Talk to your doctor before changing your diet, medicines or treatment, especially with a medical
condition, in pregnancy, or with a current or past eating disorder. In an emergency, call your local
emergency number.

## License

Copyright © 2026 Ievgen Perederieiev. All rights reserved. Third-party model terms are in
[`assets/licenses/models.txt`](assets/licenses/models.txt).
