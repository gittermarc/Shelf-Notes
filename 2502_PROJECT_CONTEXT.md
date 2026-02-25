# PROJECT_CONTEXT

## TL;DR
Shelf Notes is an iOS reading tracker built with **SwiftUI** + **SwiftData** and optional **iCloud/CloudKit sync**. Core features: a personal library of books, reading sessions (time + optional pages), yearly reading goals, statistics (charts + top lists), a reading timeline, tags, collections/lists, and periodic challenges. **Minimum iOS is at least iOS 17** (SwiftData). The Xcode project currently sets `IPHONEOS_DEPLOYMENT_TARGET = 26.0` (see `Shelf Notes.xcodeproj/project.pbxproj`) — verify that this is intentional.

---

## Key Concepts (Domain Glossary)
- **Book**: Central entity. Status (`toRead` / `reading` / `finished`), metadata (author, ISBN, categories, publisher, language), tags, notes, optional read period (`readFrom`/`readTo`), and a synced thumbnail cover.  
  - Source: `Shelf Notes/Book.swift`
- **ReadingSession**: One session for one book (start/end timestamps, cached duration seconds, optional pages + note).  
  - Source: `Shelf Notes/ReadingSession.swift`
- **ReadingGoal**: Target number of finished books per year.  
  - Source: `Shelf Notes/ReadingGoal.swift`
- **BookCollection**: Named list of books (many-to-many).  
  - Source: `Shelf Notes/BookCollection.swift`
- **ChallengeRecord**: Persisted weekly/monthly challenge definition + progress/completion metadata; progress computed from sessions/books.  
  - Source: `Shelf Notes/Challenges/ChallengeModels.swift`
- **CloudKit vs Local-only store**: App can run CloudKit-backed (default), explicit **local-only** fallback, or in-memory emergency mode. Local-only uses a separate persistent store (separate data set).  
  - Source: `Shelf Notes/AppContainerHostView.swift`
- **Cover pipeline**:
  - A small **synced** JPEG thumbnail is stored in SwiftData (`Book.userCoverData` with `.externalStorage`).
  - Full-resolution user photo covers remain **local on disk** (`UserCoverStore`).
  - Remote covers are fetched and cached on disk (`ImageDiskCache`) and/or thumbnailed via `CoverThumbnailer`.  
  - Sources: `Shelf Notes/Book.swift`, `Shelf Notes/CachedAsyncImage.swift`, `Shelf Notes/CoverThumbnailer/*`

---

## Architecture Map (Text)
**UI (SwiftUI Views)**  
→ reads/writes via `@Query` + `@Environment(\.modelContext)`  
→ calls **Domain Services** for heavier work (thumbnails, challenges, stats caching, import, diagnostics)  
→ persists to **SwiftData ModelContainer** (CloudKit or local-only)  
→ uses **local caches** (disk images, local user covers) where CloudKit sync is not desired/possible.

Concrete components:
- **App bootstrap**: `Shelf Notes/Shelf_NotesApp.swift` → `Shelf Notes/AppContainerHostView.swift` → `Shelf Notes/RootView.swift`
- **Persistence**: `ModelContainerFactory` (`Shelf Notes/AppContainerHostView.swift`) defines the SwiftData schema and store configuration.
- **Domain services / engines**:
  - Challenges: `Shelf Notes/Challenges/ChallengeEngine*.swift`
  - Cover thumbnails: `Shelf Notes/CoverThumbnailer/*`
  - Import: `Shelf Notes/GoogleBooksClient.swift` + `Shelf Notes/BookImport/*`
  - Sync diagnostics: `Shelf Notes/SyncDiagnostics.swift`, `Shelf Notes/SyncDiagnosticsView.swift`

---

## Folder Map
- `Shelf Notes/` — App source root (SwiftUI views, SwiftData models, services/utilities).
  - Key app bootstrap/navigation:
    - `Shelf Notes/Shelf_NotesApp.swift` — `@main` entry point.
    - `Shelf Notes/AppContainerHostView.swift` — SwiftData container bootstrap (CloudKit/local-only/in-memory) + error UI.
    - `Shelf Notes/RootView.swift` — Tab bar root + global appearance + one-time repairs/backfills.
  - Cross-cutting utilities/services live mostly at root level (e.g. `SyncDiagnostics.swift`, `CoverImageLoader.swift`, `CachedAsyncImage.swift`).
- `Shelf Notes/AddBook/` — feature folder (**5** Swift files). Examples: `AddBook/AddBookComponents.swift`, `AddBook/AddBookSheet.swift`, `AddBook/AddBookView+Cards.swift`, `AddBook/AddBookView.swift`, `AddBook/AddBookViewModel.swift`
- `Shelf Notes/AppearanceSettings/` — feature folder (**6** Swift files). Examples: `AppearanceSettings/AppearancePreferences.swift`, `AppearanceSettings/AppearanceSettingsView+Colors.swift`, `AppearanceSettings/AppearanceSettingsView+DensityAndLayout.swift`, `AppearanceSettings/AppearanceSettingsView+Presets.swift`, `AppearanceSettings/AppearanceSettingsView+Typography.swift`…
- `Shelf Notes/BookDetail/` — feature folder (**22** Swift files). Examples: `BookDetail/BookDetailComponents/BookDetailComponents+Cards.swift`, `BookDetail/BookDetailComponents/BookDetailComponents+Cover.swift`, `BookDetail/BookDetailComponents/BookDetailComponents+Header.swift`, `BookDetail/BookDetailComponents/BookDetailComponents+Helpers.swift`, `BookDetail/BookDetailComponents/BookDetailComponents.swift`…
- `Shelf Notes/BookImport/` — feature folder (**13** Swift files). Examples: `BookImport/BookImportCategoryNormalizer.swift`, `BookImport/BookImportComponents.swift`, `BookImport/BookImportFilterEngine.swift`, `BookImport/BookImportQueryBuilder.swift`, `BookImport/BookImportResultsView.swift`…
- `Shelf Notes/Challenges/` — feature folder (**6** Swift files). Examples: `Challenges/ChallengeEngine+Compute.swift`, `Challenges/ChallengeEngine+Snapshot.swift`, `Challenges/ChallengeEngine.swift`, `Challenges/ChallengeModels.swift`, `Challenges/ChallengesSummaryCard.swift`…
- `Shelf Notes/CoverThumbnailer/` — feature folder (**5** Swift files). Examples: `CoverThumbnailer/CoverThumbnailer+Apply.swift`, `CoverThumbnailer/CoverThumbnailer+Backfill.swift`, `CoverThumbnailer/CoverThumbnailer+ImageIO.swift`, `CoverThumbnailer/CoverThumbnailer+RemoteFetch.swift`, `CoverThumbnailer/CoverThumbnailer.swift`
- `Shelf Notes/LibraryView/` — feature folder (**12** Swift files). Examples: `LibraryView/LibraryAppearanceSettingsView.swift`, `LibraryView/LibraryRowAppearanceSettingsSection.swift`, `LibraryView/LibraryRowCoverView.swift`, `LibraryView/LibraryView+Actions.swift`, `LibraryView/LibraryView+AlphaIndex.swift`…
- `Shelf Notes/ProgressHub/` — feature folder (**2** Swift files). Examples: `ProgressHub/ProgressHubMetricsModel.swift`, `ProgressHub/ProgressHubView.swift`
- `Shelf Notes/Stats/` — feature folder (**6** Swift files). Examples: `Stats/StatisticsComponents.swift`, `Stats/StatisticsView+Caching.swift`, `Stats/StatisticsView+Data.swift`, `Stats/StatisticsView+Formatting.swift`, `Stats/StatisticsView+Heatmap.swift`…
- `Shelf Notes/TagsView/` — feature folder (**2** Swift files). Examples: `TagsView/TagsIndexModel.swift`, `TagsView/TagsView.swift`
- `Shelf Notes/Timeline/` — feature folder (**5** Swift files). Examples: `Timeline/ReadingTimelineBookRowView.swift`, `Timeline/ReadingTimelineMiniMapView.swift`, `Timeline/ReadingTimelineView.swift`, `Timeline/ReadingTimelineViewModel.swift`, `Timeline/ReadingTimelineYearSectionView.swift`
- `Shelf Notes/Stats/` — Statistics UI + caching/aggregation helpers (Charts integration).
- `Shelf Notes/TagsView/` — Tags screen + cached tag counts (`TagsIndexModel`).
- `Shelf Notes/Timeline/` — Reading timeline screen + view model.
- `Shelf Notes/config/` — build configuration (`base.xcconfig` includes `secrets.xcconfig`).
- `Shelf Notes/Assets.xcassets` — app assets.

---

## Data Model Map (SwiftData)
### `Book` (`Shelf Notes/Book.swift`)
Relationships
- `collections: [BookCollection]?` (many-to-many, optional for CloudKit constraints)
- `readingSessions: [ReadingSession]?` with `@Relationship(deleteRule: .cascade, inverse: \ReadingSession.book)`

Important fields (selected)
- Identity: `id: UUID`
- Core: `title`, `author`, `createdAt`, `statusRawValue`, `tags: [String]`, `notes`
- Read range: `readFrom`, `readTo`
- Import metadata: `googleVolumeID`, `isbn13`, `thumbnailURL`, `coverURLCandidates: [String]`
- Synced cover thumb: `@Attribute(.externalStorage) userCoverData: Data?`
- Local cover pointer: `userCoverFileName: String?`
- Ratings: six integer criteria + derived averages (`userRatingAverage`, …)

Migration/repair hooks
- One-time status code migration: `ReadingStatusMigrator.migrateIfNeeded(...)` in `Shelf Notes/Book.swift`

### `ReadingSession` (`Shelf Notes/ReadingSession.swift`)
- Identity: `id: UUID`
- Relationship: `book: Book?` (inverse is `Book.readingSessions`)
- Timing: `startedAt`, `endedAt`, cached `durationSeconds`
- Optional: `pagesRead`, `note`, `createdAt`

### `ReadingGoal` (`Shelf Notes/ReadingGoal.swift`)
- `year`, `targetCount`, `updatedAt`

### `BookCollection` (`Shelf Notes/BookCollection.swift`)
- Identity: `id: UUID`
- `name`, `createdAt`, `updatedAt`
- Relationship: `books: [Book]?` (many-to-many, optional for CloudKit constraints)

### `ChallengeRecord` (`Shelf Notes/Challenges/ChallengeModels.swift`)
- Identity: `id: UUID`
- Period bounds: `periodStart`, `periodEnd`
- Kind/metric: `kindRawValue`, `metricRawValue` (`ChallengeKind` / `ChallengeMetric`)
- Content: `title`, `detail`
- Target: `targetValue`
- Completion/progress metadata (see file for full list)

---

## Sync / Storage
### SwiftData container bootstrap
- Container creation + mode switching is centralized in `Shelf Notes/AppContainerHostView.swift`.
- Schema is explicitly enumerated in `ModelContainerFactory.schema` (Book, ReadingSession, ReadingGoal, BookCollection, ChallengeRecord).
- Store configuration:
  - CloudKit: `ModelConfiguration(... cloudKitDatabase: .automatic)`
  - Local-only fallback: `cloudKitDatabase: .none` (separate store name + URL)
  - In-memory: `isStoredInMemoryOnly: true`

### Store separation (important behavior)
- CloudKit store and Local-only store are different persistent stores (see `StoreName.cloud` vs `StoreName.local` in `Shelf Notes/AppContainerHostView.swift`).
- Consequence: local-only mode is **not** “offline queueing”; it is a **separate dataset**. UI shows a banner and an alert.

### Repairs / migrations executed on app start
- Collection membership repair (one-time per store scope):  
  `CollectionMembershipRepair.repairIfNeeded(...)` in `Shelf Notes/CollectionMembershipRepair.swift`, triggered from `.task(id: mode)` in `Shelf Notes/AppContainerHostView.swift`.
- Challenge ensure + completion refresh:  
  `ChallengeEngine.ensureCurrentChallengesAndRefreshCompletion(...)` triggered from the same startup task.
- Deferred cover thumbnail backfill (one-time):  
  `CoverThumbnailer.backfillAllBooksIfNeeded(...)` scheduled from `Shelf Notes/RootView.swift`.

### Local caches / files
- Memory cover cache: `ImageMemoryCache` in `Shelf Notes/CachedAsyncImage.swift`
- Disk cover cache (local-only): `ImageDiskCache` in `Shelf Notes/CachedAsyncImage.swift` (Caches directory)
- Local user cover storage: `UserCoverStore` in `Shelf Notes/CachedAsyncImage.swift` (Application Support / `user-covers/`)
- SwiftData stores: Application Support / `ShelfNotes/SwiftData/*.store` (see `storeURL(...)` in `Shelf Notes/AppContainerHostView.swift`)

---

## UI Map (Screens + Navigation)
### App entry + global navigation
- `Shelf Notes/Shelf_NotesApp.swift` shows `AppContainerHostView`.
- `AppContainerHostView` decides between:
  - loading state
  - ready state (`RootView` with `.modelContainer(container)`)
  - failure UI (`ModelContainerFailureView`)

### Tabs (RootView)
`Shelf Notes/RootView.swift` hosts a `TabView` with:
1) **Bibliothek** → `LibraryView()` (`Shelf Notes/LibraryView/LibraryView.swift`)  
2) **Fortschritt** → `ProgressHubView()` (`Shelf Notes/ProgressHub/ProgressHubView.swift`)  
   - Links to Stats, Goals, Timeline, Challenges (via `NavigationStack` in ProgressHub)
3) **Listen** → `CollectionsView()` (`Shelf Notes/CollectionsView.swift`)
4) **Tags** → `TagsView()` (`Shelf Notes/TagsView/TagsView.swift`)
5) **Einstellungen** → `SettingsView()` (`Shelf Notes/SettingsView.swift`)

### Key flows (selected)
- Book detail: `Shelf Notes/BookDetailView.swift` + `Shelf Notes/BookDetail/*`
  - Session logging sheets: `QuickSessionLogSheet.swift`, `AllSessionsListSheet.swift`
  - Reading timer manager: `ReadingTimerManager*.swift` (EnvironmentObject from RootView)
- Add/import books:
  - Manual add: `ManualBookAddSheet.swift`
  - Add book flow: `Shelf Notes/AddBook/*`
  - Google Books import UI: `Shelf Notes/BookImport/*` (View + ViewModel)
  - Barcode scanning: `BarcodeScannerSheet.swift` (VisionKit DataScanner; device-only)
- Stats:
  - `StatisticsView.swift` + `Shelf Notes/Stats/*` (caching + charts + heatmap)
- Challenges:
  - `Shelf Notes/Challenges/ChallengesView.swift` + `ChallengeEngine*`
- CSV import/export:
  - `CSVImportExportView.swift`, `CSVCodec.swift`

---

## Build & Configuration
### Xcode project + settings
- Project file: `Shelf Notes.xcodeproj/project.pbxproj`
- App target bundle id: `de.marcfechner.Shelf-Notes` (see `PRODUCT_BUNDLE_IDENTIFIER` in pbxproj)
- Team: `HPJKAPZ8A3` (see `DEVELOPMENT_TEAM` in pbxproj)
- Swift version: `SWIFT_VERSION = 5.0` (pbxproj)
- Deployment target: `IPHONEOS_DEPLOYMENT_TARGET = 26.0` (pbxproj) **→ verify**

### Config files / secrets
- Base config: `Shelf Notes/config/base.xcconfig`  
  - includes `secrets.xcconfig`
- Secrets: `Shelf Notes/config/secrets.xcconfig` contains `GOOGLE_BOOKS_API_KEY` (value should be treated as sensitive).
- Info.plist: `Shelf Notes/Info.plist` reads the key via `$(GOOGLE_BOOKS_API_KEY)`.

### Entitlements + privacy
- Entitlements: `Shelf Notes/Shelf_Notes.entitlements`
  - iCloud container id: `iCloud.de.marcfechner.Shelf-Notes`
  - iCloud services: CloudKit
- Privacy manifest: `Shelf Notes/PrivacyInfo.xcprivacy`
- Info.plist permissions:
  - Camera usage (ISBN scan): `NSCameraUsageDescription`
  - Photo library usage (user cover): `NSPhotoLibraryUsageDescription`
- Background mode: `UIBackgroundModes` includes `remote-notification` (likely for CloudKit pushes).

### Dependencies
- No Swift Package Manager dependencies detected in `project.pbxproj` (no `XCRemoteSwiftPackageReference` entries).
- Apple frameworks used (selected):
  - SwiftData, CloudKit, StoreKit, Vision/VisionKit, Charts (guarded with `#if canImport(Charts)`), Network.

---

## Conventions (Do / Don’t)
Patterns used in the codebase:
- File splitting via extensions: `FeatureView+Section.swift`, `ViewModel+Tasks.swift`, etc. (example: `Shelf Notes/LibraryView/*`, `Shelf Notes/BookDetail/*`).
- CloudKit+SwiftData constraints are explicitly respected in models:
  - avoid `@Attribute(.unique)`
  - relationships often optional; inverse relationship required for CloudKit (see `Book.readingSessions`).
- Expensive aggregations are increasingly moved out of render paths into caches/models (examples: `TagsIndexModel`, `ProgressHubMetricsModel`, Stats caches).

Do:
- Keep SwiftUI `body` cheap; push O(n) aggregation into `.task(id:)` + cached state models when it’s not inherently interactive.
- Keep CloudKit-facing model changes migration-safe (defaults for non-optional properties, optional relationships where needed).
- Use small, value-only snapshots for off-main compute when derived data gets heavy (pattern used in challenges).

Don’t:
- Don’t compute multi-pass stats / heavy sorts directly inside `body` or frequently-evaluated computed properties.
- Don’t silently switch users to local-only store without making the “separate dataset” behavior explicit (the app already avoids this).

---

## How to work on this project (Setup + Where to start)
### Setup checklist
1) Open `Shelf Notes.xcodeproj`.
2) Ensure `Shelf Notes/config/secrets.xcconfig` exists and contains a valid `GOOGLE_BOOKS_API_KEY`.  
   - If you don’t want secrets in git: create a `secrets.sample.xcconfig` and gitignore the real one (see Quick Wins).
3) Confirm iCloud entitlements + capabilities:
   - `Shelf Notes/Shelf_Notes.entitlements` contains the correct CloudKit container id.
4) Run once on a real device if you need barcode scanning (`BarcodeScannerSheet.swift` uses VisionKit DataScanner; simulator is typically unsupported).
5) For CloudKit debugging, use the in-app diagnostics screen:
   - `Shelf Notes/SyncDiagnosticsView.swift`

### “Start here” entry points when changing behavior
- App bootstrap / storage: `Shelf Notes/AppContainerHostView.swift`
- Tabs & global appearance: `Shelf Notes/RootView.swift`
- Primary list UX: `Shelf Notes/LibraryView/LibraryView.swift`
- Book detail UX: `Shelf Notes/BookDetailView.swift` and `Shelf Notes/BookDetail/*`
- Import pipeline: `Shelf Notes/BookImport/*` + `Shelf Notes/GoogleBooksClient.swift`
- Stats pipeline: `Shelf Notes/StatisticsView.swift` + `Shelf Notes/Stats/*`
- Challenges pipeline: `Shelf Notes/Challenges/*`

---

## Quick Wins (max 10, concrete)
1) **Secrets hygiene**: remove real API keys from the repo; keep `secrets.sample.xcconfig` committed + gitignore `secrets.xcconfig`.  
   Files: `Shelf Notes/config/secrets.xcconfig`, `Shelf Notes/config/base.xcconfig`, `.gitignore` (**UNKNOWN**: current gitignore state).
2) **Verify deployment target**: `IPHONEOS_DEPLOYMENT_TARGET = 26.0` looks suspicious; set the intended minimum iOS version and ensure it matches SwiftData (≥ iOS 17).  
   File: `Shelf Notes.xcodeproj/project.pbxproj`
3) **Rename/move** `Shelf Notes/BookDetailComponents1.swift`: filename does not match its content (“BookDetailComponents”). This makes navigation/search harder and is a merge-conflict trap.  
4) **Stats compute off-main**: `computeStatsCache(...)` and `computeHeatmapCache(...)` are currently synchronous and run inside `.task` closures that likely execute on the MainActor. Move crunching to a value snapshot + background task (see `ARCHITECTURE_NOTES.md`).  
   Files: `Shelf Notes/StatisticsView.swift`, `Shelf Notes/Stats/StatisticsView+Caching.swift`
5) **Unify signature/token helpers**: there are multiple “signature” concepts (Tags, Stats, ProgressHub). Consolidate into a small shared helper for deterministic invalidation tokens.  
6) **Add a lightweight “storage mode” indicator to diagnostics**: surface whether the current store is CloudKit vs local-only vs in-memory.  
   Files: `Shelf Notes/AppContainerHostView.swift`, `Shelf Notes/SyncDiagnosticsView.swift`
7) **Centralize user-visible error reporting for network/import**: Book import has multiple async paths; unify “debug payload” and error UI into one component.  
   Files: `Shelf Notes/BookImport/*`, `Shelf Notes/GoogleBooksClient.swift`
8) **Add a simple performance toggle**: turn off heavy stats sections (heatmap/charts) behind a UI toggle for very large libraries (useful during profiling).  
   Files: `Shelf Notes/StatisticsView.swift`, `Shelf Notes/Stats/*`
9) **Add sanity tests for relationship repair** (even if only as unit tests around pure helpers).  
   File: `Shelf Notes/CollectionMembershipRepair.swift`
10) **Audit `.task` lifetimes** (ensure cancellation is respected and tasks don’t multiply on rapid navigation). Start with Stats/Tags/Timeline.  
   Files: `Shelf Notes/StatisticsView.swift`, `Shelf Notes/TagsView/TagsView.swift`, `Shelf Notes/Timeline/ReadingTimelineView.swift`
