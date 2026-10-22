# My Nutrition AI — Plan

Agreed 2026-10-04 in a grilling session. Decisions here are binding; change them
by editing this file deliberately, never by silently diverging in code.

## Product

| | |
|---|---|
| Name / ID | **My Nutrition AI** (MyFoodMind until v0.11.0) · repo `PartORG/My_Nutrition_AI` · app ID `io.github.partorg.myfoodmind` and Dart package `myfoodmind` kept, so installs update in place |
| Goal | Commercial, **Android-first** (iOS later), English v1 with `flutter_localizations` + `.arb` from day one |
| Promise | All AI and data on the phone. No analytics/crash SDK — Play vitals + RevenueCat dashboard only |
| Min device | Android 10 (API 29)+, arm64, **≥6 GB RAM** (decided 2026-10-04 for Gemma 4 E2B) — Play device-catalog exclusion + in-app RAM check |
| Audience | Declared 18+. One profile per phone (v0.7.0), so no child profiles; under 18 → manual targets only |
| Privacy policy / ToS | GitHub Pages: `https://partorg.github.io/My_Nutrition_AI/` (includes Gemma use-policy terms for EmbeddingGemma; Gemma 4 is Apache 2.0) |

## Tiers — one subscription per phone

| Tier | Includes |
|---|---|
| **Free** | AI chat **30 user messages/day** (counted per phone, resets local midnight), recipe search, meal logging, saved/liked recipes, **allergen filtering (always free)**, today's dashboard, **weekly/monthly dashboard** (calories per day, averages, week review, weight trend), fingerprint/PIN lock, meal reminders, **History: last 30 days** |
| **Basic** | Unlimited chat, **meal plan + shopping list**, **water reminders**, micronutrients, streaks, **History: 90 days** |
| **Medium** | + Conditions (diabetes, ALS, MS, …): rule-based filtering & limits, symptom + reading journal, timeline charts, doctor export (PDF/CSV). **Records, never interprets** (except: how often symptoms followed a food, as counts, never a cause; see "All nutrients, patterns" 12). **History: 240 days** |
| **Pro** | + Camera: photo / live video / barcode → review & edit screen → "What can I cook?" or "Log this meal" (user confirms portion, values shown as ≈). **Year dashboard**. **History: 365 days**. **7-day free trial** (Play offer) |

- RevenueCat, anonymous device user, entitlements `basic ⊂ medium ⊂ pro`, one `has(tier)` check.
- Tier changes use RevenueCat product change (replacement + proration) — never double charge.
- **M4 decisions (2026-10-04):** monthly + yearly per paid tier (Pro trial unchanged); weight logging is free
  (goals use the current weight), the weight trend chart is Basic; no store/RevenueCat accounts yet, so a
  developer tier switch stands in until they exist.
- **Tier changes (2026-10-11):** Week/Month and the weight trend are free; free chat 15 → 30 (the model
  runs on the phone, so chat costs nothing to serve); meal plan + shopping list move to Basic (not Medium:
  Medium stays the medical tier); water reminders (Basic) are one glass each, spread 9:00–21:00 to reach the
  water goal; History reaches back 30/90/240/365 days by tier. **Older logs are hidden, never deleted**:
  a downgrade, a lapsed card or a billing outage (store-less build = Free) must not destroy health data.
  The Year view (Pro) shows calories per month, a logging calendar, nutrient averages with the best and
  worst month, weight over the year and the most-eaten foods.
- **Gaps closed (2026-10-11):** micronutrients are Basic (Today's card, the recipe card line); the
  assistant's recall of past events stays inside the tier's history window; water reminders reschedule
  themselves when the water goal changes, and a downgrade cancels them on every profile by notification id.
- **Ingredient names (2026-10-11):** `db/food_names.tsv`, TranslateGemma 4B at build time, reviewable;
  `food_names` in nutri.db (data_version 2), shown with a "machine-translated" note, English fallback.
  Recipe steps: free, translated on tap by the on-device Gemma (a tool-less session, ~300-character
  chunks under the 256-token reply cap), between chat turns (the chat session closes and replays; a second
  concurrent session risks OOM on phones per flutter_edge_ai), saved in user.db `recipe_translations` (v10),
  labelled with the original one tap away. Speed on the phone not measured yet.
- Chat limit table in code: `free: 30, basic+: unlimited`. Bypass by clearing app data is accepted (wipes data too).

## Architecture

**Rule: the model routes and words; code computes; the database answers.** Numbers, recipes and
medical notes are rendered as cards from the database, never as model-generated facts.

- **Agent model:** **Gemma 4 E2B** (`gemma-4-E2B-it.litertlm`, 2.6 GB, Apache 2.0, ungated) via `flutter_gemma`,
  GPU with CPU fallback, native tool calling. Chosen in M0 (95.2% tool accuracy on device); also multimodal,
  so it is a candidate to replace the photo detector for Pro later. Runtime budget ≈2 GB RAM.
  **Optional: Gemma 4 E4B** (`gemma-4-E4B-it.litertlm`, 3.66 GB, Apache 2.0) on phones reporting ≥7 GB RAM
  (8 GB phones), chosen at first download or switched in Me → AI model (the other file is deleted). ~3x slower
  prefill than E2B (1,293 vs 3,808 tok/s GPU, S26 Ultra, model card). Tool accuracy not measured yet:
  run `integration_test/agent_eval_test.dart` with `MODEL_PATH` on the phone before recommending it.
- **Tools:** plain Dart functions over SQL returning structs (see `lib/agent/tools.dart`).
- **Embeddings:** EmbeddingGemma 512 (768-d). Fixed prefixes: query `task: search result | query: {q}`,
  document `title: none | text: {t}`. Same model + prefixes on PC and phone.
- **Search:** SQLite FTS5 (foods, recipes, dishes, products) + brute-force cosine over `docs` and
  episodic vectors, merged with RRF. ObjectBox only if measured slow.
- **Vision (Apache stack, no Ultralytics/AGPL):** `tflite_flutter` + EfficientDet-Lite0 (COCO, bundled asset,
  food classes only) since M6; real food/dish model trained with D-FINE / RT-DETR / YOLOX → TFLite, labels =
  `foods.name`/`dishes.name`, drops in behind the same `Detector` interface (`lib/vision/detector.dart`).
  Photo mode (2026-10-06): Gemma 4 E2B vision names the foods + estimates grams (`nameFoods` in
  `lib/vision/scan.dart`, own session, model loaded with `supportImage`); EfficientDet stays for live mode
  and as the photo fallback before the chat model is downloaded.
  Camera via `camera` (photo + live, frames never stored); barcode via `flutter_zxing` (zxing-cpp, EAN/UPC,
  no network; ML Kit was dropped in M7 because it sends usage diagnostics to Google).
  Everything detected goes through the review screen before use.
- **Memory (per profile):**
  1. Working — last 6 messages.
  2. Semantic — `memory_facts`, written via `remember_fact` + user confirmation.
  3. Episodic — chat messages, logged meals, camera scans as dated one-line texts + embeddings;
     top-3 quoted verbatim. Photos are not stored.
  4. Habits — computed by SQL into a ~200-token profile card each turn.
  - Every write proposed by the model needs a ✓/✕ confirmation card.
  - "What the AI knows about me" screen: view/edit/delete facts, wipe episodic memory.
- **Safety:** crisis keywords → fixed helpline card before the model runs. Condition rules only ever
  tighten limits. Wellness wording only ("suggestions", "limits"; never "treat", "diagnose",
  "safe for your condition"). "Report this response" on every AI message via long-press (email draft); no icon (user decision 2026-10-04).
- **Goals:** Mifflin-St Jeor × activity, ±15% for goal, kcal floor; protein 1.2 g/kg, fat 30%,
  carbs rest, fiber 14 g/1000 kcal, WHO sodium/sugar. Manual override per value. Under 18 → manual only.
- **State:** Riverpod 3, no codegen. **UI:** reuse NutriAI theme + screen layouts, rewrite internals.
- **M3 decisions (2026-10-04):** metric + imperial per profile (stored metric); goals onboarding is
  skippable (dashboard nudges until set); big mic button in chat (Android speech recognizer, prefer
  offline); bottom tabs Today · Chat · Log · Me.
- **Reminders:** `flutter_local_notifications`, per profile, permission requested on enable, inexact
  scheduling, reschedule on boot, `VISIBILITY_PRIVATE` on lock screen.
- **Accessibility:** large tap targets, TalkBack labels, voice input via Android speech-to-text.

## Storage

```
nutri.db                   shared, read-only, replaced whole (meta.schema_version range)
models/                    LLM + embedding, not backed up (the 4.6 MB detector ships as an app asset)
profiles.db                the phone's one profile (PIN hash, fingerprint flag, linked Google email), chat counter, settings
profiles/<id>/user.db      private data, PRAGMA user_version migrations (add-only, one transaction)
vectors/<id>.db            episodic embeddings, not backed up, rebuilt after restore
```

Backup is **include-only** (`android/app/src/main/res/xml/`): `profiles.db` + `profiles/`. Everything else
in the app folder — nutri.db, models, flutter_gemma's ~800 MB GPU caches, vectors — stays out, because
going over Auto Backup's 25 MB quota silently stops all backup.

- Profile: **one per phone** (v0.7.0). Fingerprint, PIN (4–6 digits, salted hash) as the fallback, or the
  linked Google account; unlocked until 5 min in background; growing lockout after 5 wrong tries; forgot PIN =
  delete profile; monthly doctor-export reminder.
- Delivery (decided M7): `nutri.db` bundled as an asset until real data exists; EmbeddingGemma bundled in the
  app; Gemma 4 downloaded once from Hugging Face on the user's tap (2.2 GB compressed is over Play's 1.5 GB
  per-asset-pack limit). Dev: models via `adb push` still win.

### nutri.db data contract (owner: Ievgen builds real DBs to this)

`meta(key, value)` — `schema_version`, `embedding_model`, `built_at` ·
`foods` (per 100 g: kcal, protein_g, fat_g, carbs_g, fiber_g, sugar_g, sodium_mg) ·
`recipes(id, title, instructions, servings, minutes, tags, texture)` ·
`recipe_ingredients(recipe_id, food_id, grams)` · `dishes(id, name, serving_g, recipe_id NULL, food_id NULL, + per-100 g
nutrition and micronutrients)` · `products(barcode, name, + per-100 g nutrition and label micronutrients)` ·
`foods.source` (the dataset; government tables rank first) · `allergens(food_id, allergen)` ·
`conditions(id, name)` · `condition_rules(condition_id, nutrient, max_per_day, note)` ·
`condition_avoid(condition_id, food_id, note)` (M5: foods to avoid, filtered like allergens) ·
`docs(id, source, text, embedding BLOB float32[768])` + FTS5 tables.

Rules: recipe nutrition is computed at build time (v4: stored per serving) · additive changes need no version bump ·
docs chunks ≤ 512 tokens, ≤ ~50k docs · `nutri.db` ≤ 400 MB · data licensing is the data owner's job.

## Milestones

| # | Goal | Done when |
|---|---|---|
| **M0** | ~100 labelled queries; compare candidate models on the phone; check chat + embedding models load together | ≥90% tool accuracy ✅ (Gemma 4 E2B 95.2%); in-app latency and RAM with both models recorded |
| M1 | Skeleton, `schema.sql` + dummy DB, profiles + PIN, migrations, PC-vs-phone embedding check | Tests pass ✅ (22 host tests + on-phone checks) |
| M2 | Agent, tools, 4-type memory, chat limit, confirmation cards, report button | Eval runs as on-device `integration_test`; unit tests use a fake model ✅ (54 host tests; 105-query re-run with the new prompt skipped by user decision) |
| M3 | Onboarding/goals, logging, dashboard, reminders, accessibility | Goal formula test with reference values ✅ (77 host tests) |
| M4 | RevenueCat, Basic dashboard, weight logging, tier changes, Pro trial | Sandbox buy / upgrade / restore ⏳ code done + dev tier switch (88 host tests); sandbox test waits for the accounts: `docs/BILLING_SETUP.md` |
| M5 | Medium: conditions, journal, timeline, doctor export | No forbidden ingredient for a given condition ✅ (97 host tests) |
| M6 | Pro: tflite detector + barcode → review → cook/log | Full flow with dummy detector + products ✅ (105 host tests); real detector on the phone ⏳ `integration_test/detector_test.dart` |
| M7 | Model delivery, privacy policy + ToS + Gemma terms, Data safety, trademark check (EUIPO/USPTO class 9/44) | Internal-testing build installs and runs ⏳ code + docs done (105 host tests, arm64 `.aab` builds); needs Play Console + upload key: `docs/PLAY_RELEASE.md` |

**v1.1:** Health Connect import · encrypted backup export · iOS · second language · optional photo storage.

## M0 results (2026-10-04, Linux desktop CPU, same engine as Android)

`linux/` exists only to run the model eval on a dev PC; it is not a shipping target.

| Model file | Result |
|---|---|
| `Qwen3-0.6B.litertlm` (INT8, plugin's default URL) | Does not load: tokenizer error in LiteRT-LM (`piece must not include null character`) |
| `Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm` (INT4, 329 MB) | Loads in 0.8 s, ~1.2 GB RAM, 4.4 s/answer p50 on CPU. **Tool accuracy 43.8%** (forced tool choice + lenient parser); 20% with the plugin's default `auto` prompt |
| `functiongemma-270M-it.litertlm` | Loads; context is fixed at 1024 tokens and 13 tool schemas don't fit |
| `Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm` (558 MB) | **13.3%** — escapes to `reply` or invents tool names. Ruled out |
| **Option A:** EmbeddingGemma 512 router, 1-NN over ~110 example messages (no LLM; code removed after M0) | **83.8% tool accuracy**, 362 ms/route on CPU, +360 MB RAM. Embedding 110 examples at startup takes 42 s → must ship precomputed |
| **`gemma-4-E2B-it.litertlm` (2.6 GB, Apache 2.0, ungated) on Xiaomi 11T (MT6893, 8 GB), GPU, all 13 tools** | **95.2% tool / 90.5% args — passes the gate.** 8.1 s p50 per query (≈3.5 s is the harness re-creating the chat each query; rest is prefill of 13 tool declarations), ~1.95 GB RSS, first load 34 s. Crashes in native code on Linux desktop, so Gemma 4 is evaluated on the phone only |
| Option A + Qwen3 0.6B filling args for the one routed tool | Args right on 63/88 correctly routed queries (72%); Qwen3 often echoes the tool schema instead of values. 2.5 s p50 |

Plugin findings (flutter_gemma 1.11.3): Qwen3 gets a generic JSON tool prompt, `auto` mode carries
demo-app wording that discourages tool calls, and every Qwen3 token comes back wrapped in
`<|channel>thought\n…<channel|>` so the plugin's own parser misses the calls — `lib/agent/tool_call_parser.dart` handles it.

### M0 step 1–3 (phone, one reused conversation, Gemma 4 E2B GPU + EmbeddingGemma loaded together)

Script: 8 realistic turns incl. tool call → tool result → answer (`integration_test/agent_latency_test.dart`).

| Measure | Result |
|---|---|
| Load | LLM 38 s on first launch (GPU setup), **3.2 s** afterwards (cached) · chat with 13 tools created 2.3–2.9 s |
| First message | 7.5–8.6 s (tool declarations are prefilled once, on the first turn) |
| Later turns: tool call | **2.4–4.1 s** (was 8.1 s with a new chat per message) |
| Later turns: written answer | 0.5–9.5 s, grows with answer length → stream it, keep answers short |
| RAM peak, both models | **3.0–3.4 GB** RSS — fits the 6 GB minimum |
| EmbeddingGemma on phone | **~2.0 s per text, CPU only** (GPU request falls back to CPU); 115 router examples took 227 s |
| Routing | All 8 script turns routed correctly by Gemma 4 itself |

Decisions from these numbers:
- **Gemma 4 routes by itself** (95.2%). The embedding router is not used for routing: it costs 2 s per
  message on the phone, and a top-3 tool shortlist (step 2) would need a new conversation per message
  (+2.9 s) — slower than the 2.4–4.1 s we have. Step 2 skipped on this evidence.
- EmbeddingGemma stays for medical search and episodic memory, run off the chat's critical path.
  To check in M1: the 512-token model likely pads every text to 512; the 256-token build may halve the time.
- M2: stream answers (`generateChatResponseAsync`), short-answer instruction, warm the conversation at app
  start, and tool results must say "awaiting user confirmation" clearly — the model told the user
  "I have added peanuts" while the result was still pending.

## M1 results (2026-10-04)

- `db/nutri_schema.sql` is the data contract; `tool/build_nutri_db.py` builds `nutri.db` from SQL files
  (stdlib only, atomic, checks foreign keys and meta). Dummy data: `db/nutri_dummy.sql` → `test/nutri_test.db`
  (the fixture every host test uses). Real data (2026-10-06): `tool/build_real_nutri_db.py` → `assets/nutri.db`
  (git-ignored, too big for GitHub), per-file report in `docs/DATA_SOURCES.md`, gate `test/real_nutri_db_test.dart`.
  Contract additions: ids are stable across releases; `meta.embedding_model = 'embeddinggemma-300m'`
  names the model, not the file variant.
- user.db v1 tables: chat_messages, memory_facts, user_allergens, saved_recipes, meal_log (nutrition
  snapshot at log time), symptoms, readings. profiles.db v1: profiles, chat_usage.
- PIN: PBKDF2-HMAC-SHA256 100k (≈0.24 s on PC, on a background isolate); 4 wrong → 5th locks 30 s,
  doubling, capped 1 h; the PIN isn't checked while locked.
- **Embedder:** the seq512 build pads every text to 512 tokens. **Use the seq256 build on the phone:
  0.58 s vs 1.4–1.6 s per text, identical vectors (cos 1.0000).**
- **PC vs phone vectors:** sentence-transformers (`google/embeddinggemma-300m`, full precision) vs the
  phone's mixed-precision `.tflite`: cos 0.96 on every text, nearest neighbour agreed 8/8. Not the prefix
  (checked), not bf16 (checked) → quantization. Either embed docs with sentence-transformers and check
  recall on real data, or embed them with the same `.tflite` on the PC for an exact match. Decide when
  real docs exist. `tool/compare_embeddings.py` does the comparison.
- Not yet: biometric unlock (M3 with onboarding UI); the 5-minute auto-lock has no automated test.

## M3 results (2026-10-04)

- Goals: `lib/data/goals.dart` (formula per the plan, reference values in `test/goals_test.dart`), user.db v2
  (`body`, `goal_overrides`); a newer weight reading replaces the onboarding weight; under 18 → manual only.
- Bottom tabs Today · Chat · Log · Me. Profile databases open on unlock (`profileDataProvider`, auto-dispose,
  null while locked); the AI loads separately and stays alive across tabs.
- Log tab logs straight from the food database (pressing Log is the confirmation); one insert path shared with
  the chat cards and "I ate this".
- Reminders: user.db v3 `reminders`; meal reminders 30 min after the usual time (3+ logs in 30 days), else
  8:30 / 13:00 / 19:00; evening 21:00. Inexact daily, re-armed after reboot, private on the lock screen,
  first name only. Deleting a profile cancels its reminders.
- Voice: **on-device recognition only**; if the phone has no offline speech pack the app explains how to add
  it instead of falling back to online recognition (keeps "nothing leaves the phone"). Since v0.11.0 the chat's
  voice input is transcribed by Gemma 4 on the phone instead.
- Fingerprint: **only while the phone has one profile** (user decision: Android can't tell whose finger it
  is); adding a second profile turns it off for everyone. profiles.db v2. *Superseded in v0.7.0: one profile
  per phone, fingerprint always available.*
- Accessibility: 200 % text on a 360 dp phone has no overflow (`test/accessibility_test.dart`, found and fixed
  4); chat bubbles and nutrient tiles read as whole sentences; progress bars carry spoken labels.
- Not verified on the phone yet: reminders firing, voice recognition, fingerprint prompt.

## M4 results (2026-10-04)

- `Billing` interface: `RevenueCatBilling` (REVENUECAT_KEY), `DevBilling` (DEV_BILLING=true, tier stored in
  profiles.db v3 `settings`), `UnavailableBilling` (neither: Free only — a store-less build must never fall
  back to the dev switch). Packages `<tier>_<monthly|yearly>`, entitlements `basic`/`medium`/`pro`.
- Plan changes replace the old subscription: up / same tier → immediately with time credited
  (`withTimeProration`); down → at renewal (`deferred`). Monthly↔yearly is a replacement too.
- Gates: chat unlimited from Basic; Week/Month (calories per day + goal line, daily averages over logged
  days, week review, weight trend) free since 2026-10-11, their streak from Basic; logging weight is free;
  meal plan, shopping list and water reminders from Basic; Year from Pro; History window `Tier.historyDays`.
- Paywall: price and renewal terms next to every button, Pro "7 days free, then …", restore.
- Not verified: real purchases (no accounts yet). Setup checklist: `docs/BILLING_SETUP.md`.

## M5 results (2026-10-05)

Decisions (user, 2026-10-05):
- Forbidden ingredients: additive contract table `condition_avoid(condition_id, food_id, note)`, no
  schema_version bump; the app tolerates an older nutri.db without it.
- **Downgrade keeps filtering:** conditions already set keep hiding recipes and capping targets below
  Medium (safety never switches off silently). Editing conditions, the journal screen, timeline and
  report are Medium.
- Doctor report: **PDF + CSV through the Android share sheet** (`pdf`, `share_plus`); the app sends
  nothing itself. PDF embeds Noto Sans (OFL, `assets/fonts/`) so any script prints.
- Chat `log_health` (symptoms and readings) stays free; only the Health screen is Medium.

Built:
- user.db v4 `user_conditions`. `currentTargets` caps every target (manual ones too) at the lowest
  condition `max_per_day`; capped nutrients show "limit for …" and turn into ceilings on the bars.
- Recipe search drops recipes with allergens **or** avoided foods; a recipe opened by name lists the
  offending ingredients on the card and tells the model. The AI context names conditions and foods to avoid.
- Me → Health: condition chips with their limits, journal (symptom 1–5, glucose mg/dL or mmol/L,
  blood pressure; last 14 days, delete), timeline (30/90 days: limited nutrients per day, glucose in
  the latest unit, BP, weight, symptoms on one date axis), report (30/90/365 days).
- CSV: one row per meal/reading/symptom; typed text can't run as a spreadsheet formula.
- Gate test: `test/health_test.dart` searches every recipe title, tag and food under each condition and
  fails if any suggestion contains an avoided food (checked: it fails with the filter removed).

Not yet: monthly doctor-export reminder (reminders.slot CHECK needs a new table), texture rules for
ALS (recipes.texture exists, no rule links it), avoided foods aren't flagged in the Log tab search,
real condition data. Not verified on the phone: share sheet, PDF rendering on device.

## M6 results (2026-10-05)

Decisions (user, 2026-10-05): EfficientDet-Lite0 COCO via `tflite_flutter` now (real food model later);
**live mode included**; a barcode missing from nutri.db → "find it by name" on the review screen, offline.

- Model: TFLite task-library `efficientdet_lite0_detection_metadata_1` (Apache 2.0, 4.6 MB asset) — it has
  NMS built in (the MediaPipe build outputs 19 206 raw anchors). Input 320×320 uint8 RGB, outputs boxes /
  classes (0-based COCO-90 labelmap) / scores / count. Food classes 51–60 only. Checked on the PC: a banana
  photo → class 51, 0.76.
- Camera (`camera`): one screen, Photo ⇄ Live. YUV frames are converted in Dart to an upright 320² image;
  live detects every 500 ms and draws boxes; photo detects on the shutter. **No picture is written to disk.**
  Barcode: `mobile_scanner` (ML Kit, EAN/UPC only) → nutri.db `products` (replaced by `flutter_zxing` in M7).
- Review screen: rename/re-match, grams, remove, add by name, meal type; photo values ≈. "Log this meal"
  (the tap is the confirmation) or "What can I cook?" (recipes into the chat, no model, not counted).
  Entry: chat camera button, `open_camera` card, Log tab camera + barcode buttons. Below Pro → paywall.
- user.db v5 `scans` (one line per scan) → episodic memory. Dummy foods + apple, orange, carrot.
- Match rule: the shortest matching name wins ("banana" is the food, not "Overnight oats with banana").
- `android/build.gradle.kts`: tflite_flutter 0.12.1's Kotlin target forced to JVM 11 (Gradle rejects 11 vs 21).
- Release APK 187 → 231 MB (native libs for all ABIs); an arm64 app bundle split is M7's job.

Not yet / not verified: detector speed and boxes on the phone, camera permission prompt, barcode on a real
packet, live-mode smoothness (YUV conversion runs on the UI isolate; move it if it stutters), Gemma 4 vision
as a replacement detector (photo mode done 2026-10-06, see below).

## M7 results (2026-10-05)

Decisions (user, 2026-10-05):
- **Model delivery:** Play Asset Delivery is out — Gemma 4 compresses to 2.2 GB, over the **1.5 GB per
  asset pack** limit. Gemma 4 (Apache 2.0, ungated, same SHA-256 as the M0 file) downloads from Hugging Face
  when the user taps Download in Chat (resumable, flutter_gemma's downloader, progress, cancel).
  EmbeddingGemma is gated on HF, so it ships inside the app (Gemma terms allow redistribution with the notice).
- **Publisher:** Ievgen Perederieiev, individual; contact peredereev.ievgen@gmail.com (also the in-app
  report address, replacing the placeholder).
- **Signing:** the owner creates the upload key; `android/key.properties` (git-ignored) is read if present,
  else the debug key. Play App Signing.
- **Trademark:** pre-check only (`docs/TRADEMARK.md`); the official searches are the owner's.
- **ML Kit removed:** it sends usage diagnostics (device IDs, app info) to Google, against "no analytics".
  Barcodes now decode with `flutter_zxing` (zxing-cpp, MIT), on the device.

Built:
- `llmProvider`: adb-pushed file (dev) → already-downloaded model → else `LlmNotDownloaded`, and the Chat tab
  shows a download card (size, Wi-Fi, "nothing about you is sent"). Everything else works without the model.
- Release: `INTERNET` declared; implied `READ_PHONE_STATE` / storage permissions removed (TFLite GPU's and
  CameraX's old manifests); **arm64 only** — plugin `.so` files for other ABIs are excluded, else Play would
  offer the app to 32-bit/x86 phones that crash on start. `.aab` 257 MB (≈180 MB of it EmbeddingGemma).
- Legal: `site/` (landing, privacy policy, terms with the Gemma notice + Prohibited Use Policy, wellness
  disclaimer) deployed by `.github/workflows/pages.yml`; links in Me and on the paywall; model licences
  (Apache 2.0 text, Gemma notice) on the in-app licences page.
- `docs/PLAY_RELEASE.md`: upload key, build, internal-testing checklist, device catalog (RAM ≥ 6 GB),
  App content answers (Health apps, foreground service `dataSync`), Data safety (only purchase history is
  collected), store listing draft. Dependency scan: no analytics/telemetry left (RevenueCat diagnostics off).

Packaged products (Oct 2026): every Open Food Facts product with complete nutrition (2,034,064 of 4.5 M rows,
1.27 M with European barcodes) is an **optional download** in Me → Packaged products: `tool/build_products_db.py`
→ `products.db` (276 MB) → `products.db.gz` (104 MB), published as a GitHub release asset (`productsUrl` in
`lib/app_state.dart`, tag `products-2026-10`; **not uploaded yet**). Search uses it instead of nutri.db's 2019
products once it is on the phone. ODbL: credited on the licences page.

Open: the real `nutri.db` (≤ 400 MB, now built into `assets/` for phone builds) can't also be bundled in the Play build — the base module limit is 500 MB and the app is
already 257 MB. When the real data exists: an install-time asset pack (≤ 1.5 GB, read via a small native
bridge) or a download like Gemma 4 (it holds no user data either).

Owner to do: create the GitHub repo + Pages, upload key, Play Console app + internal track (needs the
developer account), official trademark searches, governing-law country in `site/terms.html` (TODO there),
legal review of the privacy policy and terms. Not verified on the phone: model download + offline restart,
zxing barcode scanning, bundled-embedder first load.

## After M7 (2026-10-06)

Fixed: **bundled embedder failed to install** after the Gemma 4 download (`PlatformException: Failed to copy
asset "assets/models/embeddinggemma-300M_seq256.tflite"`). flutter_gemma → `large_file_handler` always looks
bundled files up as `assets/<path>`, but they were declared as `models/…`. The two EmbeddingGemma files now
live in `assets/models/` (git-ignored, copy them there before building); `models/` keeps the adb/dev files.

Found on the phone: the camera labels almost everything "pizza". EfficientDet-Lite0 knows only 10 COCO foods
(banana … cake), so any plate gets the nearest of those. Not fixable by tuning; a different model is needed.

Decision (user, 2026-10-06): **good recognition in both photo and live mode**, in two steps:
1. **Photo — Gemma 4 E2B vision** ✅ code. The shutter sends the upright frame (own resolution, PNG via the
   engine's encoder, never written to disk) to the chat model in its own session (`nameFoods`,
   `lib/vision/scan.dart`); it answers `grams | name` per food; names are matched in nutri.db like typed text,
   grams go to the review screen. The model now loads with `supportImage: true` (vision encoder on the CPU).
   EfficientDet is the photo fallback until the chat model is downloaded. 108 host tests.
   Not verified on the phone: the `.litertlm` file's vision section loads, extra RAM, seconds per photo,
   name quality.
2. **Live — own small detector** ⏳. Superseded by the decisions of 2026-10-18 below (step 7).

## v0.7.0 (2026-10-15)

Decisions (user, 2026-10-15):
- **One profile per phone.** Fingerprint can't tell people apart, so multiple profiles are gone and fingerprint
  unlock is always offered, with the PIN as the fallback. On upgrade the oldest profile is kept and the others
  are **deleted** with their files and reminders (`Profiles.keepOnlyFirst`). profiles.db v4.
- **Google sign-in is optional**, identity only, no backend (`google_sign_in`, build flag `GOOGLE_CLIENT_ID`).
  "Continue with Google" fills the name and links the email; the lock screen then offers "Sign in with Google"
  for that account only. Known risk: on the owner's phone Google usually signs in without a password, so a
  linked account lets anyone holding the unlocked phone open the app and skips the PIN lockout.
- **Agent prompt** rewritten in sections (language, context, intents, several requests, distinctions, saving,
  safety). The `reply` tool is gone: general questions are answered in plain, streamed text. Several tool
  calls in one response all run (results go back together); a tool call written as text runs instead of being
  shown; a model still calling tools after 3 rounds shows an error instead of nothing. The v0.6 prompt stays in
  `integration_test/legacy_prompt.dart` as the eval baseline (`PROMPT=legacy`) until the new one has won on
  the phone. Thinking mode behind `AGENT_THINKING` (output cap 1024, turn room 2048, not measured yet).
- **Eval:** 146 queries; new groups for general questions, two requests in one message ('a+b', both must be
  called) and negation/uncertainty. TOOL_CHOICE defaults to `auto`, as in the app.
- **Food matching** (phone report: "rice with chicken liver in cream" logged ice cream): a candidate must
  contain every word said and its main name (before a comma) must be what was said; "in" splits items;
  "about/roughly/~" keep the amount; foods search looks at 10 candidates, not 3. `staples` in
  `agent_tools.dart` pins ~20 everyday words with no plain row to the row people mean (cooked rice and
  buckwheat, white bread, light cream, an egg = 50 g, honey = 21 g); `test/real_nutri_db_test.dart` checks the
  rows exist.
- **Change food** on Today's meal editor: swap a logged entry for another food (`replaceMeal`), keeping amount,
  time and meal.

Not verified on the phone: Google sign-in, the new prompt's accuracy and latency vs the legacy one, thinking.
The chat's confirmation card still can't swap a food before Save (grams only).

## Data v3 (2026-10-15)

Phone report: the vitamins card stayed empty. The generic foods the meal parser picks ("Rice", "Egg"…) came
from foodstruct, whose minerals and vitamins (in grams) were never loaded; dishes and products had no
columns for them at all.

- **schema_version 3, data_version 3:**
  - `foods.source` with an index on `name`.
  - `dishes` gets micronutrients and `food_id`; `products` gets micronutrients.
  - The app requires schema 3, so phones reinstall the bundled file.
- **Micronutrients:**
  - foodstruct (converted from grams), NZ FOODfiles, and FDC Foundation (bulk CSV fills what the extract lacks).
  - FNDDS 2021-2023: 5,316 survey foods are added as foods, with their "Quantity not specified" portion as the serving.
  - McDonald's label %DV (pre-2016 daily values) for dishes.
  - The OFF label columns for products.
  - Cross-checked against FoodData Central's API: banana, chicken liver and rice match USDA exactly; egg and
    milk are within about 10-25 %.
- **Range check:** values outside `MICRO_MAX` become unknown, except in government tables, whose extremes are
  real (baking powder calcium, dried thyme iron).
- **Dishes:**
  - **USDA match:** each dish links to the USDA FNDDS food covering every word of its name, with calories
    within 0.7-1.4x. The same chain wins, then the fewest extra words, then the closest calories.
  - **Recipe link:** generic dishes link to a recipe with exactly their title (filler words aside). That link
    is for opening and rating; the dish keeps its own nutrition.
- **App:**
  - Government sources win ties in the meal parser and in Log search.
  - Past meals are filled from the food or dish of the same name, once per data version.
  - Recipe ideas follow taste: the ingredients of 4-5 star and saved recipes, weighted by how rare they are,
    add up to 3 points (a requested ingredient is worth 10), in searches and in random ideas.
- **Products download (`products.db`):** `tool/build_products_db.py` writes the label micronutrients too
  (schema 2). Rebuilt 2026-10-16 from that day's dump and published as release `products-2026-10-16`
  (117 MB gz, 303 MB): the same 2,034,064 products as 2026-10-07 (OFF's CSV export had not changed), now
  with label micronutrients (~15 % give calcium/iron). Phones that downloaded the old file keep it until
  they remove and download again.
- **Size:** `nutri.db` was 299.75 MB, just under the 300 MB contract (raised to 400 MB in data v4).

## Catalogue v4: complete rebuild — decisions (user, 2026-10-19), in progress

Why: generic search is buried by branded rows in `foods` (34k of 61k: "banana" → banana chips, waffles), so the
agent gets poor candidates. Schemas: `db/catalog/` (the v3 builder and `db/nutri_schema.sql` stay until the switch).

1. **New ids, no mapping** from v3 ids.
2. **Upgrade wipes the profile's data:** `user.db` and the memory vectors are deleted on the first unlock with the
   v4 catalogue; the sign-in (name, PIN, avatar in profiles.db) stays.
3. **Wide nutrient columns**, NULL = unknown (no food_nutrients table).
4. **All sources kept:** generic → `foods`, branded → `products`.
5. **Licence rule for new downloads:** the original source must allow commercial use (CC0, CC BY, ODbL, OGL,
   etalab…), recorded per file in DATA_SOURCES.md. Exception: recipes (9, 10).
6. **Health:** official reference values and guidelines, plus licence-clean medical Q&A on all topics (e.g. MedQuAD),
   always quoted with their source, never rewritten by the model.
7. **Three files:** `nutri.db` + `health.db` bundled (≤ 800 MB together; was 500, raised 2026-10-20); `products.db` downloaded and kept on the
   phone (all branded: the old `foods` brands, chain menus, Open Food Facts).
8. **Scraped recipes kept** (food.com, BBC Good Food, allrecipes, Reddit) as a deliberate exception: copyright stays
   with the sites, takedown risk accepted by the owner.
9. **New scraped recipe sets allowed**; a set whose own licence says non-commercial / research only stays out
   (RecipeNLG). Foreign-language recipes kept.
10. **Translated on the PC** (TranslateGemma, cached) to English for matching; originals stored and shown in their
    language.
11. **Recipes:** ingredient lines (id, position, food, grams, original line), `recipe_steps`, `recipe_tags` from a
    fixed list, source and URL per recipe. Recipe nutrition precomputed per serving with coverage per nutrient.
12. **No `dishes` table:** chain menu items → products; generic dishes → foods with `category = 'dish'`.
13. **Search:** `common_name` + one `is_default` row per common name + `food_aliases` (en/uk/de/fr). The `staples`
    map and `food_names` become data; order: exact alias → default rows → the rest by words and authority.
14. **Full nutrient panel** (list in `db/catalog/nutrients.tsv`).
15. **Gaps filled** from the same food in another table, then estimated from similar foods; every value marked
    measured / borrowed / estimated; not measured shows ≈.
16. **Health rules:** per-person reference values (DRI / EFSA, by sex, age, pregnancy, lactation), advisory
    condition limits (min/max, never blocking), condition foods avoid / limit / prefer; every row names its source.
17. **Pipeline:** `tool/catalog/` (uv, ruff, pytest), stages fetch → normalize → translate → match → fill → write,
    each cached and run alone under the 9 GB cap.
18. **No release gates;** host tests and pipeline tests pass.

Built (2026-10-19), `tool/catalog/` (README in each module's docstring; `uv run --with pytest --with openpyxl pytest
tool/catalog`):
- **fetch** (`sources.tsv`, `fetch.py`): CNF 2015 (OGL-Canada), Frida 5.5 (CC BY), Swedish Food Agency API (CC BY),
  Matvaretabellen (NLOD), AFCD R3 (CC BY), Swiss FCDB 7.1, MedQuAD (CC BY), DRI tables (Health Canada pages), EFSA
  DRV summary PDF. Out: NEVO (no charging users), WHO (NC), BLS 4.0 (no licence text; owner: leave out), RecipeNLG and
  the 2M Kaggle recipe set (NC), the "10k South Asian recipes" set (synthetic: random ingredients). By hand only (bot
  check): Fineli. No licence-clean recipe sets from Europe, Canada or NZ with servings were found.
- **normalize** (`readers/`): 12 government tables at the full panel (USDA SR Legacy, FNDDS, Foundation, CNF, Frida,
  Sweden, Norway, AFCD, Swiss, CIQUAL, CoFID, NZ), the v3 loaders for the smaller and branded files (`legacy.py`),
  Open Food Facts 2026 (2.03M), recipes through the v3 loaders (`recipes.py`, 500k raw), DRI (`dri.py`), MedQuAD.
  Units and rules in `normalize.py` (EU available carbs + fibre, RAE not RE, kJ, DFE else total folate, omega-3 sums,
  a per-nutrient maximum in nutrients.tsv drops wrong units).
- **match** (`match.py`, `names.py`, `match_recipes.py`): 41k generic foods, 13k defaults, 43.5k branded rows to
  products; recipes through the v3 matcher and ingredient_map.txt, translated to v4 rows: 168,642 kept (v3 170,951).
- **fill**: 1.43M values measured, 293k borrowed, 429 estimated.
- **translate**: everyday names → uk/de/fr aliases with TranslateGemma 4B (`db/catalog/aliases.tsv`, resumable, ~10.5k
  names, ~5 h). Machine translation: review the most-used names.
- **write**: nutri.db 339 MB + health.db 40 MB (recipe nutrition was a view to save 140 MB; stored again since the 800 MB limit, 2026-10-20), products.db 523 MB
  (2.08M). Doc embeddings not stored (search is FTS, as v3).
- **App**: schema 4 / data 5; health.db attached as `health`; `food_aliases` replace `staples`; dishes are foods
  (≈); products only from products.db; `Profiles.resetForCatalog` wipes old profiles' user.db once. Test fixtures:
  `python3 tool/catalog/test_db.py` (v3 dummy data converted). The app still shows the 14 v3 nutrients; the other 42
  are in nutri.db for a later UI step. The published products.db.gz is still v3's (works with this code): the v4
  file needs uploading to a new GitHub release before the URL changes.
- **Size limit raised to 800 MB** (user, 2026-10-20): recipe nutrition is stored again (`write.py` turns the view
  into a table); nutri.db 512 MB + health.db 40 MB. Over Play's 500 MB base module: a Play build needs an asset pack.
- **Translations done** (2026-10-20): 10,479 names × uk/de/fr. The 300 most used were reviewed by hand (~1 in 4 had a
  wrong word: lime → "mustard powder", turkey → "Turkish"); the rest is unreviewed machine output. A translated word
  goes to the food that owns the English name, once per language (most used first).

## All nutrients, patterns, model-first chat — decisions (user, 2026-10-20), in progress

Ships in the same release as Catalogue v4, after v4 is committed on its own.

**Status (paused 2026-10-20 by the user; resume here)**

Done:
- [x] Catalogue v4 finished and committed (b1cf4cc pipeline, 27e1f1e app): translations (top 300 reviewed by hand),
  alias ownership fixes, recipe nutrition stored (800 MB limit), all host tests pass, release APK builds.
- [x] Decision 5, fill every gap in nutri.db foods (a6b2287): no NULL left, `foods.sources` per value.

- [x] Decisions 1–4 (2026-10-21): meal_log has all 56 nutrients (user.db v14); NASEM goals (RDA, else AI) and ULs from
  health.db by sex, age, pregnancy/breastfeeding (a choice on the Goals form, a profile pref); "Over the limit" and,
  after the usual dinner time, "Low today" in the context block; `nutrition_status` gives the macros, the rest as % of
  goal, the ULs passed, and a card with the full table; All nutrients screen (day or week, history window), the
  Low/Over chip on Today, the vitamins card on NASEM goals (EU label % gone), micronutrient goals grouped and collapsed
  on Me; ≈ for values nutri.db estimated, ≥ for totals some meal doesn't know; names in 4 languages.
  Choices made on the way: the 7 macros keep the formula (personal kcal, protein per kg), NASEM gives the rest; "other"
  takes the mean of the female and male goals and the lower UL; no UL warning for magnesium, niacin, folate and
  vitamin E (NASEM: supplements and added forms only), and vitamin A's UL counts retinol (RAE − β-carotene/12); never
  "low": energy, fat, carbs, ceilings and totals some meal doesn't know; under 18 no automatic goals (as the kcal
  formula). Pregnancy does not change kcal yet (NASEM adds 340–450 kcal by trimester; the app doesn't ask it).
- [x] Decision 12, the part above: Free has the panel, the chip (protein and fibre can be low) and UL warnings;
  Basic adds the All nutrients screen, micronutrient goals (Me, the chat card, `nutrition_status`) and "Low today".
  The patterns' gating comes with the patterns.
- [x] Decisions 7–8 (2026-10-21, `lib/data/patterns.dart`): the seven patterns over the last 28 whole days (two meals
  or more and half the kcal goal; a half-logged day is never a low day), from the first log on, a week at least. The
  3 strongest in the context block (computed at the day's first message, kept in prefs), `my_patterns` with its card,
  a "Patterns" section in the weekly review. Basic: 1–6; Medium: symptoms after foods (≥ 5 times and at least half
  the times the food was eaten — a daily staple precedes every symptom — within 6 h, counts only, "you might mention
  it to a doctor"). Weight against intake gives both numbers, no verdict.
- [x] Decisions 9–10 (2026-10-21): the model decides every message (`Agent.modelFirst`, the router first again when
  false). `AgentTools.checkCall` holds the arguments against the user's words: every log_meal food was said (its own
  words, or an alias of its food in any language; a food without an alias in the app's language can't be told and
  passes), every amount was said (digits or a number word in 4 languages), a recipe number is in the list shown,
  a reading's number was said. One retry with the reason, then the router; the router also stands in when the model
  calls nothing it should have (not when it asked back). Water from log_meal goes to the water tracker. Every text
  answer gets the hidden check turn (`Agent.checkAnswers`): "checking…", ✓; WRONG → written again once with the
  reason; WRONG again → hidden, "couldn't verify", never replayed. Checks don't count. Cost on the phone: not measured
  yet (the gate prints it).
- [ ] Decision 11: the phone gate on the Xiaomi: `integration_test/phone_gate_test.dart` (the real Agent, the routing
  set plus the router's cases in en/uk/de/fr, `agent_queries_i18n.dart`; prints accuracy, wrong meals, retries and
  every step's time). Needs the phone connected; then the user's own phone test.
- [x] One release: v0.15.0 (2026-10-22).

Open, the owner's call (not blocking): upload the v4 products.db to a new GitHub release; a Play asset pack (the
bundled files are over Play's 500 MB base limit); check the
biotin of CoFID/Frida (see below).

Built 2026-10-20: **5** (all gaps filled; numbers and the estimator's held-back check in DATA_SOURCES.md). Web research
gave little beyond the tables: the USDA iodine database (a dataset, used whole) and the Staggs 2004 biotin table; NIH
ODS fact sheets quote USDA values already in the tables (and block downloads). Staggs found published biotin values
often several times too high, so the CoFID/Frida biotin that lends to similar foods may be high.

**All nutrients**
1. **meal_log stores all 56 nutrients** as columns, copied at log time (NULL = unknown). No migration: the v4
   upgrade already wipes user.db.
2. **Goals from health.db** (NASEM): RDA, else AI, by sex, age (birth month), pregnancy and lactation; editable
   like kcal. The ULs become upper limits with warnings. The 26 nutrients without a reference value are tracked,
   without a goal.
3. **Context block:** "Low today" (at most 5 by % of goal, only after the usual dinner time) and "Over the limit"
   (always), ~40 tokens. The full table through `nutrition_status` and its card.
4. **UI:** a new "All nutrients" screen grouped as in `db/catalog/nutrients.tsv` (any day, the week; goal bars, UL
   marker; amino acids and single sugars behind "More"); a Low/Over chip on Today; the Goals screen grouped and
   collapsed. NASEM goals replace the EU label % (`microReference`): one source of truth. 4 languages.
5. **Fill every gap in nutri.db foods** (571,796 NULL cells in v4), in order, each value with its provenance
   (per value, not per food): borrowed from the same food in a government table (reviewed name match, extends
   `fill.py`) → web research with a URL for the top ~200 foods (`db/catalog/manual_values.tsv`, wins over
   estimates) → estimated from similar foods (food group + close name, scaled by a related known value, e.g.
   amino acids by protein). Estimates show as ≈; a test scores the estimator on held-back real values. No values
   from an LLM's memory.
6. **Products keep their label values only** (no estimates: fortified products differ, and the download would
   grow); their unknowns show as "partly known" (≥ the known sum).

**Behaviour patterns** (SQL over 14–30 days, no model)
7. **All seven:** skipped meals; late eating; weekdays vs weekends; recurring nutrient gaps; logging gaps (so a
   half-logged day isn't read as a low day); weight trend vs intake; symptoms after foods (≥ 5 cases, counts only,
   never "causes", "you might note this to a doctor").
8. **Delivery:** the 3 strongest in the context block (refreshed at the day's first message), a `my_patterns`
   tool for all of them, and a "Patterns" section in the weekly review.

**Model-first chat**
9. **The model decides every message;** `route()` is no longer the first step. Code checks the tool arguments
   against the user's words (every food in `log_meal` was said; a recipe number exists in the list shown); one
   retry with the reason; then the old router logic as the fallback.
10. **Every answer is checked** by a second model pass, small talk included: a hidden turn in the same
    conversation ("check your last answer against these facts" → OK / WRONG: …). Answers stream with a
    "checking…" mark, then ✓. WRONG → regenerated once with the reason; WRONG again → the cards stay, the text
    is hidden, "couldn't verify this answer". Checks don't count towards Free's 30 messages. Expected cost:
    +3–9 s per answer, and the conversation is cut back every ~4–5 messages (+~300 tokens per check).
11. **Phone gate before shipping:** the routing set plus every case the router used to handle, in 4 languages, on
    the Xiaomi: ≥ 95 % right tool after check and retry, ≤ 1 % wrong meals logged, with timings per step. Failing
    it, the router stays first until the prompts are fixed.

**Tiers**
12. **Free:** all 56 tracked, the Low/Over chip, UL warnings (safety, like allergens). **Basic:** the All nutrients
    screen, micronutrient goals, the "Low today" line, patterns 1–6. **Medium:** symptoms after foods; its rule
    becomes "records, never interprets; shows how often symptoms followed a food, as counts, never as a cause".
    **All tiers:** model-first chat and the answer check.

Order: finish v4 (build, tests, phone, commit) → fill the gaps (pipeline) → meal log, goals, context, screens,
translations → patterns → model-first and the check → phone gate → one release.

## Drinks, store size limits, translation review (user, 2026-10-21), in progress — resume here

**Status (2026-10-22: shipped in v0.15.0; what's left at the end of this section)**

Done:
- [x] Drinks: nutri.db already had most drinks (government tables); the gaps were servings and a few kinds. New
  servings stage `tool/catalog/servings.py` (after fill): every drink gets a serving — USDA's own volume portions
  (`food_portion.csv`, CC0), else the median of drinks of the same everyday name, else the usual size of its kind
  (NIAAA standard drinks: beer 355, wine 148, spirits 44; can 330, cup 240, espresso 30); a table's "serving" over
  750 g (a litre carton) is reset. Tests: `tool/catalog/test_servings.py`.
- [x] Missing drink kinds from Open Food Facts medians (`db/catalog/drinks.tsv`, `readers/off_drinks.py`, source
  `off_median`, ODbL, ≥ 5 labels): kvass, diet cola, sugar-free energy drink, flavoured water, radler, IPA, drinking
  yogurt, hemp drink. Too few labels (EU alcohol needs no nutrition label) → aliases in defaults.tsv instead:
  prosecco/cava/sparkling wine, porter, limoncello, raki, ouzo; rooibos/yerba mate/mint/chamomile → herbal tea (OFF has
  the dry leaves); mors → cranberry drink; latte, americano, flat white, cold brew, still/mineral/sparkling water,
  wheat and alcohol-free beer, cola zero/coke zero/pepsi max/diet coke. No clean source: uzvar, kissel (OFF's
  "compotes to drink" are purée pouches).
- [x] Bug: translated aliases were stored as written ("Квас") and the app looks up lower case; SQLite NOCASE folds
  ASCII only, so every capitalised Ukrainian alias never matched. `write.py` now lowercases (test in test_names.py).
  `translate.wanted()` now also covers off_median drinks and every defaults.tsv alias; 44 everyday words that had no
  translation row (coffee, tea, eggs, potatoes, fries, …) were added.

To do, in order:
- [x] Translation review of `db/catalog/aliases.tsv` (10,546 names × uk/de/fr), done 2026-10-22: every row read
  and fixed for meaning errors, wrong words, Russian forms (long descriptive names: meaning only); unbalanced quotes
  repaired by script (uk → «», de/fr stripped). Common machine errors were "app." read as an app, "w/" lists, fish,
  berry and meat-cut names swapped (veal → beef, turkey → "Turkish", pear → peach), "ns as to" qualifiers, Swedish
  dish names. Not checked: whether every alias still reaches the right food after matching.
- [x] Rebuilt 2026-10-22 under the 9 GB cap (`normalize.py off_drinks` → `match.py` → `fill.py` → `servings.py` →
  `write.py <out> nutri health`; fill/servings/write need `uv run --no-project --with openpyxl --with numpy --with
  scipy`): nutri.db 41,075 foods, 168,642 recipes, 497 MB; health.db 40 MB; copied to assets/. `pytest tool/catalog`
  63 passed; all 24 host test files pass one at a time. Three defaults fixed in defaults.tsv before the final build:
  "calf" (most used by recipes, so it owned `телятина`/`veau`/`Kalb`) → "Veal, meat, cooked (average)" instead of a
  calf's head; coffee 240 g (the table said 480 g "1 medium"); turkey 150 g (the table said a 3.8 kg bird). An
  override's grams now drop the table's serving label. Committed on main as v0.15.0+18 (2026-10-22).
- [x] Store size — decided 2026-10-22: download on first run, shipped in v0.16.0 (see "What's left"). Background: Android base module limit is 500 MB compressed (Play; asset
  packs 1.5 GB each, 4 GB install-time total, 30 GB fast-follow/on-demand); the release APK is 490 MB compressed —
  nutri.db 205 MB, EmbeddingGemma 179 MB (stored uncompressed), native libs ~70 MB, health.db 12 MB. Recipes are
  ~430 of nutri.db's 497 MB (steps 109, ingredient lines 101 + indexes 54, recipe_nutrition 99). Recommended: an
  install-time asset pack with nutri.db, health.db and the embedder (installed with the app, offline; the app copies
  the files out on first run through a small platform channel); base drops to ~100 MB. Alternatives: download them
  like products.db; recipe_nutrition back to a view (−99 MB raw). iOS: 4 GB uncompressed app limit (fine), over
  200 MB only asks before a cellular download; big files can use Apple-hosted Background Assets (200 GB per app).
- [x] Release v0.15.0 (2026-10-22): GitHub release with the APK (490 MB), built by CI from build-inputs (nutri.db
  and health.db re-uploaded; the workflow now downloads health.db too).

**What's left (2026-10-22)**
- [ ] Phone gate, decision 11 (`integration_test/phone_gate_test.dart`): needs the Xiaomi connected; then the
  owner's own phone test of v0.15.0. Failing the gate (≥ 95 % right tool, ≤ 1 % wrong meals), the router goes
  first again (`Agent.modelFirst = false`) until the prompts are fixed.
- [x] Store size → **download on first run** (owner, 2026-10-22). The APK carries no data: on first run (and for a new
  `nutriDataVersion`) the app shows "Food data" and downloads nutri.db, health.db and EmbeddingGemma (≈367 MB gzipped)
  from the public release `data-<nutriDataVersion>` (`DataDownload`, `missingData` in `lib/app_state.dart`; each
  database has its own `<db>.data_version`, so a half-done update resumes where it stopped). CI fails if that release
  lacks a file; the build-inputs release is no longer read. Left: an upgraded phone keeps the old embedder copy that
  0.15 installed from the bundle in the plugin's folder (~179 MB, unused) — no cleanup yet.
- [x] Products v4: release `products-2026-10-22` (2,077,610 branded foods and menu items, schema 4, 166 MB gzipped);
  `productsUrl`/`productsDownloadMb` updated. Phones that downloaded the 2026-10-16 file keep it (it still works) until
  they delete and download again: no "update available" yet.
- [x] Biotin: `fill.py` applies db/catalog/manual_values.tsv (Staggs 2004) before the same-food step, and a researched
  value replaces the same food's (common name + state) measured values more than 3x off (`OUTLIER`): 94 values,
  e.g. banana 3.2 → 0.13, plain yogurt 1.1 → 0.13 µg/100 g median. Milk, v0.18: every table names plain cow's milk its own
  way ("pasteurised milk", "uht milk", "milk, cow, trim"), so a pattern row in manual_values.tsv (source `*`, a
  regular expression over the name) gives all 155 plain milks Staggs' mean, 0.11 µg (was 1.8–3.8).
- [ ] Food detector gates (Step 7): mAP on a held-out set of the owner's own meal photos, ≤ 150 ms per frame on the
  Xiaomi, the threshold (0.4) tuned on real meals. Needs photos and the phone.
- [x] Pregnancy kcal: the Goals form asks the trimester when "Pregnant" is chosen (pref `trimester`; pregnant before
  it was asked = 1st); the kcal goal adds 0 / 340 / 452 (`pregnancyKcal`, IOM/NASEM DRI 2005), and "lose" gives the
  maintain targets while pregnant, said in the form and the goal dialog (`pregnantNoLose`), as for underweight.
  Breastfeeding, v0.18: the form asks the baby's age (0–6 / 7–12 months, pref `baby_half_year`) and the kcal
  goal adds 330 / 400 (`lactationKcal`); losing stays allowed (the 0–6 figure already counts the usual loss).
- [x] Release v0.16.0: first-run download, products v4, trimester, biotin.

## Owner's ideas (2026-10-22; all six done the same day, 1 in v0.19)

v0.25 (same day), owner's reports: a spoken "I ate for dinner cottage cheese 160 g with pear 60 g" got "I've stored
your dinner…" and no card. Each voice message reopens the conversation (audio needs the main session), so the model
sees only a text replay with no tool calls in it and may answer in words; the fallback router then skipped any reply
ending in "?". Now only a reply that is just a question skips it; the router also takes "For dinner I ate…". Cook
mode used fixed dark colours: now the theme's. The base ThemeData is built from the colour scheme (dropdown menus
had the default canvas), menus sit on the card colour, and text is 8 % below the system size (`SmallerText`) so
menu items and buttons stop wrapping. Needs the phone: the voice turn end to end.
v0.25.1: on the phone the model answered "I had 2 eggs for breakfast" with lookup_nutrition ("Here are the numbers.")
three times in a row, and a tool call skips the fallback router: lookup_nutrition on a message that starts like a
meal report now logs it, as search_recipes already did. Seen too, not fixed: "wholegrain toast" matches "Gruel
wholegrain fortified" and "whole wheat toast" French toast (no everyday default for them in db/catalog/defaults.tsv;
needs a data rebuild), and "a slice of toast" is 100 g.
v0.25.2: the Plan week strip showed Sunday 25 October twice (the night clocks go back): midnight + 24 h steps landed
on 23:00 the same day. Plan, add-to-plan and the chart's date labels step with DateUtils.addDaysToDate; the data layer
already used DateTime(y, m, d + i).
v0.25.3: still wrapping on the phone at 92 % text: the recipe's macro tile ("Protei/n"), its "Log a serving" and
"Start cooking" buttons, and Log's "Snap a / photo". Those labels are one line now, shrunk to fit (FittedBox, as
StatTile's value already was).
v0.25.4: the original report, reproduced on the phone: "I had 2 eggs for breakfast" got "I have logged your breakfast of
2 boiled eggs and 40.0 g toast" (toast from an earlier message), no call, and the check passed it ✓. The fallback card
came (v0.25.0), but the false words stayed on screen and in the replay, where a reopened conversation (every voice
message) copies them. When the fallback card is a write (ConfirmCard), the reply goes from the screen and
chat_messages and is not checked, as after a second failed check.
v0.25.5: Today's water card showed "/ 2.25 L" with no amount: the litres format dropped a trailing zero meant for
"2.50", which also blanked "0" (and would show 10 L as "1"). Only a decimal's last zero goes now.
v0.26.0, data version 7 (release data-7): "wholegrain/whole grain/whole wheat/wholemeal/brown toast" (no food has those
words, so "Gruel wholegrain fortified" and "Whole Wheat French Toast" won) → CNF "Bread, whole wheat, commercial, toasted"
(33 g a slice); "multigrain toast" → CNF "Bread, multigrain, toasted", with "multigrain bread" pinned to the untoasted row
so its default doesn't move; "toast" 25 g a slice (was none, so 100 g). Applied to data-6's nutri.db by SQL (7 aliases,
one serving, meta.data_version) instead of a full rebuild: nothing in tool/catalog or db/catalog changed since that
build, and match.py's dry run with old vs new defaults.tsv differs in exactly those rows. Welcome, recipe search and
the plan said 55,000 foods and 166,000 recipes: 41,500 and 168,000 now (41,578 and 168,642 in data 7), README too.
Owner's request, same release: recipe steps (US-written: in 1.08M steps, bare "350 degrees" 39k, cups 37k, inches 36k,
°F 26k, 9" 10k, quarts 5k) in the user's units from Goals (`body.units`, metric when unset): `unitsFor` in data/cook.dart,
on the recipe page and cook mode, after any translation. Bare degrees count as °F from 250 up (no oven goes past
250 °C); "350F"/"180C" need 100+; explicit temperatures need 10+ and a whole number (the data has cups written "C"
turned into "3/4°C"); a pair ("375°F (190°C)", "325°F/160°C") keeps the figure already in the user's units; "2-1/2" is
2½; "3 - 9\" pizzas" is a count. Spoons stay. Under 20 g stays grams for imperial (steps' nutrition notes).
v0.26.1: ingredient amounts too (`amountIn`: the recipe's list, cook-mode chips, the shopping list): oz, lb from 16 oz,
tenths under an ounce. Nutrition values stay grams, as on US labels. A 12k-step sample: 1,783 changed, ~0.09 ms a step.

Camera, owner's request (v0.24, 2026-10-22): the shot frame is held (the stream stops replacing it)
and shown with its boxes while Gemma names it, in photo and live mode; gallery photos go through the detector too
(`_detectPng`, whole photo and four quarters). Review: photo on top in an InteractiveViewer, list in a
DraggableScrollableSheet; boxes only where the detector agrees with a food on the list (`boxesFor`: Gemma names,
a disagreeing box would confuse), a removed food's box goes. The chat photo card carries the PNG and boxes
(thumbnail, tap for full screen). Memory only. Needs the phone: real frames, box positions, Gemma timing.

v0.23 (same day): Eva on more screens, by mood (owner's request): a new chat (waving, with a greeting), the chat while it
answers (thinking), Today's "set your goals" card and Goals (sitting), the health journal (sleeping), too few
weigh-ins and no saved recipes (thinking), an empty shopping list (eating), a camera review with nothing found
(camera). A pose may serve several screens, never twice on one. Wanted next from the owner: Eva with a plate (Log),
a shopping basket (Shopping), a chef's hat (Recipes, Cook mode).

v0.22 (same day): Google Fit through Health Connect (owner's report): steps are the larger of Health Connect's combined
count and the largest app's own (the combined one takes each minute from one app, by Health Connect's priority list,
so a phone counter ranked above Fit hid Fit's steps); burnt calories from Fit's totals subtract the resting burn only
for the hours Fit's records cover (Fit syncs in batches; counted to "now" it went below zero and the ring stayed
empty). Settings → Your picture is one row opening a sheet (large preview, Picture / Colour / Shape tabs, scrolls with
pinned tabs at large text). Colours from the app icon: warm cream base, sage, peach and coral chips, the icon's forest
green for strong fills; all text still ≥ 4.5:1.

v0.21 (same day), reality check of the numbers (owner's request):
- the meal parser read "8 oz steak" as 8 servings and missed tbsp/tsp/l/lb/fl oz: they are now weights;
- the sugar limit is the EU reference intake for total sugars (18 % of kcal), since the tables give total sugars and
  WHO's 10 % is for free sugars only (fruit and milk days showed "Over");
- protein counts on the adjusted body weight above BMI 25 (BMI-25 weight + 40 % of the rest), not the whole weight;
- water: +300 ml in pregnancy, +700 ml breastfeeding (EFSA);
- the embedder copy 0.15 left in the plugin's Documents folder (~179 MB) is deleted once the downloaded one is in use.
Checked and right as they were: Mifflin-St Jeor and the activity factors, the kcal floors, burnt calories shown but not
added (the activity level already counts them), the weight trend (10 % a day smoothing), unit conversions, fibre,
sodium, the NASEM reference intakes and upper limits.

v0.20 (same day): the app icon is the owner's design (`assets/icons/app_icon.png`, 1024 px made from a 195 px
screenshot, so soft on iOS and in the Play listing; a full-size original would sharpen it): iOS AppIcon set, Android
legacy mipmaps and an adaptive icon (green #365F44 behind, the artwork in the 72 dp visible area). Every Eva picture
is lighter, salt-and-pepper grey as the real Eva (dark fur lifted, eyes, nose and outlines kept).

1. **Done 2026-10-22 (v0.19): photo in chat.** Built: a "Photo of your meal" chip first above the chat input (Pro,
   else the plans; not a fourth button in the input row, which squeezed the field on narrow phones) and the chat's
   own "Open camera" card both run the camera (shoot or gallery, Gemma's recognition, `capturePhoto` shared with the
   review screen); the foods come back as the chat's meal card (`photoMeal` in scan.dart): "seen: …" and "check
   this" per food, change / remove / amount / add, the meal, foods not in the list named, oil offered after frying,
   "What can I cook?", Save or Discard. Save logs, remembers the user's swaps for the next photo and records the
   scan. The Log tab keeps the full-screen review. Eva poses, one screen each: head (drawer), waving (welcome),
   sitting (food data download), sleeping (History empty), eating (Log search, no match), thinking (what the AI
   knows, empty), camera (the photo card). Asked for: Today chat only shows a CameraCard that opens the camera screen (`openCamera`,
   `lib/ui/camera_screen.dart`); recognition happens there, not in the conversation. Wanted: attach a photo (camera or
   gallery, `image_picker` is already a dependency) in the chat input, run the same recognition loop in the chat,
   show what was recognised (foods, grams, ≈ marks) as a card, let the user edit each item, and choose how to store it
   (log as a meal + which meal type, save as a recipe, or just ask about it). Reuse the meal confirm card
   (`_MealConfirm`/`ConfirmCard`) and the photo session (`openSession`) rather than a second pipeline.
2. **Done 2026-10-22 (v0.18): packaged products removed** (no barcode scanning, so search alone didn't earn
   523 MB). The download, its Settings section, the Log hint and the product search are gone; phones delete an old
   products.db at start. The 503 chain menu items moved into nutri.db as foods (data version 6). Was asked:
   **Packaged products: needed?** Where they are used now: Settings → "Packaged products" download
   (`settings_screen.dart`, `productsDownloadProvider`); once downloaded, Log search and the chat's food lookup show
   matching products after generic foods (`AgentTools.search`, products_fts, 8 hits, every word must match); the Log
   screen hints at the download when a search finds nothing. Not used: barcodes (no scanner), photos, recipes. To
   decide: keep and make it useful (barcode scan on the Log screen and in chat → exact label; a brand chip in
   results; "update available" for a newer release; maybe only the user's country to cut the 523 MB), or drop it.
3. **Done 2026-10-22: more profile looks.** Built: 17 icons (3 named person icons + 14 more), 18 colours,
   background solid / gradient / soft wash, shape circle / rounded / hexagon / flower, outline none / thin / thick;
   shape and outline apply to a photo too (prefs `avatar_shape`, `avatar_style`, `avatar_ring`; `UserAvatar`,
   `AvatarChoices` in `avatar.dart`). Asked for: Today: picture = woman / man / neutral icon on a colour, or a photo (`avatar.dart`,
   Settings). Wanted: more options — more icons and colours, background, outline (contour) and shape (circle,
   rounded square, …).
4. **Done 2026-10-22: light theme less bright.** Built: background #E8EEEA, cards #F6F9F7 (no pure white),
   chips and borders a step darker; accents darkened just enough to keep ≥ 4.5:1 on the new background
   (`test/theme_test.dart` checks every text colour on background and cards, icons ≥ 3:1 on their tint, both
   themes). Dark theme, same day: text off-white at L* 90 (was 95, glare on black), cards one tone above the
   background. Not done: golden screenshots per screen. Asked for: light theme too bright (too much white: `AppColors.light` has `surface: Colors.white` on a near-white
   `background`). Rework from researched practice: tinted neutral surfaces instead of pure white (Material 3 tonal
   surfaces / surface containers from the seed), fewer elevation levels told apart by tone, WCAG AA contrast kept for
   text (4.5:1) and UI parts (3:1); check every screen in both themes (golden tests).
5. **Done 2026-10-22: drawer.** Built: "Go to" with the five tabs (current one highlighted, Eva on Chat), All
   nutrients under Track (Basic, else the plans), Photo of a meal under Food (Pro, else the plans). Asked for: Today: Weight, History & year, Goals, Health, Saved recipes, Shopping list, What the AI
   knows. Add navigation to the tabs too (Today, Chat, Log, Plan, Me) and anything else reachable only by deep taps.
6. **Done 2026-10-22: Eva in more places.** Built: `assets/icons/eva_cutout.png` (icon_chat.png without its disc,
   by code), `EvaCutout` and `EvaNote` in `avatar.dart`; Eva peeks from the drawer header, sits beside the logo on
   the welcome screen, and fronts the empty states (what the AI knows, shopping list, saved recipes, history, Log
   search with no match, health journal). The unlock screen already had her. Poses from the owner (3 images,
   cut off their paper and floor, 384 px): `eva_waving.png` on the welcome screen, `eva_sleeping.png` on the
   "nothing yet" notes, `eva_eating.png` on no food found / nothing to buy / no saved recipe. Asked for: Eva the drawer header, empty states, the unlock/login
   screen; new poses/forms of the picture generated from `assets/icons/icon_chat.png` (e.g. waving, sleeping for empty
   states, holding a bowl). Keep it small and where space is free; one style across them.

## v0.11.0 (2026-10-18): My Nutrition AI, voice, Eva, avatars, widget sizes, Google Fit calories

- **Name:** "My Nutrition AI" everywhere users see it; the GitHub repo is `My_Nutrition_AI`. App ID, Dart package,
  `myfoodmind://` deep links and method channels stay (a new ID would be a different app: no data, no update).
- **Voice input (chat):** Gemma 4 E2B transcribes (its audio encoder; model loaded with `supportAudio`, retried
  without it if that fails). `record` writes 16 kHz mono WAV to the temp dir, deleted after reading; ends on a tap,
  2 s of quiet after speech, 8 s of nothing, or 30 s. Own session (`openSession`), like photo mode. The transcript
  is sent as the user's message, so the crisis check, routing and the meal card still apply. Search fields and a
  model without audio keep Android's on-device recognizer. Still nothing leaves the phone.
- **Voice answers:** `flutter_tts` with installed offline voices only (`network_required` voices skipped), after a
  spoken message; Settings → Voice: on/off, woman/man (per phone). Man/woman by Google voice codes; one voice for
  a language (Ukrainian) → pitch 0.75 / 1.0.
- **Eva:** `assets/icons/icon_chat.png` (the developer's miniature schnauzer) is the assistant: chat messages, the
  Chat tab, a badge on the unlock screen's avatar.
- **User picture:** woman / man / neutral (they/them) icon on a colour, or a photo (system photo picker, 512 px,
  in the profile folder, new file name per change). Per phone in profiles.db settings so the unlock screen shows
  it; cleared with the profile. Picked at sign-up, else follows the goals' sex (other → neutral) until picked.
- **Widget:** one resizable widget, three layouts (small: line + mic; medium: + Log; large: + progress and kcal
  left). Android 12+ chooses by size itself; 10–11 in `onAppWidgetOptionsChanged`. Mic → `myfoodmind://voice`:
  after the unlock the chat starts listening; the meal card is the check before anything is saved. Taps are
  heard by `AppGate` (also while locked); a mic tap older than 2 minutes is dropped. No background logging:
  Android blocks the microphone without a visible app, and the PIN lock stays.
- **Health Connect:** also reads `TotalCaloriesBurned` (Google Fit writes no active calories). Burnt = max(active,
  total − Mifflin-St Jeor resting kcal × share of the day gone). Phones connected before are asked once for the
  new permission. Steps were already Health Connect's de-duplicated aggregate; a different count than Fit's comes
  from Health Connect's source priority (Health Connect → Data and access → Steps).

### Photo recognition, same model (2026-10-18)

- The chat is never touched: photos run in their own `openSession` (no tools, own prompt); the model is not
  fine-tuned (LoRA isn't supported on `.litertlm` anyway). Check with `integration_test/agent_eval_test.dart`.
- Prompt asks `grams | name | cooking` with size references (plate 26 cm, fork 19 cm, bread slice 30 g).
- Two looks: the whole photo and a closer crop (around the detector's food boxes, or the middle 60 %). What both
  see is sure; what only one sees is marked "Check this"; crop-only foods get a serving, not Gemma's grams.
- Second question in the same photo session: per food up to 5 nutri.db rows, Gemma answers by letter;
  "none" keeps the guess, marked to check. Rows the user logs most come first, then the shortest name.
- Fried or roasted → the review offers "Cooked with oil or butter?" (unticked; adds the staple oil, 14 g).
- Corrections: "Change" on the review, saved when the meal is logged (user.db v12 `food_corrections`), makes
  that row the match for that seen name next time (no second question for it).
- 12 GB phones: E4B is listed first as Recommended (better at photos). Its tool accuracy is still unmeasured.
- Cost: a photo now takes two vision passes and a short text pass, so a few seconds more; Cancel still works.

### Step 7: own live food detector — decisions (user, 2026-10-18), not built yet

- **Model: YOLOX-Tiny** (Megvii, Apache 2.0; 5M params, 416 px), exported to TFLite (int8, calibrated) for the
  `tflite_flutter` runtime the app already uses, behind the `Detector` interface; replaces EfficientDet-Lite0.
  Not Ultralytics (AGPL-3.0, paid licence for closed apps). RF-DETR Nano (Apache, litert-community port) is the
  fallback if accuracy is short, but it needs LiteRT's CompiledModel runtime through a new native bridge.
- **Classes: fine ingredients + coarse foods + dishes** (e.g. tomato, bread white, rice, salad, pizza, soup).
  Each class maps to one reviewed nutri.db row in a table (like `staples`), not to search: search ranks branded
  products first ("Strawberry" → a gummy). Coverage check against the real nutri.db (crude matcher, lower
  bounds): Open Images 58/76 clear, 15 fuzzy, 3 missing; Nutrition5k 411/555 clear, 131 fuzzy, 13 missing.
- **Data, licence-clean only (paid app):**
  - MyFoodRepo / AIcrowd Food Recognition (CC BY 4.0 per the authors' paper): real meal photos, polygons → boxes;
    v2.0 has 39,962 training images, 498 classes. Download needs an AIcrowd login (the user).
  - Open Images V7 food boxes (annotations CC BY 4.0; Flickr images CC BY 2.0, per-image licence to check).
  - Nutrition5k (Google, CC BY 4.0): overhead plates with ingredient names and grams, no boxes → auto-labelled.
  - Own meal photos, auto-labelled on the PC with OWLv2 / Grounding DINO (Apache 2.0), checked by hand.
  - Not used: FoodSeg103 (its Apache 2.0 covers the code; the image licence is not stated), Food-101 (use beyond
    fair use must be negotiated with the photo owners), UEC FOOD-256 (licence unconfirmed), Objects365
    (listed as non-commercial). Attribution for CC BY data goes into Settings → Licenses.
- **Labels (first review, 2026-10-18): `db/detector_labels.tsv`.** The 498 MyFoodRepo classes (Food Recognition
  2022 v2.0 from the Kaggle mirror, COCO format, 39,962 training images) merged into 164 labels, each with ≥ 50
  boxes and one nutri.db row (government tables; cooked forms where food is eaten cooked; water logs nothing).
  Nothing dropped: an unlabelled object would teach "not food". `tool/detector_classes.py` drafts matches and
  checks the file (every class once, every row present).
- **Training: this PC's RTX 4070 Laptop (8 GB)**, run alone and memory-capped (the 14 GB box OOMs otherwise).
- **Gates before it ships:** mAP on a held-out set of own meal photos above EfficientDet's; ≤ 150 ms per frame
  on the Xiaomi 11T at 2 FPS; review-screen label quality checked on real meals.
- **In the camera (user, 2026-10-19), before the held-out gate:** `YoloxDetector` replaces EfficientDet (kept for
  the benchmark). CPU, 2 threads; frames scaled to fit 416 with their shape kept (letterboxed, as trained); photo
  mode searches the frame tiled (`photoTiles`); each label logs its reviewed row from `detector_labels.tsv`
  (`AgentTools.named`), search only if the row is missing; water logs nothing. Threshold still 0.4, not tuned.
- **Fixed (phone report 2026-10-19): voice input always "Nothing heard", photo naming always failed, so spoken
  answers never came.** flutter_edge_ai_litertlm 1.11 rejects images and audio on `openSession` (UnsupportedError,
  caught and shown as those messages). Both now use `createSession`, which ends the chat's conversation, so they
  call `Agent.release()` first (waits for a warm-up or turn; the chat reopens with its history).

## v0.10.0 (2026-10-17): new design (docs/New_Design), light and dark

- **Tokens** (`theme.dart`): the design's dark palette (background, surface, surfaceHigh, heroSurface) and one
  colour per nutrient and per meal (breakfast amber, lunch green, dinner violet, snack coral), read with
  `context.nutrientColor` / `context.mealColor`. Light keeps the roles with darker hues (each ≥ 4.5:1 on
  white). Type: Plus Jakarta Sans (OFL), Onest as its fallback for Cyrillic; scale `AppText` (display 30/800 …
  caption 12/500). Radii cards 20, hero 24, tiles 14, chips 12; gutter 16; app bar 64, nav 76.
- **Kit:** `IconTile` / `MealIcon` (tinted squares), raised-tab `PillTabs`, smaller `ScreenHeader`.
- **Today:** ring split by macro share, coloured macro bars, Goal · Eaten · Burnt · Left; fiber/sugar/sodium
  tiles; "Meals · n of 4 logged" with one-row meal cards (tap to open the items, "+ Add" in the meal's colour,
  "Suggested ~kcal"); water and steps cards; weight card with the 30-day line; **Vitamins and minerals** card
  always shown (Basic: all seven, lowest first; Free: a teaser to the plans); "Rate what you ate" + History.
- **Drawer:** profile hero with plan, Left today · Water · Weight, Track and Food sections, Settings and Lock.
- **Me:** profile hero (height, weight, born, goal row), Energy with the macro split, macro tiles, target list,
  links with coloured icons. The water goal is edited here only (500–6000 ml).
- **Plan:** green day chips, "Your whole week, planned in one tap" hero, placeholder meals before planning.
  **Recipes:** amber "What can I cook?", recipe tiles with kcal / time / high-protein / stars chips,
  "Ideas for your dinner" (`mealIdeas`, the plan's picker sized to what's left today).
- **Settings:** icon tiles per row, language picker dialog, meal-coloured reminder times; water goal and
  "What the AI knows" moved out (Me, drawer).
- Not done: the search (Settings) and filter (Plan, Recipes) header buttons, no feature behind them yet.

## v0.9.0 (2026-10-17): fix what the AI got wrong, Undo, burnt ring, Health Connect, History

From the UI/UX audit (canvas "MyFoodMind UI/UX Audit") and phone testing.
- **Meal editor** (`lib/ui/meal_editor.dart`), shared by the chat meal card and the photo review: tap a food
  to swap it, × removes it, "+ Add item", ± half servings. Each row owns its grams field (keyed per item):
  the review used to show a stale amount after a remove or a changed food and log a different one. Rows
  show "seen: …" (what the AI read), unmatched items come first.
- **Undo** on every log (Log, quick add, yesterday's meal, photo review) and on a saved chat card
  (`lastMealId` / `undoMealsAfter`); a saved card also links to Today to edit.
- **Weight:** a weight saved in the Goals form is also a reading, so the trend sees it (it only updated
  the profile before: "log at least twice" after three days). The hint says "on two different days".
- **Health Connect / Apple Health:** also reads active calories. Shown as an inner "Burnt" ring in the hero
  (target 300 kcal), never added to the goal (the activity level already counts a typical day). Steps
  refresh every minute and when the app returns; the steps tile opens a sheet (what's read, last sync,
  Sync now, Disconnect); disconnect revokes access on Android.
- **Today:** ≈ on the totals (and the home widget) when a meal is estimated; over the goal in coral, not
  Pro gold; water · fasting · steps · weight in one tile block; vitamins as amounts behind one row; a History
  link; a card offering the AI download; the welcome text names only what works now (Chat with the AI,
  photos with Pro). "Get an idea" waits for the AI instead of dropping the message.
- **Log:** search first, photo and quick add as compact buttons; quick add is a bottom sheet, kcal first.
- **Camera:** "Choose photo" from the gallery (`image_picker`; the picker's cache copy is deleted, the photo
  stays in memory); a Cancel overlay while Gemma names foods; Open settings / Try again when the camera is
  denied (`myfoodmind/system` channel); live labels without detector percentages; kit buttons.
- **Chat:** a "Thinking…" row; "Search foods in Log instead" while the AI downloads or starts.
- **History** redesigned: Meals (day cards) and Recipes cooked (count, last date, opens the recipe).
- ☰ on every tab; Goals and Timeline use `ScreenHeader`; Weight's sync shows progress and the result.
- Not done: the type/spacing scale (needs device screenshots first).

## v0.8.2 (2026-10-16): phone-test fixes, colour, drawer, year view

- **Crashes:** leaving the camera (back, or after Continue) freed the EfficientDet interpreter while a live
  detection was still running in its isolate (native crash). `TfliteDetector.close()` now waits for it; live
  detection pauses while Gemma names the foods.
- **Water:** the "Glass added · Undo" snackbar stayed forever (an action makes it persist by default); now it doesn't.
- **Unlock:** the PIN field is always light-themed (dark text on white), its label stays inside the field, and
  Unlock is a gold button so it no longer looks like a second field.
- **Colour:** each meal on Today has a colour and icon (breakfast amber, lunch green, dinner indigo, snack
  coral) with a wash on its card; the calories hero and drawer header are a green-to-teal gradient; water,
  fasting and steps tiles are tinted.
- **Drawer is back** (menu button on Today, or swipe): the tabs, Weight, History, Goals, Health, Settings, Lock.
- **Year view** as in `Year view (new).png`: the calendar year (Jan–Dec), months in a 4 × 3 grid of week rows.
- **Weight:** logging again the same day replaces that day's reading (a typo was otherwise stuck in the trend);
  20–350 kg (44–770 lb) only; kg per week to two decimals; range pills fill the width as in the design.

## v0.8.1, data v4 (2026-10-16): European food tables

- **New sources:** ANSES-CIQUAL 2025 (France, Licence Ouverte 2.0, 3,243 foods) and McCance and Widdowson's
  CoFID 2021 (UK, OGL v3, 2,632 foods), both authoritative (`authority()` = 2) with all seven micronutrients,
  many of them European dishes (quiche, moussaka, toad in the hole…). Credited on the app's licences page.
- **Carbs convention:** both tables give available carbohydrate (fibre excluded); the build stores carbs +
  fibre so `carbs_g` is a total everywhere, as in USDA (CIQUAL cloves 31.6 + 33.9 = 65.5 g = USDA).
  Reviewed 2026-10-16: high micronutrient values are real (dried seaweed, cream of tartar, liver).
  Hugging Face had no better option: its European recipe sets are small or scraped with unclear licences.
- **Not added:** Fineli (Finland, CC BY 4.0) sits behind a Cloudflare browser check; download the open-data
  zip by hand into `raw_eu/fineli/` to add it.
- **Size contract 400 MB** (was 300): the budget no longer drops any recipe; the build is 308 MB with
  61,415 foods and 170,951 recipes. On the phone the asset plus its installed copy cost about twice that.

## v0.8.0 (2026-10-16): redesign

The design lives in `docs/MyFoodMind redesign.html` and `docs/MyFoodMind redesign-png/` (19 screens).

- **Design system:**
  - Onest font, bundled (OFL, static 400/500/600/700).
  - A warm paper and deep green palette (`AppPalette` in `lib/ui/theme.dart`), with a dark variant derived from
    it. Wallpaper colours are still an option.
  - Shared widgets in `lib/ui/kit.dart`.
- **Navigation:**
  - The bottom bar is Today · Chat · + (Log) · Plan · Me. The drawer and app bar are gone (drawer back in v0.8.2).
  - History is in Today's periods and in Me; health, the AI memory, settings and plans are in Me.
- **New screens:**
  - First run in three steps: name (or Google), PIN and fingerprint, then goals. Goals come last because they
    live in the profile's own database.
  - A green unlock screen.
  - The Plan hub (Plan · Recipes · Shopping) with the recipe box and "What can I cook?".
  - A recipe screen with servings scaling, add to plan and log a serving.
  - Cook mode: steps from the numbered instructions, the timer each step names, the ingredients it uses, and the
    screen kept on through the `myfoodmind/screen` channel in `MainActivity`.
  - A weight trend screen (a 10 % daily exponential average).
- **New behaviour:**
  - Shopping items get an aisle (keywords on the English food name) and "For: recipe" (user.db v11).
  - Change PIN.
  - Link or unlink the Google account.
  - Add an allergy or diet from "What the AI knows".
  - Delete a meal from its edit sheet.
- **200 % text:**
  - Fixed headers and tabs are capped at 1.5× text.
  - At large text, chat's header and disclaimer scroll with the conversation.
  - A header's trailing item goes under the title.

