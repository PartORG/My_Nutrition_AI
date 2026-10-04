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
| Audience | Declared 18+. Child profiles are created by a parent and use manual targets only |
| Privacy policy / ToS | GitHub Pages: `https://partorg.github.io/myfoodmind/` (includes Gemma use-policy terms for EmbeddingGemma; Gemma 4 is Apache 2.0) |

## Tiers — one subscription per phone, unlocks all profiles

| Tier | Includes |
|---|---|
| **Free** | AI chat **15 user messages/day** (counted per phone, resets local midnight), recipe search, meal logging, saved/liked recipes, **allergen filtering (always free)**, today's dashboard, multiple profiles, reminders |
| **Basic** | Unlimited chat, weekly/monthly dashboard, micronutrients, streaks, weight trend (logging weight is free) |
| **Medium** | + Conditions (diabetes, ALS, MS, …): rule-based filtering & limits, symptom + reading journal, timeline charts, doctor export (PDF/CSV). **Records, never interprets** |
| **Pro** | + Camera: photo / live video / barcode → review & edit screen → "What can I cook?" or "Log this meal" (user confirms portion, values shown as ≈). **7-day free trial** (Play offer) |

- RevenueCat, anonymous device user, entitlements `basic ⊂ medium ⊂ pro`, one `has(tier)` check.
- Tier changes use RevenueCat product change (replacement + proration) — never double charge.
- **M4 decisions (2026-10-04):** monthly + yearly per paid tier (Pro trial unchanged); weight logging is free
  (goals use the current weight), the weight trend chart is Basic; no store/RevenueCat accounts yet, so a
  developer tier switch stands in until they exist.
- Chat limit table in code: `free: 15, basic+: unlimited`. Bypass by clearing app data is accepted (wipes data too).

## Architecture

**Rule: the model routes and words; code computes; the database answers.** Numbers, recipes and
medical notes are rendered as cards from the database, never as model-generated facts.

- **Agent model:** **Gemma 4 E2B** (`gemma-4-E2B-it.litertlm`, 2.6 GB, Apache 2.0, ungated) via `flutter_gemma`,
  GPU with CPU fallback, native tool calling. Chosen in M0 (95.2% tool accuracy on device); also multimodal,
  so it is a candidate to replace the photo detector for Pro later. Runtime budget ≈2 GB RAM.
- **Tools:** plain Dart functions over SQL returning structs (see `lib/agent/tools.dart`).
- **Embeddings:** EmbeddingGemma 512 (768-d). Fixed prefixes: query `task: search result | query: {q}`,
  document `title: none | text: {t}`. Same model + prefixes on PC and phone.
- **Search:** SQLite FTS5 (foods, recipes, dishes, products) + brute-force cosine over `docs` and
  episodic vectors, merged with RRF. ObjectBox only if measured slow.
- **Vision (Apache stack, no Ultralytics/AGPL):** `tflite_flutter` + EfficientDet-Lite0 (COCO) for dev;
  real food/dish model trained with D-FINE / RT-DETR / YOLOX → TFLite, labels = `foods.name`/`dishes.name`.
  Barcode: ML Kit. Everything detected goes through the review screen before use.
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
models/                    LLM + embedding + detector, not backed up
profiles.db                profile list, PIN hashes, chat counter
profiles/<id>/user.db      private data, PRAGMA user_version migrations (add-only, one transaction)
vectors/<id>.db            episodic embeddings, not backed up, rebuilt after restore
```

Backup is **include-only** (`android/app/src/main/res/xml/`): `profiles.db` + `profiles/`. Everything else
in the app folder — nutri.db, models, flutter_gemma's ~800 MB GPU caches, vectors — stays out, because
going over Auto Backup's 25 MB quota silently stops all backup.

- Profiles: PIN (4–6 digits, salted hash) + biometric; unlocked until 5 min in background;
  growing lockout after 5 wrong tries; forgot PIN = delete profile; monthly doctor-export reminder.
- Delivery: dev = dummy `nutri.db` as asset, models via `adb push`; prod = Play Asset Delivery fast-follow
  (verify the 2.6 GB single-file limit), else first-launch download from Hugging Face (ungated, free).

### nutri.db data contract (owner: Ievgen builds real DBs to this)

`meta(key, value)` — `schema_version`, `embedding_model`, `built_at` ·
`foods` (per 100 g: kcal, protein_g, fat_g, carbs_g, fiber_g, sugar_g, sodium_mg) ·
`recipes(id, title, instructions, servings, minutes, tags, texture)` ·
`recipe_ingredients(recipe_id, food_id, grams)` · `dishes(id, name, serving_g, recipe_id NULL, + per-100 g nutrition)` ·
`products(barcode, name, + per-100 g nutrition)` · `allergens(food_id, allergen)` ·
`conditions(id, name)` · `condition_rules(condition_id, nutrient, max_per_day, note)` ·
`docs(id, source, text, embedding BLOB float32[768])` + FTS5 tables.

Rules: recipe nutrition is computed, never stored · additive changes need no version bump ·
docs chunks ≤ 512 tokens, ≤ ~50k docs · `nutri.db` ≤ 300 MB · data licensing is the data owner's job.

## Milestones

| # | Goal | Done when |
|---|---|---|
| **M0** | ~100 labelled queries; compare candidate models on the phone; check chat + embedding models load together | ≥90% tool accuracy ✅ (Gemma 4 E2B 95.2%); in-app latency and RAM with both models recorded |
| M1 | Skeleton, `schema.sql` + dummy DB, profiles + PIN, migrations, PC-vs-phone embedding check | Tests pass ✅ (22 host tests + on-phone checks) |
| M2 | Agent, tools, 4-type memory, chat limit, confirmation cards, report button | Eval runs as on-device `integration_test`; unit tests use a fake model ✅ (54 host tests; 105-query re-run with the new prompt skipped by user decision) |
| M3 | Onboarding/goals, logging, dashboard, reminders, accessibility | Goal formula test with reference values ✅ (77 host tests) |
| M4 | RevenueCat, Basic dashboard, weight logging, tier changes, Pro trial | Sandbox buy / upgrade / restore ⏳ code done + dev tier switch (88 host tests); sandbox test waits for the accounts: `docs/BILLING_SETUP.md` |
| M5 | Medium: conditions, journal, timeline, doctor export | No forbidden ingredient for a given condition |
| M6 | Pro: tflite detector + barcode → review → cook/log | Full flow with dummy detector + products |
| M7 | Asset Delivery, privacy policy + ToS + Gemma terms, Data safety, trademark check (EUIPO/USPTO class 9/44) | Internal-testing build installs and runs |

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
  (stdlib only, atomic, checks foreign keys and meta). Dummy data: `db/nutri_dummy.sql` → `assets/nutri.db`.
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
  is); adding a second profile turns it off for everyone. profiles.db v2.
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
  days, streak, weight trend) from Basic; logging weight is free.
- Paywall: price and renewal terms next to every button, Pro "7 days free, then …", restore.
- Not verified: real purchases (no accounts yet). Setup checklist: `docs/BILLING_SETUP.md`.
