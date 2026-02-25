# ARCHITECTURE_NOTES

This document is intentionally technical and biased toward **correctness, maintainability, and performance**.  
Anything that can’t be confirmed from the current codebase is marked **UNKNOWN** and collected in **Open Questions**.

---

## Big Files List (Top 15 by lines)
Computed from `*.swift` files under `Shelf Notes/` (excluding `Assets.xcassets`).

- `Shelf Notes/BookImport/BookImportView/BookImportViewModel.swift` — **562** lines
  - Purpose: Google Books import orchestration (search, paging, dedupe, state machine).
  - Risk: Large async state surface; easy to introduce race/cancellation bugs and UI stalls.
- `Shelf Notes/Stats/StatisticsView+Data.swift` — **459** lines
  - Purpose: Derived slices for stats (scoping, year filtering, helper derivations).
  - Risk: Many computed properties with O(n) filters/sorts; can be reevaluated frequently.
- `Shelf Notes/Stats/StatisticsView+Sections.swift` — **456** lines
  - Purpose: SwiftUI section composition for Stats screen.
  - Risk: Large UI file; merge conflicts; can hide expensive view computations.
- `Shelf Notes/LibraryView/LibraryRowAppearanceSettingsSection.swift` — **454** lines
  - Purpose: Settings UI for library row appearance customization.
  - Risk: UI-only but large; high merge-conflict probability; hard to review.
- `Shelf Notes/Challenges/ChallengeEngine+Compute.swift` — **435** lines
  - Purpose: Pure challenge compute (value-only).
  - Risk: Algorithm changes affect correctness; needs deterministic tests.
- `Shelf Notes/Book.swift` — **428** lines
  - Purpose: Book model + helpers/migrations/derived values.
  - Risk: Model changes affect sync/migrations; large surface area.
- `Shelf Notes/LibraryView/LibraryView+Header.swift` — **418** lines
  - Purpose: Library header UI (search/filter controls, etc.).
  - Risk: Header state drives filtering; can cause frequent invalidations.
- `Shelf Notes/BookImport/BookImportView/BookImportViewModel+Tasks.swift` — **406** lines
  - Purpose: Google Books import orchestration (search, paging, dedupe, state machine).
  - Risk: Large async state surface; easy to introduce race/cancellation bugs and UI stalls.
- `Shelf Notes/BookDetail/BookDetailView+Bindings.swift` — **376** lines
  - Purpose: Computed bindings/derived state for book detail UI.
  - Risk: Derived state can trigger re-renders; risk of doing heavy work in bindings.
- `Shelf Notes/Stats/StatisticsView+Heatmap.swift` — **373** lines
  - Purpose: Heatmap rendering + data shaping for activity.
  - Risk: Potentially large date ranges; expensive loops + chart rendering.
- `Shelf Notes/CSVImportExportView.swift` — **364** lines
  - Purpose: CSV import/export UI + flows.
  - Risk: File I/O, parsing, and SwiftData writes can block UI if not carefully handled.
- `Shelf Notes/LibraryView/LibraryRowCoverView.swift` — **356** lines
  - Purpose: Cover rendering inside library rows.
  - Risk: Hot scrolling path; image decode/cache misses are visible as stutter.
- `Shelf Notes/ForYouSeedBuilder.swift` — **355** lines
  - Purpose: Builds “For You” seed queries/suggestions.
  - Risk: If called frequently, can do nontrivial aggregation.
- `Shelf Notes/AppearanceSettings/AppearancePreferences.swift` — **354** lines
  - Purpose: Appearance settings model + persistence keys/presets.
  - Risk: Global `@AppStorage` changes can rebuild view hierarchy.
- `Shelf Notes/CachedAsyncImage.swift` — **342** lines
  - Purpose: Image loading + memory/disk caching + local user cover store.
  - Risk: Hot path (scroll); thread-safety + memory pressure + disk IO.

---

## Hot Path Analysis

### Rendering / Scrolling (SwiftUI)
#### 1) Library list/grid filtering + sorting
- **Where**: `Shelf Notes/LibraryView/LibraryView+FilteringSorting.swift`
- **Why it’s a hot path**:
  - `filteredBooks` is a computed property that runs O(n) filters (status/tag/notes/search) and is triggered by:
    - search typing (`searchText`)
    - toggling filters in the header
    - any `@Query` update for books
  - This is expected, but it’s the primary “feel it immediately” path for large libraries.
- **Concrete risk patterns to watch for**:
  - Adding extra per-book string allocations inside the filter loop.
  - Sorting multiple times per view update (double `.sorted` calls, sorting in both `filteredBooks` and call-sites).

#### 2) Cover rendering in rows (scroll hitch risk)
- **Where**: `Shelf Notes/LibraryView/LibraryRowCoverView.swift`, `Shelf Notes/CachedAsyncImage.swift`, `Shelf Notes/CoverImageLoader.swift`
- **Why it’s a hot path**:
  - Any cache miss → disk IO + image decode while the user scrolls.
  - `LibraryRowCoverView.swift` already documents the goal “avoid main-thread JPEG decoding” and includes an in-memory thumbnail cache (`SyncedThumbnailMemoryCache`).
- **Failure modes**:
  - Decoding large images on the MainActor (would show as frame drops).
  - Unbounded cache growth (memory pressure) or too-small caches (eviction churn).

#### 3) Statistics screen derived computations
- **Where**:
  - View: `Shelf Notes/StatisticsView.swift`
  - Cache compute: `Shelf Notes/Stats/StatisticsView+Caching.swift`
  - Derived slices: `Shelf Notes/Stats/StatisticsView+Data.swift`
  - Heatmap: `Shelf Notes/Stats/StatisticsView+Heatmap.swift`
- **Why it’s a hot path**:
  - `StatisticsView.swift` triggers recomputation via `.task(id: statsKey)` / `.task(id: heatmapKey)`.
  - `computeStatsCache(for:)` and `computeHeatmapCache(for:)` are synchronous functions that:
    - filter the `books` array multiple times
    - build top lists (grouping + sorting)
    - generate monthly series and heatmap structures
  - Those compute functions currently run inline inside the `.task` closures (likely MainActor, because they set `@State`).
- **Concrete reasons (code-level)**:
  - Multi-pass O(n) filtering + O(k log k) sorting for “top lists” inside `computeStatsCache` (`Shelf Notes/Stats/StatisticsView+Caching.swift`).
  - Additional computed properties in `StatisticsView+Data.swift` (e.g. `yearOptions`) iterate books and sort; if referenced frequently, they add repeated work.
- **Observed mitigation already in place**:
  - Caching layer (`StatsCache`, `HeatmapCache`) avoids recomputing during minor UI changes (DisclosureGroup toggles etc.).
- **Still worth considering**:
  - Off-main crunching via a value-only snapshot (similar to the ChallengeEngine pattern).

#### 4) Timeline derived data rebuilds
- **Where**: `Shelf Notes/Timeline/ReadingTimelineView.swift`, `Shelf Notes/Timeline/ReadingTimelineViewModel.swift`
- **Why it’s a hot path**:
  - `ReadingTimelineViewModel.setBooks(...)` sorts entries (example: `.sorted { $0.date < $1.date }`) and rebuilds `items`.
  - It’s called from `.task(id: signature)` in the view, and the view model is `@MainActor`.
- **Risk**:
  - O(n log n) rebuild on main thread whenever the signature changes (usually only finished books, but still scales).

#### 5) Book detail tag suggestions / autocomplete
- **Where**: `Shelf Notes/BookDetailView.swift`, `Shelf Notes/TagsView/TagsIndexModel.swift`
- **Why it’s a hot path**:
  - Book detail updates as the user types; any O(n·tags) global tag aggregation here becomes instantly noticeable.
- **Current implementation (good)**:
  - Book detail uses a `TagsIndexModel` (`@StateObject var tagsIndexModel = TagsIndexModel()` in `Shelf Notes/BookDetailView.swift`) so counts are cached and not recomputed in the render path.

---

### Sync / Storage (SwiftData + CloudKit)
#### Container bootstrap and fallback modes
- **Where**: `Shelf Notes/AppContainerHostView.swift`
- **What it does**:
  - Builds a `ModelContainer` for either CloudKit (`cloudKitDatabase: .automatic`), local-only (`.none`), or in-memory.
  - Shows a dedicated failure UI (no crash) with retry + fallback options.
- **Risk / edge cases**:
  - Local-only mode is a separate store → users can accidentally create “split-brain” data if they keep using the app in local-only and then switch back.
  - The app mitigates this with a banner + alert, but you still need to treat this as a product decision.

#### One-time repairs / migrations on launch
- **Collection membership repair**
  - **Where**: `Shelf Notes/CollectionMembershipRepair.swift`
  - **Trigger**: `.task(id: mode)` in `Shelf Notes/AppContainerHostView.swift`
  - **Why risky**: it fetches **all books** and **all collections** and iterates them (MainActor). On large datasets this can delay “first interactive” time.
- **ReadingStatus migration**
  - **Where**: `ReadingStatusMigrator` in `Shelf Notes/Book.swift`
  - **Why risky**: any migration logic mistakes impact persisted data and sync correctness.
- **Cover thumbnail backfill**
  - **Where**: scheduled in `Shelf Notes/RootView.swift` → runs `CoverThumbnailer.backfillAllBooksIfNeeded(...)`
  - **Why risky**: this is IO-heavy; it must remain cooperative (batching + cancellation + yields).

#### CloudKit signals/diagnostics
- **Where**: `Shelf Notes/SyncDiagnostics.swift`, `Shelf Notes/SyncDiagnosticsView.swift`
- **What it provides**:
  - iCloud account status, network status, and “last local save” style breadcrumbs.
- **Limitations**:
  - SwiftData doesn’t expose granular CloudKit operation progress; this is “best possible” lightweight observability.

---

### Concurrency (Tasks, MainActor, Cancellation)
#### Good patterns already present
- **Value snapshot + off-main crunching** (recommended pattern)
  - `ChallengeEngine.ensureCurrentChallengesAndRefreshCompletion(...)` uses:
    - `MainActor.run { buildSnapshot(...) }` for SwiftData reads
    - `Task.detached` for pure computation (`Shelf Notes/Challenges/ChallengeEngine.swift`)
    - `MainActor.run { apply... }` for writes
- **Explicit cancellation**
  - Root cover backfill stores its `Task` handle and cancels it when leaving active state (`Shelf Notes/RootView.swift`).

#### Things to watch
- `.task` closures that do heavy compute + update `@State` without detaching.
  - Primary candidate: Stats cache compute (`Shelf Notes/StatisticsView.swift` + `Shelf Notes/Stats/StatisticsView+Caching.swift`)
- `@MainActor` ObservableObjects that do nontrivial CPU work (e.g. timeline rebuilds, tag index rebuilds).
  - Not necessarily wrong; just be intentional about the scaling profile.

---

## Refactor Map

### A) Concrete file splits (mechanical / maintainability)
1) Split `Shelf Notes/LibraryView/LibraryRowAppearanceSettingsSection.swift` (454 lines)
- Suggested cuts (UI-only sub-sections):
  - `LibraryRowAppearanceSettingsSection+Cover.swift`
  - `LibraryRowAppearanceSettingsSection+Typography.swift`
  - `LibraryRowAppearanceSettingsSection+Badges.swift`
  - `LibraryRowAppearanceSettingsSection+Spacing.swift`
  - `LibraryRowAppearanceSettingsSection+Reset.swift`
- Benefit: reduces merge conflicts and improves reviewability.  
- Risk: very low (pure UI composition).

2) Normalize Book detail components naming
- File `Shelf Notes/BookDetailComponents1.swift` appears to contain “BookDetailComponents”-style UI.
- Suggested action:
  - Rename to a purpose-based name (e.g. `BookDetailComponents+TagsPills.swift`) and move under `Shelf Notes/BookDetail/BookDetailComponents/` if that matches the module layout.
- Benefit: less confusion, fewer accidental duplicate components.
- Risk: low, but requires updating references/import order.

3) Further split `BookImportViewModel` responsibilities
- The view model is already partially split (`BookImportViewModel+Tasks.swift`, `+Filtering.swift`, `+LibraryIndex.swift`), but the base file is still the largest.
- Potential next split:
  - `BookImportViewModel+State.swift` (state machine + published properties)
  - `BookImportViewModel+Mapping.swift` (DTO → ImportedBook mapping, normalization)
  - `BookImportViewModel+Persistence.swift` (apply import to SwiftData / dedupe policies)

### B) Cache / Index ideas (performance)
1) Stats compute: snapshot + off-main
- Mirror the ChallengeEngine approach:
  - Create value-only “StatsSnapshot” (book fields + relevant session aggregates) built on MainActor from SwiftData.
  - Run `computeStatsCache` / `computeHeatmapCache` on a detached task.
  - Apply computed caches back on MainActor.
- Files:
  - `Shelf Notes/StatisticsView.swift`
  - `Shelf Notes/Stats/StatisticsView+Caching.swift`
  - (new) `Shelf Notes/Stats/StatisticsSnapshot.swift`
- Benefit: avoids MainActor contention when opening Stats or switching segments.
- Risk: low–medium (must keep output identical).

2) Timeline compute: consider off-main rebuild
- If finished-books count grows large, move `setBooks` rebuild (sort + year stats) off-main via snapshot.
- Files:
  - `Shelf Notes/Timeline/ReadingTimelineViewModel.swift`
  - (new) `Shelf Notes/Timeline/ReadingTimelineSnapshot.swift`
- Benefit: smoother first render and updates.
- Risk: low–medium.

3) Library filtering: incremental indices for tags/status
- If the library becomes very large, pre-index by status/tag into dictionaries and then filter against those sets rather than scanning all books for every keystroke.
- Files:
  - `Shelf Notes/LibraryView/LibraryView+FilteringSorting.swift`
  - (new) `LibraryIndexModel.swift`
- Benefit: reduces per-keystroke O(n) cost.
- Risk: medium (must keep index invalidation correct; may not be worth it unless dataset is huge).

### C) Pattern unification
- There are multiple “input signature” implementations:
  - `TagsIndexModel.computeSignature(...)` (`Shelf Notes/TagsView/TagsIndexModel.swift`)
  - `StatisticsView.booksSignature(...)` (`Shelf Notes/Stats/StatisticsView+Caching.swift`)
  - `ReadingTimelineViewModel.taskSignature(...)` (`Shelf Notes/Timeline/ReadingTimelineViewModel.swift`)
- Consider a shared helper (small, pure) to standardize “order-independent signature tokens”.

---

## Risks & Edge Cases
- **CloudKit vs local-only store divergence**: local-only is a separate dataset by design. Ensure UX messaging stays explicit.  
  Files: `Shelf Notes/AppContainerHostView.swift`
- **SwiftData relationship drift**:
  - Many-to-many Book ↔ Collection is manually mutated in helpers; drift existed historically (hence the repair).  
  Files: `Shelf Notes/BookCollection.swift`, `Shelf Notes/CollectionMembershipRepair.swift`
- **External storage + iCloud payload size**:
  - `Book.userCoverData` is synced (thumbnail) using `.externalStorage`. Large thumbnails could affect sync/storage.  
  File: `Shelf Notes/Book.swift`
- **Startup-time work**:
  - Launch `.task(id: mode)` does repairs + challenge ensures; scale testing required for large libraries.  
  Files: `Shelf Notes/AppContainerHostView.swift`
- **Device-only functionality**:
  - Barcode scanning uses VisionKit DataScanner (simulator limitations).  
  File: `Shelf Notes/BarcodeScannerSheet.swift`
- **StoreKit config**:
  - `ProManager.productID` is `"001"` with TODO comment → ensure production IDs are correct before release.  
  File: `Shelf Notes/ProManager.swift`

---

## Observability / Debuggability
- **Sync diagnostics UI**: `Shelf Notes/SyncDiagnosticsView.swift` (iCloud account + network + last save signals).
- **Sync diagnostics backend**: `Shelf Notes/SyncDiagnostics.swift` (NWPathMonitor + CKContainer checks).
- **ModelContext diagnostics**: `Shelf Notes/ModelContext+Diagnostics.swift` (**UNKNOWN**: how/where this is surfaced in UI).
- For performance investigations:
  - add signposts around Stats compute, cover decode paths, and import networking (**UNKNOWN**: current logging strategy).

---

## Open Questions (**UNKNOWN**)
1) **Minimum iOS version**: pbxproj sets `IPHONEOS_DEPLOYMENT_TARGET = 26.0`. Intended min iOS should be confirmed (SwiftData requires ≥ iOS 17).
2) **Secrets handling**: `Shelf Notes/config/secrets.xcconfig` contains a real API key in this ZIP. Is the repo supposed to keep secrets committed, or should it be gitignored?
3) **ModelContext diagnostics usage**: where is `ModelContext+Diagnostics.swift` used, and is it safe in production builds?
4) **Release strategy for local-only mode**: is local-only intended only as a debug fallback, or a user-facing offline mode (knowing it creates a separate dataset)?
5) **Cover thumbnail sizing policy**: what target dimensions/quality are intended for `userCoverData` thumbnails, and is there a cap enforced everywhere?

---

## First 3 Refactors I would do (P0)

### P0.1 — Stats crunching off the MainActor (Snapshot pattern)
- **Goal**: Remove UI hitching risk when opening Stats / switching segments by moving expensive aggregation off-main, without changing visible results.
- **Files**:
  - `Shelf Notes/StatisticsView.swift`
  - `Shelf Notes/Stats/StatisticsView+Caching.swift`
  - (new) `Shelf Notes/Stats/StatisticsSnapshot.swift`
- **Risk**: low–medium (must keep aggregation output identical; needs regression checks).
- **Expected benefit**: noticeably smoother navigation/scroll while caches compute; less MainActor contention.

### P0.2 — Split `LibraryRowAppearanceSettingsSection.swift` into sub-sections
- **Goal**: Reduce merge conflicts and review overhead in Settings UI.
- **Files**:
  - `Shelf Notes/LibraryView/LibraryRowAppearanceSettingsSection.swift`
  - (new) `Shelf Notes/LibraryView/LibraryRowAppearanceSettingsSection+*.swift`
- **Risk**: low (mechanical split, no logic change).
- **Expected benefit**: faster iteration on appearance settings, fewer “monster diff” reviews.

### P0.3 — Clean up Book detail component naming/placement
- **Goal**: Remove confusing “duplicate-ish” component file naming (`BookDetailComponents1.swift`) and align with the `BookDetail/BookDetailComponents/` structure.
- **Files**:
  - `Shelf Notes/BookDetailComponents1.swift`
  - `Shelf Notes/BookDetail/BookDetailComponents/*`
- **Risk**: low–medium (rename/move touches references; needs a quick search-and-compile pass).
- **Expected benefit**: improved code navigation, less accidental reuse of legacy components, fewer merge surprises.
