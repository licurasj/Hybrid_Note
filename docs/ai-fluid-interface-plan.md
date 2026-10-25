# AI Fluid Interface: Feasibility & Plan

Status: proposal, nothing implemented. Written against commit `568cc9d`. Revision 2 adds the agreed
gesture spec, Decisions API scenarios, backend setup, and a bug/sync evaluation.

## 1. Verdict up front

**Feasible, but the hard part is not the AI and not the circle menu. It is the data model and
sync.**

Today every list type is a hand-written Dart class, a hand-written screen, hand-written cubit
methods and a hand-written Drive merge function. For the app to build list types on the fly, all
four layers have to become generic and data-driven. Once that's done, the radial launcher is a
self-contained widget, and the AI prompt bar is a thin layer that writes JSON the app already knows
how to render.

Decisions made so far:

- The AI **picks and configures** components the app ships with. It never generates UI code.
- Launcher: a ~200° arc of sticker notes with a pinned "+", hold-and-drag plus a tap mode with
  arrows (Section 5).
- A backend is needed (AI key proxy, and possibly sync). Its setup is part of the plan (Section 7).

Rough effort for one developer who knows this codebase (guesses, not measurements):

| Phase | What | Rough size |
|---|---|---|
| 0 | Two data-loss fixes | 0.5–1 day |
| 1 | Choose sync approach; stand up backend (Firebase or Worker) | 3–5 days |
| 2 | Generic list engine + port the 4 built-in lists + new sync | 4–6 weeks |
| 3 | Radial sticker-note launcher (hold + tap modes) | 1–2 weeks |
| 4 | Manual list editor (the "edit" target) | 1–2 weeks |
| 5 | AI prompt bar (generative model via backend) | 2–3 weeks |
| 6 | Optional: Decisions API router / auto-classification | ~1 week |

Phases 0–4 give a useful app with **no AI at all**. The manual editor comes before the AI because
AI output has to land in something a person can inspect and fix by hand.

## 2. Design decisions and remaining caveats

1. **AI configures, doesn't create.** Flutter can't load new Dart code at runtime, and the app
   stores forbid downloading executable code. The app ships a fixed vocabulary of field types,
   views and behaviours (Section 4). The AI only outputs a declarative list definition (JSON)
   built from that vocabulary. *Agreed.*
2. **Decisions API = classifier, not generator.** It returns probabilities, choices among options
   you supply, and rubric scores. It can't design a list or pull items out of a sentence.
   Concrete uses are in Section 6.4. *Agreed.*
3. **Edit gesture = dwell with visible progress.** Hold still on a note for about 1 s while a ring
   fills; release after it fills to edit. The visible ring and the "only while still" rule remove
   the accidental-trigger problem raised in revision 1 (Section 5.1). *Agreed.*
4. **Arc capacity is about 6–9 notes** (estimate, depends on screen width), so edge auto-scroll is
   normal use. The "+" is pinned at the right end so it's always reachable without scrolling.
5. **"Reminders" are stored, not delivered.** There is no notification plugin, so `reminderAt`
   never fires. The vocabulary's `dateTime(reminder)` field needs `flutter_local_notifications`
   (scheduled on-device, works with any sync choice), or it should be labelled "due date".
6. **Six target platforms.** Tap mode with arrows and keyboard support (Section 5.2) covers mouse,
   keyboard and screen-reader users. That may make a separate grid fallback unnecessary; test it
   with TalkBack/VoiceOver before deciding.

## 3. What exists today (must all survive)

### 3.1 List types and their data

| List | Model | Fields | Built-in behaviour |
|---|---|---|---|
| Tasks | `TaskItem` + `SubtaskItem` (`lib/task_item.dart`) | title, description, isCompleted, category, subtasks[], reminderAt, repeatFrequency (none/daily/weekly/monthly/yearly/custom), customRepeatDays | Categories with counts and filter chips; default "All My Tasks"; clearing a completed repeating task spawns the next instance, with month/year date clamping and fresh subtasks (`app_cubit.dart:243-350`); clear-all-completed per category |
| Grocery | `GroceryItem` (`lib/grocery_item.dart`) | title, description, section (current / nextTime), isCompleted, autoAddToNext | Two sections; items with `autoAddToNext` re-appear in Next Time when deleted or cleared, de-duplicated by title (`app_cubit.dart:1340-1526`); move one/all Next Time → Current |
| Journal | `JournalEntry` (`lib/journal_entry.dart`) | title, body, createdAt | Grouped year → month in nested expansion tiles; month level skipped when a year has one month |
| Watch/Read | `WatchItem` (`lib/watch_item.dart`) | title, type (movie/tvShow/book), status (planned/inProgress/completed), season, episode, notes | Status changes; season/episode progress; legacy status names migrated on load |

### 3.2 Cross-cutting features

- Home dashboard with counts per list (`lib/home_screen.dart`).
- Local JSON storage in the app documents folder (`lib/app_storage.dart`).
- Google Drive `appDataFolder` sync. It runs a per-type, per-id last-write-wins merge with
  tombstones (pruned after 365 days), plus exact-duplicate removal per type, and auto-pushes after
  every local change (`lib/drive_sync_service.dart`, `app_cubit.dart:352-465`).
- Dark mode, and 6 locales (en, zh, ja, fr, es, de) via ARB files.

## 4. The core idea: a generic list engine

### 4.1 List definition (what the AI writes, and what the editor edits)

```jsonc
{
  "id": "uuid",
  "name": "Grocery",
  "icon": "shopping_cart",
  "color": "#4A90D9",
  "templateId": "builtin.grocery",      // null for AI/custom lists
  "schemaRevision": 3,                  // bumps on every definition edit
  "fields": [
    { "key": "title", "type": "text", "label": "Item", "required": true, "primary": true },
    { "key": "description", "type": "longText", "label": "Notes" },
    { "key": "done", "type": "checkbox", "role": "completion" },
    { "key": "section", "type": "enum", "options": ["current", "nextTime"], "default": "current" },
    { "key": "autoAddToNext", "type": "toggle", "label": "Auto-add next time" }
  ],
  "view": { "kind": "sectioned", "sectionBy": "section" },
  "behaviors": [
    { "kind": "copyOnClear", "when": "autoAddToNext", "setField": { "section": "nextTime" },
      "dedupeBy": "title" }
  ],
  "aiAllowed": true,                    // per-list "never send to AI" switch
  "updatedAt": "…"
}
```

Items become `{ id, listId, values: { fieldKey: value }, createdAt, updatedAt }`.

### 4.2 Vocabulary (the finite set the renderer supports)

Rule: **if a current feature can't be expressed with this vocabulary, the vocabulary grows. The
built-in list doesn't keep a special case.** Otherwise built-in and AI-made lists drift apart.

- **Field types:** text, longText, checkbox (completion role), toggle, number, counter (± stepper —
  season/episode), rating, date, dateTime (reminder role), enum/status, tags/category
  (user-extensible — task categories), url, checklist (sub-items — subtasks), recurrence
  (repeatFrequency + customDays).
- **Views:** `checklist` (tasks), `sectioned` (grocery), `timeline` by year/month (journal),
  `grouped` by an enum (watch/read), `table`, `cards`. Any view can add `filterChipsBy` (task
  categories with counts).
- **Behaviours** (named, parameterised rules run by app code — never model-written code):
  `recurOnClear` (today's repeat-task logic moved as-is), `copyOnClear` (grocery auto-add),
  `moveAll`, `clearCompleted`, `autoTimestamp`.

### 4.3 Mapping current lists to templates

| Built-in | View | Special fields | Behaviours |
|---|---|---|---|
| Tasks | checklist + filterChipsBy category | tags(category), checklist(subtasks), dateTime(reminder), recurrence | recurOnClear, clearCompleted |
| Grocery | sectioned by section | enum(section), toggle(autoAddToNext) | copyOnClear, moveAll, clearCompleted |
| Journal | timeline by createdAt | longText(body) | autoTimestamp |
| Watch/Read | grouped by status | enum(type), enum(status), counter(season), counter(episode) | — |

"Set lists by default" means these four templates are created on first launch. A user who never
touches AI or the editor sees exactly today's app.

### 4.4 Migration strategy

Run both engines side by side; don't rewrite in place:

1. Add `ListDefinition` / `ListItem` storage on the new sync layer (Section 8).
2. Build the generic renderer. Watch/Read is first (simplest, no behaviours), with the old screen
   kept behind a flag until parity.
3. Port Journal, then Grocery, then Tasks last (most logic; write its tests first).
4. One-time import of the v2 data into the new format, keeping the v2 file untouched as a backup.

**Changing a field's type on a list that already has data** is the tricky case (for example "make
price a number" when values look like "$3"). Never destroy values. Convert where it's lossless;
otherwise keep the old value in a hidden `_legacy` slot and show "3 items couldn't be converted".
Removing a field hides its values rather than deleting them, so an undo is always possible.

## 5. Radial sticker-note launcher

### 5.1 Hold mode (primary on touch)

```
 press & hold hub ─► ~200° arc of notes fans out above the hub; "+" pinned at the right end
   │
   ├─ drag onto a note ─────────► note lifts, haptic tick
   │     ├─ release ─────────────────────────────► OPEN list
   │     └─ hold still ~1 s ─► ring fills around the note
   │            ├─ finger moves away before full ─► cancelled, back to hover
   │            └─ ring full (haptic thump, note shows "Edit")
   │                   └─ release ──────────────────► EDIT list
   │
   ├─ drag onto "+" and release ──► NEW list (opens prompt bar / template picker)
   ├─ drag into either end zone ──► arc auto-scrolls; speed grows with depth into the zone
   └─ release on hub or off-arc ──► cancel
```

The dwell timer runs only while the finger is still (moved less than ~8 px) **and** the arc is not
auto-scrolling. Notes sliding under a resting finger during auto-scroll therefore never trigger
edit.

### 5.2 Tap mode (mouse, keyboard, screen readers, anyone who forgets the gesture)

- Tap hub → the arc opens and **stays open**, with ‹ › arrow buttons at the two ends.
- Tap a note → open. Long-press (or right-click) a note → edit. Tap "+" → new list.
- Arrows page by one visible screenful. Horizontal scroll or swipe on the arc also scrolls.
- Tap hub again, tap outside, or press Esc → close.
- Keyboard: ←/→ move focus, Enter opens, E edits, Esc closes.
- Every note has a `Semantics` label ("Grocery, 4 items, button. Double-tap to open, long-press to
  edit").

Layout detail: the right arrow and the pinned "+" are both at the right end. Put the arrows just
*below* the arc ends so neither crowds the "+".

### 5.3 Implementation notes

- A single `Listener` on the hub captures the pointer for the whole gesture. An `OverlayEntry`
  paints the notes. Hit-testing is by angle and distance from the hub centre, not widget
  hit-tests, so it stays reliable while notes animate.
- The notes are a virtual strip with a scroll `offset` driven by a `Ticker` in the end zones (outer
  ~15% of the arc). Visible count N comes from note width and arc radius.
- Order notes by most-recently opened, so the common case never needs scrolling.
- The hub floats (draggable, position saved per device) and replaces the bottom `NavigationBar`.
- The home dashboard becomes one summary card per list, built from each definition's
  count/completion fields.

Feasibility: high. Ordinary custom-gesture Flutter work, no platform channels or new packages. The
numbers (dwell time, end-zone size, note size) need tuning on a real phone, not in an emulator.

## 6. AI prompt bar

### 6.1 What the user can say

| Intent | Example | Output |
|---|---|---|
| Create list | "Track my runs: distance, time, how I felt" | new `ListDefinition` (+ optional seed items) |
| Change current list | "Add a price column and total it" | patch ops on the definition |
| Add/modify items | "Add milk, eggs and 2 lb chicken" | item ops |
| Ask | "What's left for this week?" | text answer, no writes |

### 6.2 Contract between model and app

The model calls **tools**, and their arguments are validated against a JSON Schema generated from
the vocabulary:

- `create_list(definition)`
- `patch_list(listId, ops[])` — addField, removeField, renameField, changeFieldType, setView,
  addBehavior, removeBehavior
- `upsert_items(listId, items[])`, `delete_items(listId, ids[])`

The backend validates the arguments, and the app validates them again. The app shows a **preview**
(live render plus a plain-language diff), applies on confirm, and keeps one-tap **undo**. Item
additions can skip the preview and rely on undo. Definition changes always preview.

Context per request: the current list's definition, its last ~20 items (none if `aiAllowed` is
false), the names of the other lists, and the UI locale.

### 6.3 Model choice

Use one generative model with structured outputs or strict tool use, behind a provider-agnostic
`AiService` interface. Candidates: OpenAI Responses API, Claude Messages API, Gemini. Test them on
your own prompts; for this volume, cost differences will be small. On-device models (Apple
Foundation Models, Gemini Nano) are possible later for offline routing, but Flutter plugin support
is uneven (unverified).

### 6.4 Where the Decisions API fits — concrete scenarios

The Decisions API answers: "given this input, how likely is X?", "which of *these* options?", "how
does this score on *this* scale?" It works when the **options already exist** and only one needs
choosing. Each answer comes with a probability, so the app can act automatically when confident and
ask when not.

**Scenario A — "Where does this go?" (global prompt, no list open).**
User types "buy AA batteries" from the home screen.
- Question: `choice` over the user's own list names `[Grocery, Tasks, Journal, Watch/Read,
  Party supplies, (new list)]`.
- Result: Grocery 0.62, Tasks 0.31, …
- App rule: ≥ 0.80 → add there and show "Added to Grocery · Undo". Below that → show the top two as
  chips: "Grocery / Tasks?". The options come from the user's data at request time, which is
  exactly what this API is built for.

**Scenario B — auto-fill a category.**
New task "renew passport". Question: `choice` over that user's task categories
`[Personal, Work, Errands, none]` → Errands 0.88 → pre-select the chip; the user can change it.
Same pattern: grocery item → store section/aisle, watch item → `movie / tvShow / book`.

**Scenario C — when *not* to guess.**
"Dune" → movie 0.41, book 0.38, tvShow 0.21. Nothing is confident, so leave the field empty. This
is the main benefit over a generative model: you get calibrated uncertainty instead of a confident
wrong answer.

**Scenario D — skip generation for common requests.**
"Make me a list for party shopping" → `choice` over templates `[grocery, tasks, journal, watch,
none]` → grocery 0.91 → create from the built-in template locally and instantly, with no
generative call. Only when no template scores high does the request go to the generative model.

**Scenario E — intent router in front of the generative model.**
`choice` over `[add_items, change_structure, create_list, question]`. This picks a smaller, cheaper
prompt for the generative call. It is useful only if the generative model is slow or costly enough
to matter; for a personal app it probably isn't.

**What it can't do:** turn "milk, eggs and 2 lb chicken" into three items with a quantity. That's
extraction → generative model (or a local comma-split for trivial cases).

**Verdict:** A–C are real wins that a generative model handles worse (slower, no calibrated
confidence). They are small, add-on features, so they belong in Phase 6, after the core works.
Status: public beta per press reports; I couldn't reach OpenAI's own docs, so check the request
shape and price before building on it.

## 7. Backend setup

An LLM API key can't ship inside the app binary — it would be extracted. So a backend is required
for AI. Two routes, depending on the sync choice in Section 8:

### 7.1 Route F — Firebase (recommended if sync moves to Firestore)

1. **Project.** Create a Firebase project, ideally on the same Google Cloud project as the OAuth
   client the app already uses for Drive sign-in. Upgrade to the **Blaze** (pay-as-you-go) plan:
   Cloud Functions need it to call external APIs. Set a billing **budget alert** (e.g. $10/month)
   on day one.
2. **App wiring.** Run `dart pub global activate flutterfire_cli`, then `flutterfire configure`
   (this generates `lib/firebase_options.dart`). Add `firebase_core`, `firebase_auth`,
   `cloud_firestore`, `cloud_functions`, `firebase_app_check`.
3. **Auth.** Enable the Google provider. Reuse the existing `google_sign_in` flow:
   `GoogleAuthProvider.credential(idToken, accessToken)` → `signInWithCredential`. Users see no
   new sign-in step.
4. **Firestore** (if used for sync): data model and security rules in Section 8.2.
5. **AI function.** A 2nd-gen callable function `aiCommand` (TypeScript or Python):
   - The key lives in Secret Manager: `firebase functions:secrets:set OPENAI_API_KEY` (or the
     Anthropic/Gemini equivalent). It is never in the repo or the app.
   - Callable functions reject unauthenticated calls automatically; also enforce **App Check**
     (Play Integrity / App Attest / reCAPTCHA for web) so only your app can call it.
   - Builds the tool schema from the vocabulary, calls the model, validates the output, and
     returns ops. It **does not write data**: the client applies ops after the user confirms the
     preview.
   - Optional `aiClassify` function wrapping the Decisions API for Section 6.4.
6. **Rate limit.** A per-uid counter document (e.g. 200 requests/day), checked in a transaction
   before calling the model.
7. **Dev loop.** The Firebase Emulator Suite (Auth, Firestore, Functions) for local runs and tests;
   a fake model provider for CI.
8. **Store requirements.** Update the privacy policy (list data goes to your backend and an AI
   provider), add an in-app AI opt-in, and complete the data-safety forms (Play) and privacy labels
   (App Store).

### 7.2 Route W — Cloudflare Worker (if sync stays on Drive)

A single Worker that verifies the Google ID token the app already gets (Google's public JWKS),
rate-limits per user in KV, holds the key as a Worker secret, and forwards to the model. Lighter
than Firebase and free at this scale, but it's a second system with no shared auth/database
benefits.

## 8. Bugs and sync: evaluation against the rebuild

### 8.1 Current defects

| # | Defect | Where | Severity |
|---|---|---|---|
| B1 | Local file that fails to parse is overwritten with empty data | `lib/app_storage.dart:67-71` | **Data loss** |
| B2 | Remote Drive file that fails to parse is overwritten with local data | `lib/drive_sync_service.dart:163-187` | **Data loss** (cloud copy) |
| B3 | Merge round-trips through `AppData.toJson()` and hard-codes `schemaVersion: 2`, so an older build deletes any data a newer build adds | `drive_sync_service.dart:363` | Data loss once the format changes |
| B4 | **Lost-update race:** sync downloads, merges, then uploads with a plain `files.update` and no revision check. Two devices syncing at once — likely, since every edit auto-pushes — means the second upload overwrites the first device's changes | `drive_sync_service.dart:302-321` | Silent loss of recent edits |
| B5 | Reminders never fire (no notification plugin) | `pubspec.yaml` | Missing feature |
| B6 | `watchingCount` compares against a status name that no longer exists, so it always returns 0; unused | `lib/app_state.dart:72-76` | Cosmetic |

### 8.2 Sync options for generic lists

| | A. Drive, rebuilt generically | B. Firestore | C. Supabase/PowerSync (SQLite + Postgres) |
|---|---|---|---|
| Where data lives | User's own Drive (private to them) | Your Firebase project | Your Postgres |
| Server to run | None for data (still need the AI proxy) | Same project as the AI function | Separate service |
| Merge code you maintain | All of it (~750 lines today, to be rewritten generically) | None — per-document writes, field-level `update()` merges | Little |
| Deletes | Tombstones + pruning (yours) | Native | Native |
| Fixes B4 race | Only with a revision check before upload (still a narrow window) | Yes, by design | Yes |
| Realtime across devices | No (sync on change/refresh) | Yes (listeners) | Yes |
| Offline | Yes (local file) | Yes (built-in cache on Android/iOS/web) | Yes |
| Platforms | All 6 | Android, iOS, web, macOS. **Linux not supported** by FlutterFire; Windows support is limited (verify before relying on it) | Most; check Linux/Windows |
| Cost | Free | Free tier likely covers personal use | Free tier, more setup |
| Fit to generic definitions | OK — one file, or one per list | Very good — `users/{uid}/lists/{listId}`, `…/lists/{listId}/items/{itemId}` | Very good, but needs a schema for dynamic fields (JSONB) |

Firestore rules for option B:

```
match /users/{uid}/{document=**} {
  allow read, write: if request.auth != null && request.auth.uid == uid;
}
```

**Recommendation: B (Firestore)**, *if* you accept two trade-offs: (1) data moves from the user's
own Drive to your project, which you're responsible for; (2) Linux desktop (and possibly Windows)
loses sync or the app on those platforms. Reasons: the AI work already forces a Firebase-style
backend, so sync shares its auth and project at no extra infrastructure. It removes the merge,
tombstone and race code entirely instead of rewriting it generically. And per-document storage is
exactly the shape of generic lists and items.

Choose **A** instead if "your data stays in your own Drive" is a core promise of the app, or if
Linux/Windows desktop matter. Then the rewrite must include a separate v3 file and a revision check
before every upload.

### 8.3 What to fix now vs. what the rebuild removes

| Defect | Under B (Firestore) | Under A (Drive) | Do now? |
|---|---|---|---|
| B1 local wipe | Still matters: the one-time import reads this file | Still matters | **Yes.** Hours of work; it protects current data *and* the migration |
| B2 remote overwrite | Gone once the new build stops writing Drive (Drive becomes read-only import) | Must fix | **Yes** if anyone besides you uses the app now (≈10 lines); otherwise optional |
| B3 old-build clobber | Gone: the new build never writes the v2 Drive file, so old builds can't damage new data (they just stop seeing new edits — show an "update the app" notice) | Fix via separate v3 file + version guard | **No.** Solve it inside the rebuild |
| B4 race | Gone | Fix with revision check in the rebuild | **No** (existing behaviour, rarely hit by a single user) |
| B5 reminders | Decide during vocabulary design; notifications are local and sync-independent | same | In Phase 2 |
| B6 | Delete during rebuild | same | No |

So the only pre-rebuild work is B1 (and B2 if there are other users). Spending effort on B3/B4 for
the current code would be thrown away by the rebuild.

## 9. Localisation

Built-in template names and labels stay in ARB files. AI-created labels are stored as literal
strings in the language the user wrote. That's correct, but those lists won't re-translate when the
UI language changes. Pass the UI locale to the model.

## 10. Risks, ranked

1. **Data loss during migration** — mitigated by B1 fix, a read-only import, and keeping the v2
   file as backup.
2. **Generic renderer less polished than today's screens** — port one list at a time behind a flag.
3. **Valid-but-poor AI lists** — preview, editor, and few-shot prompts using the 4 built-in
   templates.
4. **Backend cost/abuse** — App Check, per-user limits, budget alert.
5. **Platform gaps from Firestore** (Linux/Windows) — confirm before choosing option B.
6. **Gesture tuning** — needs real-device testing early.

## 11. Next steps

1. Fix B1 (and B2 if there are other users), with tests.
2. Decide sync: B (Firestore) or A (Drive). Confirm FlutterFire platform support for the platforms
   you actually ship.
3. Write the `ListDefinition` / `ListItem` models plus the vocabulary JSON Schema; unit-test that all
   4 built-in templates validate and round-trip.
4. Prototype the radial launcher on a branch and test on a real phone (independent of 3).
5. Stand up the backend (Section 7) once the sync decision is made.

## Sources (Decisions API — secondary reporting only)

- The New Stack: https://thenewstack.io/openai-decision-api-luna/
- Vercel: https://vercel.com/i/what-is-openai-decisions-api
- Microsoft Foundry blog: https://techcommunity.microsoft.com/blog/azure-ai-foundry-blog/azure-openai-decisions-api-now-generally-available-in-microsoft-foundry/4567265
- ProPakistani: https://propakistani.pk/2026/10/07/openai-launches-decisions-api-with-up-to-10x-faster-responses/
- Promptfoo provider docs: https://www.promptfoo.dev/docs/providers/openai-decisions/
