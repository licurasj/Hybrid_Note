# AI Fluid Interface: Feasibility & Plan

Status: proposal, nothing implemented. Written against commit `568cc9d`.

## 1. Verdict up front

**Feasible, but the hard part is not the AI and not the circle menu. It is the data model.**

Today every list type is a hand-written Dart class, a hand-written screen, hand-written cubit
methods and a hand-written Drive merge function. An app that can "create the UI it needs on the
spot" needs every one of those four layers to become generic and data-driven first. Once that is
done, the radial launcher is a self-contained widget and the AI prompt bar is a fairly thin layer
that writes JSON the app already knows how to render.

Rough effort for one developer who knows this codebase (guesses, not measurements):

| Phase | What | Rough size |
|---|---|---|
| 0 | Fix data-loss paths, add sync version gate | 1–3 days |
| 1 | Generic list engine + port the 4 built-in lists to it | 3–5 weeks |
| 2 | Radial "sticker note" launcher | 1–2 weeks |
| 3 | Manual list editor (the "hold to edit" target) | 1–2 weeks |
| 4 | AI prompt bar + backend proxy | 2–3 weeks |
| 5 | Optional: Decisions API router, on-device model | 1 week each |

Phases 0–3 deliver a useful app with **no AI at all**. That ordering is deliberate: AI output has to
land in something a person can inspect and fix by hand, so the manual editor is a prerequisite, not
an extra.

## 2. Corrections to the original framing

These are the places where I think the idea as stated would go wrong if built literally.

1. **"The AI creates the UI" — it should not.** Flutter cannot load new Dart code at runtime,
   and the App Store and Play Store forbid downloading executable code anyway. Even where it
   were possible, model-written widgets would be untestable. The workable version is: the app ships
   a fixed vocabulary of field types, views and behaviours (Section 4), and the AI only produces a
   **declarative list definition** (JSON) that picks and configures pieces from that vocabulary.
   The UI feels generated, but every pixel comes from a renderer you wrote and tested. This is
   the main framing change I would make.

2. **The OpenAI Decisions API cannot do the core job.** It classifies, scores and picks from
   options you supply. It does not generate structures. It cannot design a list schema. It
   *can* cheaply decide "is this prompt editing the current list or creating a new one?" and "which
   built-in template fits best?" (Section 6). Treat it as an optional router in front of a normal
   generative model, not as a replacement for one.

3. **Hold-to-edit inside a hold-to-open menu conflicts with itself.** The user is already holding
   and dragging. If "pause on a note" means edit, then pausing to read a label opens the editor by
   accident. Section 5 proposes a version without that collision.

4. **A circle doesn't hold many notes.** Rectangular sticker notes around a thumb-sized hub fit
   roughly 6–9 before they overlap or run off a phone screen (my estimate). The auto-scroll you
   describe is therefore the normal path, not an edge case, for anyone with more than ~8 lists.
   Design it as a scrolling **arc**, not a full ring.

5. **"Reminders" today are stored, not delivered.** `TaskItem.reminderAt` exists and drives repeat
   logic, but there is no notification plugin in `pubspec.yaml`, so nothing ever fires. If the AI
   offers a "reminder" field on custom lists, users will expect alerts. Either add
   `flutter_local_notifications` or label the field "due date".

6. **The app targets 6 platforms.** Android, iOS, web, Windows, macOS and Linux runners all exist.
   Press-hold-drag radial menus are natural on touch and awkward with a mouse and keyboard, and they
   do not work with a screen reader. A plain list or grid fallback is required, not optional.

## 3. What exists today (must all survive)

### 3.1 List types and their data

| List | Model | Fields | Built-in behaviour |
|---|---|---|---|
| Tasks | `TaskItem` + `SubtaskItem` (`lib/task_item.dart`) | title, description, isCompleted, category, subtasks[], reminderAt, repeatFrequency (none/daily/weekly/monthly/yearly/custom), customRepeatDays | Categories with counts and filter chips; default "All My Tasks"; clearing a completed repeating task spawns the next instance with month/year date clamping and fresh subtasks (`app_cubit.dart:243-350`); clear-all-completed per category |
| Grocery | `GroceryItem` (`lib/grocery_item.dart`) | title, description, section (current / nextTime), isCompleted, autoAddToNext | Two sections; items with `autoAddToNext` re-appear in Next Time when deleted or cleared, de-duplicated by title (`app_cubit.dart:1340-1526`); move one/all Next Time → Current |
| Journal | `JournalEntry` (`lib/journal_entry.dart`) | title, body, createdAt | Grouped by year → month in nested expansion tiles; month level skipped when a year has one month |
| Watch/Read | `WatchItem` (`lib/watch_item.dart`) | title, type (movie/tvShow/book), status (planned/inProgress/completed), season, episode, notes | Status changes; season/episode progress; legacy status names migrated on load |

### 3.2 Cross-cutting features

- Home dashboard with counts per list (`lib/home_screen.dart`).
- Local JSON storage in the app documents folder (`lib/app_storage.dart`).
- Google Drive `appDataFolder` sync. It runs a per-type, per-id last-write-wins merge with
  tombstones (pruned after 365 days), plus exact-duplicate removal per type. It auto-pushes after
  every local change (`lib/drive_sync_service.dart`, `app_cubit.dart:352-465`).
- Dark mode, and 6 locales (en, zh, ja, fr, es, de) via ARB files.

### 3.3 Problems found that block this plan

These need fixing **before** any schema migration. A migration multiplies their blast radius.

- **Local parse failure wipes data.** `AppStorage.loadAppData` catches any exception and saves an
  empty `AppData` over the file (`lib/app_storage.dart:67-71`). A bug in a new v3 parser would
  silently erase every user's data on first launch. Fix: back up the raw file before overwriting,
  and never overwrite on parse failure.
- **Remote parse failure overwrites Drive.** If `_downloadRemoteData` returns `null`,
  `_mergeThenUpload` uploads local data over the remote file (`drive_sync_service.dart:163-187`).
  Same risk, but on the cloud copy.
- **Old clients will delete new data.** The merge round-trips through `AppData.toJson()` and
  hard-codes `schemaVersion: 2`, so any key that version doesn't know is dropped. If one device
  runs a new build with custom lists and another device runs today's build, the old device's next
  auto-push erases the custom lists from Drive. Fix: write custom lists to a **separate Drive file**
  (for example `hybrid_note_lists_v3.json`) that old builds never read or write. Also make new
  builds refuse to overwrite a remote whose `schemaVersion` is higher than their own.
- Minor: `AppState.watchingCount` compares `status.name == 'watching'`, which no enum value has
  any more, so it always returns 0 (`lib/app_state.dart:72-76`). It's unused right now.

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
  "updatedAt": "…"
}
```

Items become `{ id, listId, values: { fieldKey: value }, createdAt, updatedAt }`.

### 4.2 Vocabulary (the finite set the renderer supports)

The rule: **if a current feature can't be expressed with this vocabulary, the vocabulary grows. The
built-in list doesn't keep a special case.** Otherwise "built-in" and "AI-made" lists drift apart
and the AI can never make something as good as the defaults.

- **Field types:** text, longText, checkbox (completion role), toggle, number, counter (±
  stepper — season/episode), rating, date, dateTime (reminder role), enum/status (single
  choice), tags/category (multi or single, user-extensible — task categories), url, checklist
  (sub-items — subtasks), recurrence (repeatFrequency + customDays).
- **Views:** `checklist` (tasks), `sectioned` (grocery current/next), `timeline` grouped by
  year/month (journal), `grouped` by an enum field (watch status / media type), `table`, `cards`.
  Each view also takes a `filterChipsBy` field (task categories with counts).
- **Behaviours** (named, parameterised rules run by the cubit — never model-written code):
  - `recurOnClear` — today's repeat-task logic, moved as-is.
  - `copyOnClear` — today's grocery auto-add-to-next.
  - `moveAll` — "move all Next Time → Current".
  - `clearCompleted` — scoped by the filter field.
  - `autoTimestamp` — journal's createdAt grouping.

### 4.3 Mapping current lists to templates

| Built-in | View | Special fields | Behaviours |
|---|---|---|---|
| Tasks | checklist + filterChipsBy category | tags(category), checklist(subtasks), dateTime(reminder), recurrence | recurOnClear, clearCompleted |
| Grocery | sectioned by section | enum(section), toggle(autoAddToNext) | copyOnClear, moveAll, clearCompleted |
| Journal | timeline by createdAt | longText(body) | autoTimestamp |
| Watch/Read | grouped by status | enum(type), enum(status), counter(season), counter(episode) | — |

"Set lists by default" = these four templates are created on first launch. A user who never
touches AI or the editor sees exactly today's app.

### 4.4 Migration strategy

Don't rewrite in place. Run both engines side by side:

1. Add `ListDefinition` / `ListItem` storage next to the existing `AppData` lists.
2. Build the generic renderer. Make Watch/Read the first built-in rendered by it, since it is the
   simplest list with no behaviours. Keep the old screen behind a flag until parity.
3. Port Journal, Grocery, then Tasks last. Tasks has the most logic and the most tests worth
   writing first.
4. Only when all four are on the generic engine, do a one-time v2→v3 data conversion. Keep a
   backup copy of the v2 file.

Sync becomes simpler: one generic per-item merge keyed by `id` and `updatedAt`. That replaces 5
hand-written ones. Definitions merge the same way by `schemaRevision`/`updatedAt`. Two devices
editing the same list's *definition* offline is rare. Last-write-wins plus keeping unknown field
values (don't delete data for a removed field, just hide it) is enough.

**Changing a field's type on a list that already has data** is the one genuinely tricky case. For
example, "make price a number" when the existing values are text like "$3". Rules: never destroy
values; convert where it's lossless; otherwise keep the old value in a hidden `_legacy` slot and
show a one-time "3 items couldn't be converted" notice.

## 5. Radial "sticker note" launcher

### 5.1 Interaction (revised to avoid the hold/hold collision)

```
   press & hold hub ──► notes fan out along an arc above the thumb
        │
        ├─ slide toward a note ──► note lifts/enlarges (hover)
        │       ├─ release ─────────────► open list
        │       ├─ keep sliding outward
        │       │  past the note ───────► "edit" badge appears; release = edit list
        │       └─ dwell 600 ms ────────► small preview (counts / next items), no action
        │
        ├─ slide to the far-right "+" note ─► release = new list (opens prompt bar)
        ├─ slide toward an arc end ─────────► arc auto-scrolls, speed ∝ distance into edge zone
        └─ release on hub / outside ────────► cancel
```

Why "slide outward to edit" instead of "dwell to edit": it's a deliberate gesture, it can't be
triggered by hesitating, and it still needs no second finger. Dwell then becomes a harmless preview.

### 5.2 Implementation notes

- One `Listener`/`GestureDetector` on the hub that captures the pointer for the whole gesture, and
  an `OverlayEntry` that paints the notes. Hit-testing is done by angle and distance from the hub
  centre, not by widget hit-tests. That makes it robust while notes animate.
- Lay notes out on an arc of roughly 200° (not 360°: the bottom of the circle sits under the thumb or
  off-screen). Visible capacity N comes from note width and arc radius. The list is a virtual strip
  of length `lists.length + 1` (the "+"), with an `offset` advanced by a `Ticker` while the pointer
  is in the outer 15% of either end of the arc.
- Haptic tick (`HapticFeedback.selectionClick`) on each hover change. Order notes by most-recently
  opened so the common case never needs scrolling.
- The hub floats (draggable, position persisted per device) and replaces the bottom
  `NavigationBar` once the list count is no longer fixed at 4.
- **Fallbacks:** a tap (not hold) on the hub opens a normal grid sheet of all lists. That serves
  mouse, keyboard and TalkBack/VoiceOver users, and anyone who forgets the gesture. Every note
  gets a `Semantics` label.
- The home dashboard becomes "one summary card per list", generated from each definition's
  completion/count fields.

Feasibility: high. This is ordinary custom-gesture Flutter work, with no platform channels and no
new dependencies.

## 6. AI prompt bar

### 6.1 What the user can say

| Intent | Example | Output |
|---|---|---|
| Create list | "Track my runs: distance, time, how I felt" | new `ListDefinition` (+ optional seed items) |
| Change current list | "Add a price column and total it" | patch ops on the definition |
| Add/modify items | "Add milk, eggs and 2 lb chicken" | item ops |
| Ask | "What's left for this week?" | text answer, no writes |

### 6.2 Contract between model and app

The model never returns free-form JSON that gets trusted. It calls **tools** whose arguments are
validated against a JSON Schema generated from the vocabulary in 4.2:

- `create_list(definition)`
- `patch_list(listId, ops[])` — ops: addField, removeField, renameField, changeFieldType,
  setView, addBehavior, removeBehavior
- `upsert_items(listId, items[])`, `delete_items(listId, ids[])`

The app then:

1. Validates the arguments, rejecting unknown types or keys and resolving field-key collisions.
2. Shows a **preview**: a live render of the new or changed list plus a plain-language diff.
3. Applies only on confirm, and keeps one-tap **undo** (store the previous definition revision).

Item additions on an existing list can skip the preview and rely on undo. Definition changes
always preview.

Context sent per request: the current list's definition, its last ~20 items (or none, if the user
opts out), and the names of the other lists. That stays small, so cost per request is low.

### 6.3 Model / API options

| Option | Good for | Limits |
|---|---|---|
| **OpenAI Decisions API** (`/v1/decisions`, GPT-6 Luna) | Fast, cheap classification. Route the prompt (create vs. edit vs. add items vs. ask); pick the best built-in template with a probability; ask "does this need a new field?" | Returns probabilities, choices from options *you* supply, and rubric scores. It does **not** generate a schema or items. Public beta per press reports; I couldn't reach OpenAI's own docs, so check the endpoint shape and price before building on it. |
| OpenAI Responses API with strict structured outputs / function calling | Generating the definition and patch ops | Needs a backend proxy for the key |
| Claude (Messages API, strict tool use) or Gemini (function calling) | Same job as above | Same proxy requirement. Worth keeping the provider behind an interface and testing all of them on your own prompts. |
| On-device (Apple Foundation Models on iOS/macOS 26+, Gemini Nano on some Android) | Offline, private, free routing and item parsing | Small models; platform-specific; Flutter plugin support is patchy (unverified, check before committing to it) |

Recommended shape: **one generative model behind a provider-agnostic `AiService`.** Add the
Decisions API in front only if latency or cost actually becomes a problem. A single structured-
output call can do routing and generation at once, and for a personal notes app the volume will be
tiny. Two vendors means two failure modes for a saving you may not need.

Where the Decisions API *would* earn its place: deciding instantly, as the user types, whether a
prompt matches an existing template ("grocery list for the party" → `builtin.grocery`, p=0.93). The
app can then create it locally with zero generation and only fall back to the generative model when
nothing scores high.

### 6.4 Backend requirement (new)

The app has no server today; Drive sync talks to Google directly. **An LLM API key can't ship
inside a Flutter binary** — it would be extracted and abused. You need a small proxy, for example
Firebase Cloud Functions, Cloud Run or a Cloudflare Worker. It holds the key, authenticates the
user (the existing Google sign-in ID token works), rate-limits, and forwards requests. This is new
infrastructure to run and pay for, and it is the biggest non-UI cost of the AI phase.

### 6.5 Privacy

Today data lives only on-device and in the user's own Drive `appDataFolder`. AI features send list
contents to a third party. That needs a clear opt-in, a per-list "never send to AI" toggle (journal
is the obvious candidate), and a privacy-policy update before store submission.

## 7. Localisation

Built-in template names and labels stay in ARB files. AI-created labels are stored as literal
strings in whatever language the user wrote in. That's correct behaviour, but it means a custom
list won't re-translate when the app language changes. Tell the model the current UI locale in the
system prompt so it answers in that language.

## 8. Risks, ranked

1. **Data loss during migration or cross-version sync** (Section 3.3). Highest impact; fix first.
2. **Generic renderer doesn't match the polish of today's hand-built screens.** Mitigate by porting
   one list at a time behind a flag, and not removing the old screen until the new one is at parity.
3. **AI produces lists that are technically valid but poor** (too many fields, wrong view).
   Mitigate with the preview, the editor, and a few-shot prompt using the 4 built-in templates as
   examples.
4. **Backend cost and abuse.** Mitigate with per-user rate limits; the request size is small.
5. **Gesture discoverability.** Mitigate with the tap fallback and a one-time coach mark.

## 9. Suggested first steps

1. Phase 0 fixes (3.3), with tests: a corrupted local file must not be overwritten, an unparseable
   remote must not be overwritten, and a newer remote schemaVersion must not be downgraded.
2. Write `ListDefinition` / `ListItem` models plus the vocabulary JSON Schema. Unit-test that all 4
   built-in templates validate against it and round-trip.
3. Generic renderer for the `grouped` view, then port Watch/Read behind a flag.
4. Radial launcher prototype on its own branch. It doesn't depend on 2–3 and is worth testing on a
   real phone early, since how it *feels* decides the design.

## Sources (Decisions API — secondary reporting only)

- The New Stack, "OpenAI answers TypeSafe's Jev with a Decision API built on Luna": https://thenewstack.io/openai-decision-api-luna/
- Vercel, "What is OpenAI's Decisions API?": https://vercel.com/i/what-is-openai-decisions-api
- Microsoft, "Azure OpenAI Decisions API: Now generally available in Microsoft Foundry": https://techcommunity.microsoft.com/blog/azure-ai-foundry-blog/azure-openai-decisions-api-now-generally-available-in-microsoft-foundry/4567265
- ProPakistani, "OpenAI launches Decisions API with up to 10x faster responses": https://propakistani.pk/2026/10/07/openai-launches-decisions-api-with-up-to-10x-faster-responses/
- Promptfoo provider docs: https://www.promptfoo.dev/docs/providers/openai-decisions/
