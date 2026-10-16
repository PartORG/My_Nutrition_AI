# MyFoodMind — Plan

Agreed 2026-10-04 in a grilling session. Decisions here are binding; change them
by editing this file deliberately, never by silently diverging in code.

## Product

| | |
|---|---|
| Name / ID | **MyFoodMind** · `io.github.partorg.myfoodmind` · Dart package `myfoodmind` |
| Goal | Commercial, **Android-first** (iOS later), English v1 with `flutter_localizations` + `.arb` from day one |
| Promise | All AI and data on the phone. No analytics/crash SDK — Play vitals + RevenueCat dashboard only |
| Min device | Android 10 (API 29)+, arm64, **≥6 GB RAM** (decided 2026-10-04 for Gemma 4 E2B) — Play device-catalog exclusion + in-app RAM check |
| Audience | Declared 18+. One profile per phone (v0.7.0), so no child profiles; under 18 → manual targets only |
| Privacy policy / ToS | GitHub Pages: `https://partorg.github.io/myfoodmind/` (includes Gemma use-policy terms for EmbeddingGemma; Gemma 4 is Apache 2.0) |

## Tiers — one subscription per phone

| Tier | Includes |
|---|---|
| **Free** | AI chat **30 user messages/day** (counted per phone, resets local midnight), recipe search, meal logging, saved/liked recipes, **allergen filtering (always free)**, today's dashboard, **weekly/monthly dashboard** (calories per day, averages, week review, weight trend), fingerprint/PIN lock, meal reminders, **History: last 30 days** |
| **Basic** | Unlimited chat, **meal plan + shopping list**, **water reminders**, micronutrients, streaks, **History: 90 days** |
| **Medium** | + Conditions (diabetes, ALS, MS, …): rule-based filtering & limits, symptom + reading journal, timeline charts, doctor export (PDF/CSV). **Records, never interprets**. **History: 240 days** |
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

Rules: recipe nutrition is computed, never stored · additive changes need no version bump ·
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
  it instead of falling back to online recognition (keeps "nothing leaves the phone").
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
2. **Live — own small detector** ⏳. YOLOX / RT-DETR / D-FINE (Apache; no Ultralytics/YOLO-World, GPL/AGPL)
   → TFLite behind the `Detector` interface, ~100–200 coarse classes (pasta, rice, salad, soup, …); the
   shutter's Gemma pass refines names. Data: FoodSeg103 (Apache 2.0, masks → boxes), Open Images V7 food
   classes (CC BY boxes; check image licences), own meal photos; UEC FOOD-256 for experiments only until its
   licence is checked; auto-labelling with OWLv2 / Grounding DINO (Apache 2.0) on the PC, distilled into the
   small model. Open question: training GPU (local NVIDIA vs Colab/Kaggle).

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
  - The bottom bar is Today · Chat · + (Log) · Plan · Me. The drawer and app bar are gone.
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

