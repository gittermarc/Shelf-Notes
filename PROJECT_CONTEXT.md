# PROJECT_CONTEXT.md

## TL;DR
Shelf Notes is an iPhone/iPad SwiftUI app for managing a personal book library, tracking reading progress/sessions, organizing books into collections, importing metadata from Google Books, and surfacing reading analytics, goals, challenges, and a timeline. The main app uses **SwiftData + CloudKit** via `Shelf Notes/AppContainerHostView.swift` and boots through `Shelf Notes/Shelf_NotesApp.swift`. The main app target appears to require **iOS 26.0** while the Live Activity extension target appears to require **iOS 26.2** (`Shelf Notes.xcodeproj/project.pbxproj`).

## Key Concepts / Domänenbegriffe
- **Book**: Zentrales Modell in `Shelf Notes/BookModel/Book.swift`; enthält Kernmetadaten, Importdaten, Coverdaten, Status, Tags, Sessions und Ratings.
- **ReadingStatus**: Persistierter Lesestatus (`toRead`, `reading`, `finished`) in `Shelf Notes/BookModel/Book+Status.swift`.
- **ReadingSession**: Einzelne Lese-Session mit Dauer, Seiten und Notiz in `Shelf Notes/ReadingSession.swift`.
- **ReadingGoal**: Jahresziel pro Kalenderjahr in `Shelf Notes/ReadingGoal.swift`.
- **BookCollection**: Benutzerdefinierte Listen/Sammlungen in `Shelf Notes/BookCollection.swift`.
- **ChallengeRecord**: Persistierte Weekly/Monthly-Challenges in `Shelf Notes/Challenges/ChallengeModels.swift`.
- **Derived State**: Vorberechnete, nicht-persistierte Sichten auf SwiftData-Daten, z. B. `Shelf Notes/LibraryView/LibraryDerivedStateBuilder.swift`, `Shelf Notes/TagsView/TagsIndexStore.swift`, `Shelf Notes/ProgressHub/ProgressHubMetricsModel.swift`.
- **Source Snapshot**: Value-only Kopie von SwiftData-Daten für Off-Main-Compute, z. B. `Shelf Notes/Stats/StatisticsSnapshotBuilder.swift`, `Shelf Notes/Challenges/ChallengeEngine+Snapshot.swift`, `Shelf Notes/Analytics/ReadingAnalyticsInputMapper.swift`.
- **Local-only fallback**: Separater lokaler SwiftData-Store ohne CloudKit in `Shelf Notes/AppContainerHostView.swift`.
- **Live Activity shared store**: App-Group-basierte Übergabe für Reading Timer + Cover zwischen App und Extension in `Shelf Notes/Shared/LiveActivity/LiveActivitySharedStore.swift`.

## Architecture Map

### Entry / Bootstrap
- `Shelf Notes/Shelf_NotesApp.swift`
  - `@main` entry point.
  - Rendert nur `AppContainerHostView()`.
- `Shelf Notes/AppContainerHostView.swift`
  - Verantwortlich für ModelContainer-Bootstrap.
  - Schaltet zwischen `cloudKit`, `localOnly`, `inMemory`.
  - Baut SwiftData-Schema für `Book`, `ReadingSession`, `ReadingGoal`, `BookCollection`, `ChallengeRecord`.
  - Startet One-time repair / bootstrap work:
    - `CollectionMembershipRepair.repairIfNeeded(...)`
    - `ChallengeEngine.ensureCurrentChallengesAndRefreshCompletion(...)`

### App Shell / Global State
- `Shelf Notes/RootView.swift`
  - Zentrale Tab-Shell.
  - Hält globale EnvironmentObjects:
    - `ProManager`
    - `ReadingTimerManager`
    - `TagsIndexStore`
  - Triggert App-weite Tasks:
    - `ReadingStatusMigrator.migrateIfNeeded(...)`
    - Cover thumbnail backfill via `CoverThumbnailer.backfillAllBooksIfNeeded(...)`
    - Tags index update aus gesamtem `@Query private var books`.

### UI Layer
- Tab-Screens:
  - `Shelf Notes/LibraryView/LibraryView.swift`
  - `Shelf Notes/ProgressHub/ProgressHubView.swift`
  - `Shelf Notes/CollectionsView.swift`
  - `Shelf Notes/TagsView/TagsView.swift`
  - `Shelf Notes/Settings/SettingsView.swift`
- Feature-Screens und Sheets sind stark dateiweise gesplittet, meist über `View`-Extensions.

### Domain / Compute Layer
- Analytics / derived metrics:
  - `Shelf Notes/Analytics/ReadingAnalyticsIndexBuilder.swift`
  - `Shelf Notes/Goals/GoalsYearMetricsBuilder.swift`
  - `Shelf Notes/Stats/StatisticsSnapshotBuilder.swift`
  - `Shelf Notes/Stats/StatisticsHeatmapBuilder.swift`
  - `Shelf Notes/Challenges/ChallengeEngine+Compute.swift`
- Diese Komponenten arbeiten überwiegend value-only und sind gute Kandidaten für Tests.

### Persistence / Sync / Repair Layer
- SwiftData model types:
  - `Shelf Notes/BookModel/Book.swift`
  - `Shelf Notes/ReadingSession.swift`
  - `Shelf Notes/ReadingGoal.swift`
  - `Shelf Notes/BookCollection.swift`
  - `Shelf Notes/Challenges/ChallengeModels.swift`
- Repairs / migrations:
  - `Shelf Notes/CollectionMembershipRepair.swift`
  - `Shelf Notes/ReadingStatusMigrator.swift`
- Save diagnostics:
  - `Shelf Notes/ModelContext+Diagnostics.swift`
  - `Shelf Notes/SyncDiagnostics.swift`

### Integrations
- Google Books API:
  - `Shelf Notes/GoogleBooksClient.swift`
  - `Shelf Notes/GoogleBooksDTO.swift`
  - `Shelf Notes/GoogleVolumeBookMapper.swift`
- StoreKit:
  - `Shelf Notes/ProManager.swift`
  - `Shelf Notes/ProPaywallView.swift`
  - `Shelf Notes/unlimited_collections.storekit`
- Live Activities / WidgetKit / AppIntents:
  - `Shelf Notes/BookDetail/Sessions/LiveActivity/*`
  - `Shelf Notes/Shared/LiveActivity/*`
  - `ShelfNotesLiveActivity/*`
- Camera / barcode scan:
  - `Shelf Notes/BarcodeScannerSheet.swift`

### Dependency Pattern
- Kein zentraler DI-Container gefunden.
- Häufige Muster:
  - `@Environment(\.modelContext)` für writes/fetches
  - `@Query` direkt in Views
  - `@StateObject` / `@EnvironmentObject` für app-lokalen State
  - Singletons für globales Verhalten (`GoogleBooksClient.shared`, `SyncDiagnostics.shared`, Cache-Singletons)

## Folder Map
- `Shelf Notes/`
  - Root des App-Targets; enthält auch ältere Root-Level Dateien und kleinere Helper.
- `Shelf Notes/BookModel/`
  - Book-Modell und fachliche Extensions (`status`, `ratings`, `progress`, `collections`, `cover URLs`).
- `Shelf Notes/LibraryView/`
  - Bibliotheks-Tab, Layouts, Toolbar, Filter-UI, Derived-State-Pipeline.
- `Shelf Notes/BookDetail/`
  - Detailscreen, Subcomponents, Bindings, Sessions, Actions, Toolbar.
- `Shelf Notes/AddBook/`
  - Add-Book-Orchestrierung und sheet routing.
- `Shelf Notes/BookImport/`
  - Google-Books-Import, Query Builder, Filterung, ViewModel-Splits.
- `Shelf Notes/CSVImportExport/`
  - CSV Import/Export, Parsing, Duplicate-Index, Executor.
- `Shelf Notes/Stats/`
  - Statistik-UI, Snapshot-Builder, Compute-Pipeline, Heatmap-Builder.
- `Shelf Notes/Goals/`
  - Jahresziel-UI und Ziel-Metriken.
- `Shelf Notes/ProgressHub/`
  - Fortschritts-Startscreen mit Hero-Metriken und Deep Links zu Stats/Goals/Timeline/Challenges.
- `Shelf Notes/Timeline/`
  - Horizontale Reading Timeline plus ViewModel.
- `Shelf Notes/Challenges/`
  - Persistierte Challenges plus Snapshot/Compute/Refresh-Engine.
- `Shelf Notes/Analytics/`
  - Wiederverwendbarer Reading-Analytics-Index für Goals und ProgressHub.
- `Shelf Notes/Settings/`
  - Settings root + Appearance / LibraryAppearance modules.
- `Shelf Notes/CoverThumbnailer/`
  - Thumbnail-Erzeugung, Backfill, Remote fetch, ImageIO helpers.
- `Shelf Notes/Shared/LiveActivity/`
  - App/Extension-shared models and storage.
- `Shelf Notes/config/`
  - `.xcconfig`-Dateien.
- `Shelf NotesTests/`
  - Unit tests, vor allem für Builder/derived state / import / tag index.
- `Shelf NotesUITests/`
  - UI test target.
- `ShelfNotesLiveActivity/`
  - Live Activity / widget extension target.

## Data Model Map

### `Shelf Notes/BookModel/Book.swift`
- Type: `@Model final class Book`
- Relationships:
  - `collections: [BookCollection]?` (many-to-many, optional)
  - `readingSessions: [ReadingSession]?` with inverse on `Book.readingSessions`
- Wichtige Felder:
  - Identity: `id`
  - Core: `title`, `author`, `createdAt`, `statusRawValue`, `tags`, `notes`
  - Reading period: `readFrom`, `readTo`
  - Import metadata: `googleVolumeID`, `isbn13`, `thumbnailURL`, `publisher`, `publishedDate`, `pageCount`, `language`, `categories`, `bookDescription`
  - Rich metadata: `subtitle`, `previewLink`, `infoLink`, `canonicalVolumeLink`, `averageRating`, `ratingsCount`, `mainCategory`, `coverURLCandidates`
  - Cover pipeline: `userCoverData` (`@Attribute(.externalStorage)`), `userCoverFileName`
  - User ratings: 6 einzelne `userRating*` Felder
- Wichtige Extensions:
  - `Shelf Notes/BookModel/Book+Status.swift`
  - `Shelf Notes/BookModel/Book+Collections.swift`
  - `Shelf Notes/BookModel/Book+Ratings.swift`
  - `Shelf Notes/BookModel/Book+ReadingProgress.swift`
  - `Shelf Notes/BookModel/Book+CoverURLs.swift`

### `Shelf Notes/BookCollection.swift`
- Type: `@Model final class BookCollection`
- Wichtige Felder: `id`, `name`, `createdAt`, `updatedAt`, `books`
- Relationship helpers: `booksSafe`, `contains`, `addBook`, `removeBook`

### `Shelf Notes/ReadingSession.swift`
- Type: `@Model final class ReadingSession`
- Wichtige Felder: `id`, `book`, `startedAt`, `endedAt`, `durationSeconds`, `pagesRead`, `note`, `createdAt`
- Besonderheit: `durationSeconds` wird gecacht, um Aggregationen zu vereinfachen.

### `Shelf Notes/ReadingGoal.swift`
- Type: `@Model final class ReadingGoal`
- Wichtige Felder: `year`, `targetCount`, `updatedAt`
- Keine eigene ID; `year` wirkt fachlich wie natürlicher Schlüssel, ist aber **nicht** technisch abgesichert.

### `Shelf Notes/Challenges/ChallengeModels.swift`
- Type: `@Model final class ChallengeRecord`
- Wichtige Felder:
  - Period: `periodStart`, `periodEnd`
  - Type: `kindRawValue`, `metricRawValue`
  - Content: `title`, `detail`
  - Progress target: `targetValue`
  - Meta: `createdAt`, `completedAt`, `acknowledgedAt`, `rerollsUsed`, `rerolledAt`
- Value enums:
  - `ChallengeKind`
  - `ChallengeMetric`

## Sync / Storage

### Persistence API
- App code verwendet **SwiftData**, nicht direkte CoreData-APIs.
- Zentrale Container-Erstellung: `Shelf Notes/AppContainerHostView.swift`.
- Schema wird dort hart definiert; kein separater `VersionedSchema` / `MigrationPlan` gefunden.

### Store Modes
- `cloudKit`: `ModelConfiguration(... cloudKitDatabase: .automatic)` in `Shelf Notes/AppContainerHostView.swift`
- `localOnly`: separates lokales Persistent Store File ohne CloudKit
- `inMemory`: in-memory emergency fallback

### Store Separation
- CloudKit- und local-only Store sind explizit getrennt.
- Speicherort: `Application Support/ShelfNotes/SwiftData/*.store` in `Shelf Notes/AppContainerHostView.swift`.
- Folge: local-only ist **kein** transparenter Offline-Modus derselben Datenbasis, sondern ein separater Datenstand.

### CloudKit / iCloud
- Entitlements in `Shelf Notes/Shelf_Notes.entitlements`:
  - `com.apple.developer.icloud-container-identifiers = iCloud.de.marcfechner.Shelf-Notes`
  - `com.apple.developer.icloud-services = CloudKit`
  - `aps-environment = development`
- Sync diagnostics statt echter CloudKit op telemetry:
  - `Shelf Notes/SyncDiagnostics.swift`
  - `Shelf Notes/SyncDiagnosticsView.swift`

### Repairs / Migration
- `Shelf Notes/ReadingStatusMigrator.swift`
  - Migriert alte lokalisierte Statusstrings auf stabile Codes.
- `Shelf Notes/CollectionMembershipRepair.swift`
  - Re-synchronisiert many-to-many Beziehungen `Book <-> BookCollection`.
- Kein formaler Schema-Migrationsplan gefunden.

### Offline-Verhalten
- Bootstrap failure screen in `Shelf Notes/AppContainerHostView.swift` erlaubt:
  - Retry CloudKit
  - Start local-only
  - Start in-memory
- Lokale Saves werden über `ModelContext.saveWithDiagnostics()` gebreadcrumbed.
- `SyncDiagnostics` zählt Offline-Saves und zeigt Netzwerk-/iCloud-Status, aber keine echte Sync-Fortschrittsanzeige.

### Cache / Secondary Storage
- Cover memory cache: `Shelf Notes/CachedAsyncImage.swift`
- Cover disk cache: `Shelf Notes/CachedAsyncImage.swift`
- Full-res local user covers: `UserCoverStore` in `Shelf Notes/CachedAsyncImage.swift`
- Synced thumbnail cache for row rendering: `Shelf Notes/LibraryView/LibraryRowCoverView.swift`
- Tag index cache: `Shelf Notes/TagsView/TagsIndexStore.swift`
- Library derived-state cache: `Shelf Notes/LibraryView/LibraryDerivedStateCoordinator.swift`
- Statistics caches: `StatisticsView` state in `Shelf Notes/Stats/StatisticsView.swift`
- Shared App Group store for timer/live activity: `Shelf Notes/Shared/LiveActivity/LiveActivitySharedStore.swift`

## UI Map

### Root Navigation
- `Shelf Notes/RootView.swift`
- `TabView` tabs:
  1. `LibraryView`
  2. `ProgressHubView`
  3. `CollectionsView`
  4. `TagsView`
  5. `SettingsView`

### Main Flows
- **Library** (`Shelf Notes/LibraryView/LibraryView.swift`)
  - `NavigationStack`
  - Search, filters, list/grid, bulk actions
  - Sheets:
    - `AddBookView`
    - `BulkAddToCollectionSheet`
  - Navigation to `BookDetailView`
- **Add Book** (`Shelf Notes/AddBook/AddBookView.swift`)
  - Central sheet router via `AddBookSheet`
  - Subflows:
    - `BookImportView`
    - `BarcodeScannerSheet`
    - `InspirationSeedPickerView`
    - `ManualBookAddSheet`
- **Book Detail** (`Shelf Notes/BookDetail/BookDetailView.swift`)
  - Multiple sheets:
    - notes
    - collections picker
    - rating editor
    - all sessions
    - new collection
    - paywall
    - share sheet
    - online cover picker
- **ProgressHub** (`Shelf Notes/ProgressHub/ProgressHubView.swift`)
  - Links to:
    - `StatisticsView`
    - `GoalsView`
    - `ReadingTimelineView`
    - `ChallengesView`
- **Collections** (`Shelf Notes/CollectionsView.swift`)
  - `NavigationStack`
  - Sheet: `NewCollectionSheet`
  - Sheet: `ProPaywallView`
  - Navigation to `CollectionDetailView`
- **Tags** (`Shelf Notes/TagsView/TagsView.swift`)
  - Navigation to filtered `LibraryView(initialTag:)`
- **Settings** (`Shelf Notes/Settings/SettingsView.swift`)
  - `NavigationStack(path:)`
  - Destinations:
    - `AppearanceSettingsView`
    - `CSVImportExportView`
    - `SyncDiagnosticsView`

## Build & Configuration
- Targets found in `Shelf Notes.xcodeproj/project.pbxproj`:
  - `Shelf Notes`
  - `Shelf NotesTests`
  - `Shelf NotesUITests`
  - `ShelfNotesLiveActivityExtension`
- Bundle IDs:
  - App: `de.marcfechner.Shelf-Notes`
  - Tests: `de.marcfechner.Shelf-NotesTests`
  - UI Tests: `de.marcfechner.Shelf-NotesUITests`
  - Extension: `de.marcfechner.Shelf-Notes.ShelfNotesLiveActivity`
- Versioning in project file:
  - App `MARKETING_VERSION = 1.08`
  - App `CURRENT_PROJECT_VERSION = 2`
- Device families: `1,2` => iPhone + iPad
- App deployment target appears `26.0`; extension appears `26.2`
- `.xcconfig`:
  - `Shelf Notes/config/base.xcconfig`
  - `Shelf Notes/config/secrets.xcconfig`
- Secrets handling:
  - `GOOGLE_BOOKS_API_KEY` is injected through `Info.plist`
  - **Current repo state has the key checked into `Shelf Notes/config/secrets.xcconfig`**
- Info.plist features in `Shelf Notes/Info.plist`:
  - `GOOGLE_BOOKS_API_KEY`
  - `UIBackgroundModes = remote-notification`
  - camera usage description
  - photo library usage description
  - `NSSupportsLiveActivities = true`
- Entitlements:
  - iCloud / CloudKit / App Group in `Shelf Notes/Shelf_Notes.entitlements`
  - App Group also in `ShelfNotesLiveActivityExtension.entitlements`
- SPM:
  - No `XCRemoteSwiftPackageReference` found in `Shelf Notes.xcodeproj/project.pbxproj`
- StoreKit local config:
  - `Shelf Notes/unlimited_collections.storekit`

## Conventions
- Files are often split by responsibility using `+Suffix.swift` patterns:
  - Example: `BookDetailView+Bindings.swift`, `LibraryView+Grid.swift`, `BookImportViewModel+Tasks.swift`
- Derived state is increasingly extracted out of render code:
  - `LibraryDerivedState*`
  - `TagsIndexStore`
  - `ProgressHubMetricsModel`
  - `ReadingAnalyticsIndexBuilder`
- Many Views still use `@Query` directly.
- Saves should generally go through `modelContext.saveWithDiagnostics()`.
- CloudKit compatibility conventions are explicitly documented in model files:
  - avoid `@Attribute(.unique)`
  - keep relationships optional where needed
  - provide defaults for non-optional persisted properties
- UI state persistence uses `@AppStorage` and `@SceneStorage` heavily in `RootView.swift`, `SettingsView.swift`, and appearance-related files.

## Do / Don’t
- Do keep SwiftData access on the main actor unless a value snapshot already exists.
- Do prefer value-only builders for analytics and large aggregations.
- Do preserve CloudKit-safe model conventions.
- Do keep new feature code module-local first; the codebase already expects small split files.
- Don’t add a new direct mutation path for both sides of `Book <-> BookCollection` without rechecking `CollectionMembershipRepair.swift` and helper semantics.
- Don’t put heavy aggregation directly into `body` when an existing snapshot/index pattern already exists.
- Don’t treat `localOnly` as the same dataset as CloudKit-backed data.

## How to work on this project

### Setup Steps
1. Open `Shelf Notes.xcodeproj`.
2. Verify signing, iCloud/CloudKit, and App Group setup for:
   - `Shelf Notes`
   - `ShelfNotesLiveActivityExtension`
3. Check `Shelf Notes/config/secrets.xcconfig` and replace/remove the checked-in Google Books API key as needed.
4. Build the app target first, then the extension target.
5. Test container bootstrap paths in `Shelf Notes/AppContainerHostView.swift`.
6. Run `Shelf NotesTests` after any builder / derived-state / import change.

### Where new devs should start
- Read `Shelf Notes/Shelf_NotesApp.swift` -> `Shelf Notes/AppContainerHostView.swift` -> `Shelf Notes/RootView.swift`.
- Then read the relevant feature module entry file:
  - Library: `Shelf Notes/LibraryView/LibraryView.swift`
  - Progress: `Shelf Notes/ProgressHub/ProgressHubView.swift`
  - Collections: `Shelf Notes/CollectionsView.swift`
  - Tags: `Shelf Notes/TagsView/TagsView.swift`
  - Settings: `Shelf Notes/Settings/SettingsView.swift`
- For analytics-related work, also read:
  - `Shelf Notes/Analytics/ReadingAnalyticsIndexBuilder.swift`
  - `Shelf Notes/Stats/StatisticsComputePipeline.swift`
  - `Shelf Notes/Stats/StatisticsSnapshotBuilder.swift`
- For cover/image work, read:
  - `Shelf Notes/CachedAsyncImage.swift`
  - `Shelf Notes/CoverThumbnailer/CoverThumbnailer.swift`
  - `Shelf Notes/LibraryView/LibraryRowCoverView.swift`

### Fast path for common feature work
- **New library filter / sorting change**
  - Start in `Shelf Notes/LibraryView/LibraryDerivedStateBuilder.swift`
  - Check `Shelf Notes/LibraryView/LibraryView.swift` and `LibraryView+Header.swift`
- **New metrics / charts**
  - Start in `Shelf Notes/Analytics/ReadingAnalyticsIndexBuilder.swift` or `Shelf Notes/Stats/StatisticsSnapshotBuilder.swift`
- **New import behavior**
  - Start in `Shelf Notes/BookImport/BookImportView/BookImportViewModel.swift`
  - Then inspect `BookImportViewModel+Tasks.swift`, `BookImportQueryBuilder.swift`, `GoogleBooksClient.swift`
- **New persistence field**
  - Start at the `@Model` file and then search its usage paths
  - Re-check CloudKit safety rules
- **New Settings toggle**
  - Add storage key in `Shelf Notes/Settings/AppearanceSettings/AppearancePreferences.swift` or a feature-local storage helper
  - Wire through `RootView.swift` / target feature view if app-global

## Quick Wins
1. Move the Google Books API key out of `Shelf Notes/config/secrets.xcconfig` and into developer-local config / CI secret injection.
2. Introduce a formal SwiftData migration strategy; current repo has repairs/migrators but no `VersionedSchema` / `MigrationPlan`.
3. Convert `Shelf Notes/Goals/GoalsView.swift` to a cached/derived-state model like Library/ProgressHub/Stats.
4. Reduce duplicate whole-library scans across `RootView.swift`, `GoalsView.swift`, `ProgressHubView.swift`, `StatisticsView.swift`, and `ReadingTimelineView.swift` by sharing an analytics snapshot/index service.
5. Extract remaining heavy computed bindings from `Shelf Notes/BookDetail/BookDetailView+Bindings.swift` into smaller value builders.
6. Review `Shelf Notes/RootView.swift` because one view currently owns tab shell, appearance, migration trigger, tag indexing, CSV first-run prompt, timer completion sheet, and cover backfill scheduling.
7. Revisit `UIBackgroundModes = remote-notification` in `Shelf Notes/Info.plist`; explicit remote notification handling code was not found in the scanned repo.
8. Replace placeholder-ish monetization wiring in `Shelf Notes/ProManager.swift` (`productID = "001"`) with environment-specific config if this is still test-only.
9. Centralize app-wide caching policy for covers; current logic is spread across `CachedAsyncImage.swift`, `CoverThumbnailer/*`, `LibraryRowCoverView.swift`, and `Book+CoverURLs.swift`.
10. Add a small architecture note directly in repo for “how to add a new persisted field safely under CloudKit”; the knowledge is currently embedded in comments across model files.
