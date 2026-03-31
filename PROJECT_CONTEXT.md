# PROJECT_CONTEXT.md

## TL;DR
**Shelf Notes** is an iOS app for managing a personal library and reading activity (books, tags, collections, sessions, goals, stats, challenges) with **SwiftData + CloudKit** sync, plus a **Live Activity** extension for an in-progress reading timer. Entry point: `Shelf Notes/Shelf_NotesApp.swift` → `AppContainerHostView` → `RootView`.

- Platforms: iOS (Live Activities enabled in `Shelf Notes/Info.plist`)
- Minimum iOS: build settings include **iOS 26.0** and **iOS 26.2** (`Shelf Notes.xcodeproj/project.pbxproj`). Exact per-target minimum for the app is **UNKNOWN**; Live Activity target appears to use **26.2**.

## Key Concepts / Domänenbegriffe
- **Book**: Core entity for a book in the library (`Shelf Notes/Book.swift`).
- **ReadingSession**: A timed/logged reading session for a book (`Shelf Notes/ReadingSession.swift`).
- **ReadingGoal**: Yearly goal (“X books”) (`Shelf Notes/ReadingGoal.swift`).
- **Collection / Liste**: Named set of books (many-to-many) (`Shelf Notes/BookCollection.swift`).
- **Tags**: Normalized `[String]` on `Book` + library-wide tag index (`Shelf Notes/TagsView/TagsIndexModel.swift`, `Shelf Notes/TagNormalization.swift`).
- **Challenges**: Persisted weekly/monthly challenge records computed from sessions/books (`Shelf Notes/Challenges/ChallengeModels.swift`, `Shelf Notes/Challenges/ChallengeEngine*.swift`).
- **Cover thumbnail**: Synced JPEG thumbnail for covers (`Book.userCoverData` + `CoverThumbnailer/*`), full-res user covers stay local on disk (via `UserCoverStore`).

## Architecture Map (Text)
- **App bootstrap & storage**
  - `Shelf Notes/Shelf_NotesApp.swift` (App entry)
  - `Shelf Notes/AppContainerHostView.swift`
    - `AppBootstrapper` chooses **CloudKit / Local-only / In-memory** and creates `ModelContainer`.
    - Runs one-time repairs: `CollectionMembershipRepair.repairIfNeeded(...)`, `ChallengeEngine.ensureCurrentChallengesAndRefreshCompletion(...)`.
- **Data model (SwiftData)**
  - `Book`, `ReadingSession`, `ReadingGoal`, `BookCollection`, `ChallengeRecord`
- **Feature modules (mostly SwiftUI + small ViewModels)**
  - Library (`Shelf Notes/LibraryView/*`)
  - Book detail (`Shelf Notes/BookDetail/*` + some top-level book detail files)
  - Import/Add book (`Shelf Notes/BookImport/*`, `Shelf Notes/AddBook/*`, `Shelf Notes/GoogleBooks*.swift`)
  - Progress hub / Stats / Timeline (`Shelf Notes/ProgressHub/*`, `Shelf Notes/Stats/*`, `Shelf Notes/Timeline/*`)
  - Tags (`Shelf Notes/TagsView/*`)
  - Settings / Appearance (`Shelf Notes/SettingsView.swift`, `Shelf Notes/AppearanceSettings/*`)
  - Timer + Live Activity (Live Activity target in `ShelfNotesLiveActivity/*`; app-side timer manager file path: **UNKNOWN**)
- **Infrastructure / shared helpers**
  - Image/covers: `Shelf Notes/CoverImageLoader.swift`, `Shelf Notes/CachedAsyncImage.swift`, `Shelf Notes/CoverThumbnailer/*`
  - Diagnostics: `Shelf Notes/SyncDiagnostics*.swift`
  - CSV import/export: `Shelf Notes/CSVCodec.swift`, `Shelf Notes/CSVImportExportView.swift`

Dependencies are mostly “feature → model + shared infra”. There is no explicit DI container; environment objects are used for cross-feature state (`RootView`: `ProManager`, `ReadingTimerManager`).

## Folder Map
- `AddBook` → Add-book flows (search/import/manual add) + related view models/cards.
- `AppearanceSettings` → Appearance/typography/density/tint settings models + storage keys.
- `BookDetail` → Book detail screen split into components/bindings/actions.
- `BookImport` → Google Books import flow, DTO mapping, view models, tasks.
- `Challenges` → Challenge models + engine (compute & scheduling).
- `CoverThumbnailer` → Thumbnail generation/backfill for covers; ImageIO + remote fetch + apply.
- `LibraryView` → Library list/grid + row views + appearance settings sections.
- `ProgressHub` → 'Fortschritt' hub bundling stats/goals/timeline/challenges.
- `Shared` → Shared UI components, helpers, extensions used across features.
- `Stats` → Statistics UI + caches + heatmap.
- `TagsView` → Tags screen + TagsIndexModel (cached tag counts) etc.
- `Timeline` → Reading timeline + view model.
- `config` → Build configuration files (.xcconfig), currently includes secrets.

Other notable top-level files in `Shelf Notes/`:
- App bootstrap & container: `AppContainerHostView.swift`
- Root navigation: `RootView.swift`
- Models: `Book.swift`, `ReadingSession.swift`, `ReadingGoal.swift`, `BookCollection.swift`, `Challenges/ChallengeModels.swift`
- Import + external API: `GoogleBooksClient.swift`, `GoogleBooksDTO.swift`, `GoogleVolumeBookMapper.swift`
- Covers/caching: `CoverImageLoader.swift`, `CachedAsyncImage.swift`, `CoverThumbnailer/*`
- CSV: `CSVCodec.swift`, `CSVImportExportView.swift`

## Data Model Map (Entities / Relationships / Key Fields)

### `Book` — `Shelf Notes/Book.swift`
Stored fields (selection):
- `id (UUID)`
- `title, author`
- `statusRawValue / status (ReadingStatus)`
- `tags [String], notes`
- `readFrom/readTo (Date?)`
- `pageCount (Int?)`
- `readingSessions (1:n, cascade)`
- `collections (n:m, optional)`
- `thumbnailURL (String?) + coverURLCandidates [String]`
- `userCoverData (Data?, @Attribute(.externalStorage))`
- `userCoverFileName (String?)`

Relationships:
- **`readingSessions: [ReadingSession]?`** with `@Relationship(deleteRule: .cascade, inverse: \ReadingSession.book)` (one-to-many)
- **`collections: [BookCollection]?`** (many-to-many; stored as optional array for CloudKit compatibility)

### `ReadingSession` — `Shelf Notes/ReadingSession.swift`
Stored fields:
- `id (UUID)`
- `book (Book?)`
- `startedAt, endedAt, durationSeconds`
- `pagesRead (Int?)`
- `note (String?)`
- `createdAt`

Relationship:
- `book: Book?` (inverse is `Book.readingSessions`; inverse macro is defined on `Book` side)

### `BookCollection` — `Shelf Notes/BookCollection.swift`
Stored fields:
- `id (UUID)`
- `name`
- `createdAt/updatedAt`
- `books (n:m, optional)`

Relationship:
- `books: [Book]?` (many-to-many; optional)

### `ReadingGoal` — `Shelf Notes/ReadingGoal.swift`
Stored fields:
- `year`
- `targetCount`
- `updatedAt`

### `ChallengeRecord` — `Shelf Notes/Challenges/ChallengeModels.swift`
Persisted fields (important ones):
- `periodStart`, `periodEnd`
- `kindRawValue`, `metricRawValue`
- `title`, `detail`
- `targetValue`
- `createdAt`, `completedAt`, `acknowledgedAt`
- `rerollsUsed`, `rerolledAt`

Progress/completion is computed by `ChallengeEngine` (see `Shelf Notes/Challenges/ChallengeEngine+Compute.swift`).

## Sync/Storage (SwiftData / CloudKit / Caches / Migration / Offline)

### SwiftData container + CloudKit
- Container creation is centralized in `Shelf Notes/AppContainerHostView.swift` (`ModelContainerFactory.makeContainer`).
- Schema: `Book`, `ReadingSession`, `ReadingGoal`, `BookCollection`, `ChallengeRecord` (see `ModelContainerFactory.schema`).
- CloudKit database: `.automatic` for normal mode; `.none` for explicit local-only mode.
- **Store separation** (see `StoreName` + `storeURL(for:)`):
  - Cloud store: `ShelfNotesCloud`
  - Local-only store: `ShelfNotesLocal`
  - Stored under `Application Support/ShelfNotes/SwiftData/`
- **Offline behavior**: if CloudKit init fails, show `ModelContainerFailureView` with options (retry / local-only / in-memory).

### Relationship integrity repair
- `Shelf Notes/CollectionMembershipRepair.swift`: one-time repair to dedupe and unify `Book` ↔ `BookCollection` membership.

### Migrations / one-time data repairs
- `RootView.task`: calls `ReadingStatusMigrator.migrateIfNeeded(...)` (implemented in `Shelf Notes/Book.swift`).
- Cover thumbnail backfill: `RootView` schedules a one-time backfill (`did_run_cover_backfill_v2`) using `CoverThumbnailer` (`Shelf Notes/CoverThumbnailer/*`).

### Caches / local storage
- Image caching:
  - Memory cache (`ImageMemoryCache`) + disk cache (`ImageDiskCache`) in `Shelf Notes/CachedAsyncImage.swift`.
  - Loader keeps work off MainActor via background queue (`Shelf Notes/CoverImageLoader.swift`).
- Covers:
  - Synced thumbnail bytes in `Book.userCoverData` (`@Attribute(.externalStorage)`).
  - Full-res user covers are stored locally on disk via `UserCoverStore` (definition location: **UNKNOWN** without further trace).

## UI Map (Screens / Navigation / Sheets)

### Root navigation (tabs) — `Shelf Notes/RootView.swift`
`TabView` with:
- **Bibliothek** → `LibraryView()` (`Shelf Notes/LibraryView/LibraryView.swift`)
- **Fortschritt** → `ProgressHubView()` (`Shelf Notes/ProgressHub/ProgressHubView.swift`)
- **Listen** → `CollectionsView()` (`Shelf Notes/CollectionsView.swift`)
- **Tags** → `TagsView()` (`Shelf Notes/TagsView/TagsView.swift`)
- **Einstellungen** → `SettingsView()` (`Shelf Notes/SettingsView.swift`)

Global environment objects:
- `ProManager` (`Shelf Notes/ProManager.swift`)
- `ReadingTimerManager` (injected in `RootView`; file path **UNKNOWN** until traced)

Global sheets:
- CSV first-run import (`CSVImportExportView`) — `RootView.sheet(isPresented:)`
- Timer completion sheet (`TimerSessionCompletionSheet`) — `RootView.sheet(item:)`

### Progress hub
- Aggregates: stats, goals, timeline, challenges (`Shelf Notes/ProgressHub/ProgressHubView.swift`).
- Stats: `Shelf Notes/StatisticsView.swift` + `Shelf Notes/Stats/StatisticsView+*.swift` (cached aggregations + heatmap).

### Live Activity (separate target)
- Target folder: `ShelfNotesLiveActivity/*`
- Uses App Group: `group.de.marcfechner.Shelf-Notes` (entitlements)
- App Intents: `ShelfNotesLiveActivity/AppIntent.swift`, `ReadingSessionLiveActivityIntents.swift`

## Build & Configuration

### Targets
- App: `Shelf Notes` (bundle id in project: `de.marcfechner.Shelf-Notes`)
- Widget/Live Activity extension target: `ShelfNotesLiveActivity` (bundle id: `de.marcfechner.Shelf-Notes.ShelfNotesLiveActivity`)
- Tests: `Shelf NotesTests`, `Shelf NotesUITests`

### Entitlements
- `Shelf Notes/Shelf_Notes.entitlements` (iCloud CloudKit + App Group + push env)
- `ShelfNotesLiveActivityExtension.entitlements` (App Group only)

### Info.plist keys
- `Shelf Notes/Info.plist` (GOOGLE_BOOKS_API_KEY placeholder, camera/photo permissions, background remote-notification, Live Activities enabled)
- `ShelfNotesLiveActivity/Info.plist` (WidgetKit extension point)

### .xcconfig / Secrets handling
- `Shelf Notes/config/base.xcconfig` includes `secrets.xcconfig`.
- `Shelf Notes/config/secrets.xcconfig` contains `GOOGLE_BOOKS_API_KEY = ...` **in plaintext**. Treat as compromised and rotate.

### Deployment target
- Project contains deployment targets `26.0` and `26.2` in `project.pbxproj` (exact per-target mapping: app **UNKNOWN**, Live Activity appears to use `26.2` based on its build settings block).

### External dependencies
- Swift Packages: **none found** in `project.pbxproj` (no `XCRemoteSwiftPackageReference`).

## Conventions (Patterns / Do & Don’t)
- **SwiftData + CloudKit**
  - Avoid `@Attribute(.unique)` (explicitly noted in model files).
  - Keep relationships **optional** for CloudKit compatibility (`Book.collections`, `BookCollection.books`).
  - Define **inverse** relationships (`Book.readingSessions` has inverse `\ReadingSession.book`).
- **Derived data**
  - Prefer cached/indexed aggregation models over O(n) recompute in `body` (e.g. tags in `BookDetailView+Bindings.swift` use `TagsIndexModel`).
- **Long-running work**
  - Prefer `.task(id:)` with stable IDs for cancellation (pattern used in `CachedAsyncImage`, `AppContainerHostView`).
- **Safety-first launch**
  - Container creation must not crash; present actionable failure UI (`ModelContainerFailureView`).

## How to work on this project (Setup Steps)
1. Open `Shelf Notes.xcodeproj`.
2. Ensure signing & capabilities are set for:
   - iCloud (CloudKit) container: `iCloud.de.marcfechner.Shelf-Notes` (`Shelf Notes/Shelf_Notes.entitlements`)
   - App Group: `group.de.marcfechner.Shelf-Notes` (app + Live Activity extension)
3. **Secrets**: remove committed API key; keep a local-only `secrets.xcconfig` (see Quick Wins).
4. Run on a device (Live Activities are device-dependent; simulator support can be limited).
5. Use `SyncDiagnosticsView` (`Shelf Notes/SyncDiagnosticsView.swift`) for CloudKit diagnosis if exposed in UI (wiring is **UNKNOWN**).

Where to start for new features:
- Add a new screen: follow the pattern in `RootView` (tab or push) and keep feature code inside its folder.
- Add new persistent data: update `ModelContainerFactory.schema` in `AppContainerHostView.swift` and create a new `@Model` type with CloudKit-safe defaults.

## Quick Wins (max 10, concrete)
1. **Rotate and remove the committed Google Books API key**: `Shelf Notes/config/secrets.xcconfig` contains a real key; treat it as leaked and rotate it.
2. Add `secrets.xcconfig.template` and gitignore the real secrets file.
3. Centralize singletons/services (e.g. tag index, cover pipeline) in one place instead of scattering `@StateObject` creation.
4. Audit long-running `.task {}` usage in large views (Stats / Import / Library) for cancellation and stale state capture.
5. Add lightweight logging/metrics around cover backfill and stats cache rebuilds (keys already exist: `did_run_cover_backfill_v2`).
6. Split `BookImportViewModel.swift` by responsibility (network vs mapping vs persistence vs UI state).
7. Make local-only mode visible/persistent in Settings (currently banner + alert).
8. Add a debug screen listing data repairs/migrations state (ReadingStatusMigrator / CollectionMembershipRepair / cover backfill).
9. Ensure heavy computed properties in `Stats/StatisticsView+Data.swift` are only used to build caches, not recomputed during render.
10. Add `Docs/` folder in repo and keep these markdowns versioned with migration notes.

## Open Questions (UNKNOWN)
- Minimum iOS version per **app target** (project contains 26.0 and 26.2, but exact mapping for the app target is not conclusively located).
- Location/implementation details of `UserCoverStore` and `ReadingTimerManager` (referenced from `Book.swift` / `RootView`, but not traced here).
- Where `SyncDiagnosticsView` is wired into navigation (file exists, linkage not traced).

## Typical Workflows
### Add a new `@Model` entity (SwiftData + CloudKit-safe)
Checklist:
- Create `Shelf Notes/<FeatureOrModel>/<NewModel>.swift` with `@Model final class ...`.
- Provide **defaults for all non-optional properties** (CloudKit requirement; see `ReadingGoal`, `ReadingSession`).
- Avoid `@Attribute(.unique)` (explicit project convention).
- If you add relationships:
  - Make them optional (`var foo: OtherModel?` / `[OtherModel]?`) for CloudKit.
  - Ensure there is a clear inverse (use `@Relationship(inverse: ...)` on one side; see `Book.readingSessions`).
- Add the model type to `ModelContainerFactory.schema` in `Shelf Notes/AppContainerHostView.swift`.
- Add a small migration/repair if needed (pattern: one-time `...Repair` run in `AppContainerHostView` task with a per-store scope).

### Add a new tab or hub section
Checklist:
- Add the view under a feature folder (`LibraryView`, `ProgressHub`, etc.).
- Wire it into `RootView.TabView` (or into `ProgressHubView` if it’s a sub-feature of “Fortschritt”).
- If the screen needs shared state, prefer `EnvironmentObject` injection from `RootView` (pattern: `ProManager`, `ReadingTimerManager`).
- Avoid expensive computed properties in `body`; use cache models or `.task(id:)` to build snapshots.

### Add a new setting (AppStorage-based)
Checklist:
- Add a storage key constant (see `AppearanceStorageKey` usage in `RootView`).
- Keep defaults stable and migrate old keys if you rename them.
- For complex settings UIs, split into sections/components (pattern already used in `LibraryView` + Appearance).

### Add/modify Google Books import behavior
Where to look:
- Networking: `Shelf Notes/GoogleBooksClient.swift`
- DTOs: `Shelf Notes/GoogleBooksDTO.swift`
- Mapping into `Book`: `Shelf Notes/GoogleVolumeBookMapper.swift` + `Shelf Notes/Book+Importing.swift`
- UI + orchestration: `Shelf Notes/BookImport/BookImportView/BookImportViewModel*.swift`