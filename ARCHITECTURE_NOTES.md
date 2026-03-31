# ARCHITECTURE_NOTES.md

## Big Files List (Top 15 by line count)
- `/mnt/data/Shelf-Notes/Shelf-Notes/Shelf Notes/BookImport/BookImportView/BookImportViewModel.swift` — **562** lines — UNKNOWN
- `/mnt/data/Shelf-Notes/Shelf-Notes/Shelf Notes/Stats/StatisticsView+Data.swift` — **459** lines — UNKNOWN
- `/mnt/data/Shelf-Notes/Shelf-Notes/Shelf Notes/Stats/StatisticsView+Sections.swift` — **456** lines — UNKNOWN
- `/mnt/data/Shelf-Notes/Shelf-Notes/Shelf Notes/LibraryView/LibraryRowAppearanceSettingsSection.swift` — **454** lines — UNKNOWN
- `/mnt/data/Shelf-Notes/Shelf-Notes/Shelf Notes/Challenges/ChallengeEngine+Compute.swift` — **435** lines — UNKNOWN
- `/mnt/data/Shelf-Notes/Shelf-Notes/Shelf Notes/Book.swift` — **428** lines — UNKNOWN
- `/mnt/data/Shelf-Notes/Shelf-Notes/Shelf Notes/LibraryView/LibraryView+Header.swift` — **418** lines — UNKNOWN
- `/mnt/data/Shelf-Notes/Shelf-Notes/Shelf Notes/BookImport/BookImportView/BookImportViewModel+Tasks.swift` — **406** lines — UNKNOWN
- `/mnt/data/Shelf-Notes/Shelf-Notes/Shelf Notes/BookDetail/BookDetailView+Bindings.swift` — **376** lines — UNKNOWN
- `/mnt/data/Shelf-Notes/Shelf-Notes/Shelf Notes/Stats/StatisticsView+Heatmap.swift` — **373** lines — UNKNOWN
- `/mnt/data/Shelf-Notes/Shelf-Notes/Shelf Notes/CSVImportExportView.swift` — **364** lines — UNKNOWN
- `/mnt/data/Shelf-Notes/Shelf-Notes/Shelf Notes/LibraryView/LibraryRowCoverView.swift` — **356** lines — UNKNOWN
- `/mnt/data/Shelf-Notes/Shelf-Notes/Shelf Notes/ForYouSeedBuilder.swift` — **355** lines — UNKNOWN
- `/mnt/data/Shelf-Notes/Shelf-Notes/Shelf Notes/AppearanceSettings/AppearancePreferences.swift` — **354** lines — UNKNOWN
- `/mnt/data/Shelf-Notes/Shelf-Notes/Shelf Notes/CachedAsyncImage.swift` — **342** lines — UNKNOWN

## Hot Path Analyse

### Rendering / Scrolling (SwiftUI)
- `Shelf Notes/Stats/StatisticsView+Data.swift`
  - **Why hotspot:** multiple computed properties iterate over `books` (e.g. `yearOptions` builds a `Set` by scanning all books, then sorts). If any of these are called from `body` during frequent UI updates, this becomes O(n) per invalidation.
  - **Mitigation present:** `StatisticsView` uses `statsCache` / `heatmapCache` (`Shelf Notes/StatisticsView.swift`) and a lightweight `booksSignature` invalidator (`Shelf Notes/Stats/StatisticsView+Caching.swift`).
- `Shelf Notes/Stats/StatisticsView+Caching.swift`
  - **Why hotspot:** `booksSignature(_:)` is evaluated on every view update; it intentionally avoids O(n log n) sorting and avoids deep iteration over sessions. This is a good pattern, but it still does O(n) hashing work.
- `Shelf Notes/LibraryView/LibraryView+Header.swift` + `Shelf Notes/LibraryView/LibraryView+Grid.swift` / list views
  - **Why hotspot (likely):** library is a primary scrolling surface; any per-row expensive cover decode or tag/category formatting can show up here. Cover rendering uses cached loaders (see below).
- `Shelf Notes/CachedAsyncImage.swift` + `Shelf Notes/CoverImageLoader.swift`
  - **Why hotspot:** cover image loading happens for many rows. `CachedAsyncImage` runs `.task(id: url)` per URL; decoding + I/O must stay off MainActor.
  - **Evidence:** `CoverImageLoader` explicitly does background work (`background(qos:)`) to avoid MainActor blocking.
- `Shelf Notes/BookDetail/BookDetailView+Bindings.swift`
  - **Why hotspot:** Book detail is interactive (typing in tags, expanding descriptions). This file explicitly caches tag counts via `TagsIndexModel` to avoid O(n·tags) during render.

### Sync / Storage (CloudKit + SwiftData)
- `Shelf Notes/AppContainerHostView.swift`
  - **Why hotspot:** app startup path; creates the `ModelContainer` and runs repairs in `.task(id: mode)`.
  - **Risk:** if any of the repair tasks do heavy fetch/compute on MainActor, launch can hitch. Current design keeps launch non-crashing, but performance depends on implementations of repairs/engine.
- `Shelf Notes/CollectionMembershipRepair.swift`
  - **Why hotspot:** one-time repair potentially touches many objects; must be careful about batching, saving, and not blocking UI.
- `Shelf Notes/RootView.swift` + `Shelf Notes/CoverThumbnailer/CoverThumbnailer+Backfill.swift`
  - **Why hotspot:** initial cover backfill can touch all books; RootView cancels when app leaves `.active` and schedules only when active.
  - **Risk:** if backfill runs too aggressively, it can contend with UI and CloudKit sync. Look for batching/yield/cancellation in `CoverThumbnailer+Backfill`.

### Concurrency (MainActor contention / Task lifetimes)
- `Shelf Notes/CachedAsyncImage.swift`
  - `loadIfNeeded()` is `@MainActor` (state updates) but awaits `CoverImageLoader.loadImage(for:)` which is implemented to do I/O/decoding off-main. Keep it that way; a regression here will immediately impact scrolling.
- `Shelf Notes/AppContainerHostView.swift`
  - `.task(id: mode)` is a good cancellation boundary (switching storage modes cancels prior work).
- `Shelf Notes/BookImport/BookImportView/BookImportViewModel+Tasks.swift`
  - **Why hotspot:** import is typically network + persistence + cover handling. Ensure tasks are cancellable and do not hold MainActor while performing mapping or network work.
- `Shelf Notes/Challenges/ChallengeEngine+Compute.swift`
  - Explicitly off-main compute (file name suggests it; verify that compute paths do not touch `ModelContext` outside MainActor except via snapshots).

## Refactor Map

### Concrete Splits (mechanical, low-risk)
- `Shelf Notes/BookImport/BookImportView/BookImportViewModel.swift` (562 lines)
  - Split into:
    - `BookImportViewModel+State.swift` (published UI state, validation)
    - `BookImportViewModel+Networking.swift` (Google Books queries)
    - `BookImportViewModel+Persistence.swift` (creating/updating `Book` + saving)
    - keep `BookImportViewModel+Tasks.swift` for async orchestration
  - **Goal:** reduce merge conflicts and isolate concurrency boundaries.
- `Shelf Notes/LibraryView/LibraryRowAppearanceSettingsSection.swift` (454 lines)
  - Split by subsections (Cover / Typography / Badges / Spacing / Reset) into separate files under `Shelf Notes/LibraryView/`.
- `Shelf Notes/Stats/StatisticsView+Sections.swift` / `+Data.swift`
  - Consider moving non-trivial computed properties into cache builder functions so `body` only reads cached values.

### Cache / Index Ideas
- **Tags index (already present):** `Shelf Notes/TagsView/TagsIndexModel.swift` is used in Book Detail to avoid O(n·tags). Ensure other screens don’t re-implement tag counting ad hoc.
- **Stats caches (already present):** `StatisticsView` uses `StatsCache` and `HeatmapCache`. Keep cache build work off the render path; use `booksSignature` only as invalidator.
- **Cover pipeline:** avoid re-downloading by ensuring URL resolution is persisted (`Book.thumbnailURL`, `Book.coverURLCandidates`) and disk cache is used (`ImageDiskCache`).

### Vereinheitlichungen (Patterns / Services / DI)
- Introduce a small `AppServices` container (even as plain struct of singletons) and inject it via `.environment(...)` to avoid duplicated `@StateObject` creation patterns.
- Standardize “signature tokens” for `.task(id:)` invalidation (pattern used in stats caching; can be reused for tags/timeline).

## Risiken & Edge Cases
- **CloudKit + SwiftData constraints:** non-optional properties need defaults; relationships often need to be optional; uniqueness constraints can break sync (project explicitly avoids them).
- **Local-only fallback:** it uses a separate store name (`ShelfNotesLocal`) → data divergence is intended. UX must make this clear (banner + alert exist).
- **External storage:** `Book.userCoverData` uses `.externalStorage`; large data blobs and frequent updates can affect sync/perf.
- **Backfills/repairs:** cover backfill + membership repair can create heavy write bursts → potential CloudKit contention; ensure batching and minimal saves.

## Observability / Debuggability
- `Shelf Notes/ModelContext+Diagnostics.swift` suggests instrumented save helpers (used in `Book.swift` migration code).
- `Shelf Notes/SyncDiagnostics.swift` + `Shelf Notes/SyncDiagnosticsView.swift`: use for CloudKit visibility (exact navigation wiring: **UNKNOWN**).
- Recommend adding a lightweight “Diagnostics” section listing:
  - active store mode (cloud/local/in-memory)
  - last backfill run timestamps
  - last stats cache rebuild time + signature

## Open Questions (UNKNOWN)
- Exact iOS deployment target per app target (26.0 vs 26.2 mapping is incomplete without deeper pbxproj parsing).
- `UserCoverStore` definition path (referenced by `Book.bestCoverURLString` + `CoverThumbnailer+Backfill`).
- `ReadingTimerManager` definition path (instantiated in `RootView`).
- Where `SyncDiagnosticsView` is reachable from UI.

## First 3 Refactors I would do (P0)

### P0.1 — Secrets handling: remove committed API key
- **Goal:** prevent leaked credentials + align builds with standard secret injection.
- **Files:**
  - `Shelf Notes/config/secrets.xcconfig`
  - `Shelf Notes/config/base.xcconfig`
  - `Shelf Notes/Info.plist` (uses `$(GOOGLE_BOOKS_API_KEY)`)
- **Risk:** low (build/config change).
- **Expected benefit:** security + easier CI/teammate setup.

### P0.2 — Hard guarantee: stats work stays off render path
- **Goal:** ensure no O(n) aggregation runs during SwiftUI invalidation for Stats.
- **Files:**
  - `Shelf Notes/StatisticsView.swift`
  - `Shelf Notes/Stats/StatisticsView+Caching.swift`
  - `Shelf Notes/Stats/StatisticsView+Data.swift`
  - `Shelf Notes/Stats/StatisticsView+Sections.swift`
- **Risk:** medium (logic + UI correctness).
- **Expected benefit:** no UI hitching when expanding/collapsing sections; predictable performance on large libraries.

### P0.3 — Split import VM by responsibilities + tighten cancellation
- **Goal:** reduce complexity of import flow, make it easier to reason about task lifetimes and avoid stale updates.
- **Files:**
  - `Shelf Notes/BookImport/BookImportView/BookImportViewModel.swift`
  - `Shelf Notes/BookImport/BookImportView/BookImportViewModel+Tasks.swift`
- **Risk:** low–medium (mostly mechanical split; ensure published state wiring remains identical).
- **Expected benefit:** fewer merge conflicts, easier debugging, better cancellation hygiene during network/import operations.

## Storage Modes & Startup Sequence
- Startup view: `Shelf Notes/Shelf_NotesApp.swift` → `Shelf Notes/AppContainerHostView.swift`.
- `AppBootstrapper` starts in `.cloudKit` mode by default and transitions through phases:
  - `.loading` → `.ready(container:mode:)` or `.failed(error:)`.
- `ModelContainerFactory` creates separate persistent stores for cloud vs local-only to avoid accidental mixing:
  - Store base names are hard-coded: `ShelfNotesCloud` / `ShelfNotesLocal`.
- Post-bootstrap tasks (runs after container is ready):
  - `CollectionMembershipRepair.repairIfNeeded(...)` (scoped per store)
  - `ChallengeEngine.ensureCurrentChallengesAndRefreshCompletion(...)`

## Challenge Engine Notes
- Public facade: `Shelf Notes/Challenges/ChallengeEngine.swift` (writes to `ModelContext` on `@MainActor`).
- Heavy compute is separated into `ChallengeEngine+Compute.swift` (435 lines).
- Design intent (from file structure + comments):
  - Build a value-only snapshot from SwiftData (`ChallengeEngine+Snapshot.swift`).
  - Compute progress off-main from snapshot (`ChallengeEngine+Compute.swift`).
  - Apply results back to SwiftData on MainActor (in facade).
- Review point:
  - Verify snapshot creation does not fetch more data than required (range-bounded fetch exists in `ensureCurrentChallenges`).

## Live Activity Extension Notes
- Target folder: `ShelfNotesLiveActivity/*`.
- Entry: `ShelfNotesLiveActivity/ShelfNotesLiveActivityBundle.swift` (WidgetBundle).
- UI: `ShelfNotesLiveActivity/ShelfNotesLiveActivityLiveActivity.swift` (lock screen / Dynamic Island layouts).
- Actions:
  - App Intents in `ShelfNotesLiveActivity/AppIntent.swift` and `ReadingSessionLiveActivityIntents.swift`.
- Data sharing:
  - App Group `group.de.marcfechner.Shelf-Notes` is present for both targets (entitlements).
  - Exact data transport mechanism between app ↔ extension (ActivityKit state, shared defaults/files) is **UNKNOWN** without tracing the intent handlers and app-side timer manager.

## Additional Hotspot Callouts (Concrete Reasons)
- `Shelf Notes/Stats/StatisticsView+Caching.swift`
  - **Concrete reason:** comment states the previous signature implementation sorted `books` by UUID (O(n log n)) and caused UI hitching; current implementation uses order-independent hashing (XOR + sum) to keep it O(n).
- `Shelf Notes/RootView.swift`
  - **Concrete reason:** schedules a cover backfill task on `.active` and cancels it when leaving active. If backfill ignores cancellation or saves too often, it can still contend with scrolling and CloudKit.
- `Shelf Notes/CSVImportExportView.swift`
  - **Concrete reason:** import/export can touch many books and perform file I/O; ensure any parsing/writes are chunked and cancellable (scan file for batching if you see lag during imports).

## Testing / Repro Checklists (Performance + Correctness)
- Library scrolling:
  - Large library (hundreds of books) → scroll list/grid; watch for hitching when many covers appear.
- Stats:
  - Open “Fortschritt” → Stats; expand/collapse sections repeatedly; verify `isUpdatingStatsCache` / `isUpdatingHeatmapCache` doesn’t get stuck and UI remains responsive.
  - Change year/scope → caches rebuild once; no repeated background churn.
- Cover backfill:
  - Fresh install with older data → verify thumbnails populate gradually; backgrounding the app cancels work (no runaway tasks).
- CloudKit/local-only toggle:
  - Force CloudKit init failure (e.g. iCloud off) → ensure failure screen appears and local-only mode is clearly indicated.