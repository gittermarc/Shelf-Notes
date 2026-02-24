# PROJECT_CONTEXT.md — Shelf Notes

## TL;DR
Shelf Notes ist eine iOS/iPadOS-App zum Verwalten einer persönlichen Bibliothek (Bücher + Status), mit Google-Books-Import (inkl. Barcode-Scan), Lesesessions/Timer, Jahreszielen, Challenges, Statistiken (Charts/Heatmap) und Zeitleiste. Persistenz + Sync laufen über **SwiftData + CloudKit (iCloud)**, mit expliziten Fallback-Modi (local-only / in-memory). Mindest-iOS: **26.0** (Xcode-Projekt: `Shelf Notes.xcodeproj/project.pbxproj`).

## Key Concepts / Domänenbegriffe
- **Book**: Zentrales Modellobjekt (Titel/Autor/Status, Metadaten, Tags, Notizen, Cover, Ratings).
- **ReadingStatus**: `toRead` / `reading` / `finished` (persistierte stabile Codes, UI-Labels separat).
- **ReadingSession**: Eine geloggte Lesesession (Start/Ende, Dauer, optional Seiten, Notiz) — gehört zu genau einem Book.
- **ReadingGoal**: Jahresziel (z.B. 25 Bücher in 2026).
- **BookCollection**: Benutzerdefinierte Listen/Collections (many-to-many mit Book).
- **ChallengeRecord**: Persistierte Wochen-/Monats-Challenge (Ziel + Zeitraum + Fortschritt via Engine).
- **Cover (Thumbnail vs Full-Res)**
  - **`Book.userCoverData`**: synchronisiertes Thumbnail (extern gespeichert in SwiftData).
  - Full-Res User-Cover liegt **lokal auf Disk** (File-Store), nicht in CloudKit.
- **Storage Modes**
  - `cloudKit`: Standard (SwiftData + CloudKit `.automatic`)
  - `localOnly`: eigener lokaler Datensatz (kein Sync)
  - `inMemory`: Notfall (nicht persistent)

## Architecture Map (Layer/Module + Verantwortlichkeiten + Abhängigkeiten)

### 1) App Bootstrap / Storage
- `Shelf Notes/Shelf_NotesApp.swift`
  - `@main` Entry-Point; startet `AppContainerHostView()`.
- `Shelf Notes/AppContainerHostView.swift`
  - `AppBootstrapper`: Build/Retry State Machine (`loading/ready/failed`)
  - `ModelContainerFactory`: `Schema([...])`, Store URLs, CloudKit vs Local-only vs In-memory
  - Failure UI: `ModelContainerFailureView` (Retry, Local-only, In-memory)
  - On-ready tasks:
    - `CollectionMembershipRepair.repairIfNeeded(...)`
    - `ChallengeEngine.ensureCurrentChallenges(...)`
    - `ChallengeEngine.refreshCompletionForActiveChallenges(...)`

### 2) Persistence & Sync (SwiftData + CloudKit) + Diagnostics
- SwiftData Container:
  - Erzeugung: `ModelContainerFactory.makeContainer(mode:)` in `Shelf Notes/AppContainerHostView.swift`
  - CloudKit: `ModelConfiguration(... cloudKitDatabase: .automatic)`
  - Local-only: `cloudKitDatabase: .none` + **separater** Store-Name/URL
- Save-Diagnostics:
  - `Shelf Notes/ModelContext+Diagnostics.swift`: `saveWithDiagnostics(file:line:)`
  - `Shelf Notes/SyncDiagnostics.swift`: iCloud Account Status, Network Monitor, last local save, offline counters
  - `Shelf Notes/SyncDiagnosticsView.swift`: UI zum Debuggen (Settings → Sync)
- Repairs/Migrations (one-off / best-effort):
  - `Shelf Notes/Book.swift` → `ReadingStatusMigrator`
  - `Shelf Notes/CollectionMembershipRepair.swift` (Collections <-> Books Many-to-Many konsistent halten)
  - `Shelf Notes/RootView.swift` + `Shelf Notes/CoverThumbnailer.swift` (deferred Backfill thumbnails)

### 3) Domain Model (SwiftData @Model)
- `Shelf Notes/Book.swift`
- `Shelf Notes/ReadingSession.swift`
- `Shelf Notes/ReadingGoal.swift`
- `Shelf Notes/BookCollection.swift`
- `Shelf Notes/Challenges/ChallengeModels.swift` (`ChallengeRecord`)
- CloudKit/SwiftData-Konventionen:
  - **keine** `@Attribute(.unique)` auf gesyncten Models (mehrfach im Code kommentiert).
  - Relationships teils optional (CloudKit-Constraint).

### 4) UI (SwiftUI) — Root → Tabs → Feature-Flows
- Root:
  - `Shelf Notes/RootView.swift`: `TabView` + globale Appearance + EnvironmentObjects (`ProManager`, `ReadingTimerManager`)
- Tabs (RootView):
  1. **Library** (`LibraryView`)
  2. **Fortschritt** (`ProgressHubView`)
  3. **Listen** (`CollectionsView`)
  4. **Tags** (`TagsView`)
  5. **Settings** (`SettingsView`)
- Feature-Submodule:
  - Book Import: `Shelf Notes/BookImport/*`
  - Book Detail: `Shelf Notes/BookDetail/*` + `Shelf Notes/BookDetailView.swift`
  - Stats: `Shelf Notes/Stats/*`
  - Timeline: `Shelf Notes/Timeline/*`
  - Challenges: `Shelf Notes/Challenges/*`

### 5) Services / Helpers (non-UI)
- Google Books
  - `Shelf Notes/GoogleBooksClient.swift`
  - `Shelf Notes/BookImport/BookImportViewModel.swift` (Orchestrierung, Cancellation, Pagination)
- Cover
  - `Shelf Notes/CoverThumbnailer.swift` (ImageIO pipeline + backfill)
  - `Shelf Notes/CoverImageLoader.swift`, `Shelf Notes/UserCoverStore.swift`, `Shelf Notes/LibraryRowCoverView.swift`
- Timer / Sessions
  - `Shelf Notes/ReadingTimerManager.swift`
  - `Shelf Notes/TimerSessionCompletionSheet.swift`

## Folder Map (Ordner → Zweck)
- `Shelf Notes/` — Haupttarget (UI + Modelle + Services).
- `Shelf Notes/BookImport/` — Google-Books-Import Flow (VM, Query Builder, Filter Engine, UI Components).
- `Shelf Notes/BookDetail/` — Book-Detail Subviews + Logic Extensions.
- `Shelf Notes/BookDetail/Sessions/` — Session-UI (Karten, Listen, Quick-Log Sheet).
- `Shelf Notes/Stats/` — Statistik UI + Aggregationen + Caches (Charts/Heatmap).
- `Shelf Notes/Timeline/` — Zeitleisten-UI.
- `Shelf Notes/Challenges/` — Challenges UI + Engine + Modelle.
- `Shelf Notes/config/` — Build-Konfiguration (`base.xcconfig`, **`secrets.xcconfig`**).
- `Shelf Notes/Assets.xcassets` — Assets.

## Data Model Map (Entities, Relationships, wichtige Felder)

### Book (`Shelf Notes/Book.swift`)
- **Identity**: `id: UUID` (bewusst **nicht** `@Attribute(.unique)` wegen CloudKit/SwiftData).
- **Core**:
  - `title: String`, `author: String`, `createdAt: Date`
  - `statusRawValue: String` (stable codes) + computed `status: ReadingStatus`
  - `tags: [String]`, `notes: String`
- **Read range**: `readFrom: Date?`, `readTo: Date?` (Timeline/Goals/Stats)
- **Relationships**
  - **Many-to-many**: `collections: [BookCollection]?`
  - **One-to-many**: `readingSessions: [ReadingSession]?` mit inverse `ReadingSession.book`, deleteRule `.cascade`
- **Import/Metadata (Auszug, gruppiert)**
  - IDs/Links: `googleVolumeID`, `isbn13`, `previewLink`, `infoLink`, `canonicalVolumeLink`
  - Publishing: `publisher`, `publishedDate`, `pageCount`, `language`
  - Categories: `mainCategory`, `categories: [String]`
  - Description: `bookDescription`
  - Cover URLs: `thumbnailURL`, `coverURLCandidates: [String]` (+ Helpers zum “best-first” Persistieren)
  - Availability/Sale: `viewability`, `isPublicDomain`, `isEmbeddable`, `isEpubAvailable`, `isPdfAvailable`, `saleability`, `isEbook`, Tokens
  - Google Ratings: `averageRating`, `ratingsCount`
- **Cover**
  - `userCoverData: Data?` (`@Attribute(.externalStorage)`) → synced Thumbnail
  - `userCoverFileName: String?` → lokales Full-Res File
- **User Ratings**
  - 6 Kriterien ints (0..5), Derived `userRatingAverage`, `userRatingAverage1`
  - Rule: Ratings nur wenn `status == .finished` (setzt sonst zurück)

### ReadingSession (`Shelf Notes/ReadingSession.swift`)
- `id: UUID`
- Relationship: `book: Book?`
- `startedAt`, `endedAt`, `durationSeconds` (cached), `pagesRead?`, `note?`, `createdAt`

### ReadingGoal (`Shelf Notes/ReadingGoal.swift`)
- `year`, `targetCount`, `updatedAt`

### BookCollection (`Shelf Notes/BookCollection.swift`)
- `id`, `name`, `createdAt`, `updatedAt`
- Relationship: `books: [Book]?` (+ `booksSafe`)
- Helpers: `addBook/removeBook/contains`

### ChallengeRecord (`Shelf Notes/Challenges/ChallengeModels.swift`)
- `id`, `periodStart/periodEnd`, `kindRawValue`, `metricRawValue`
- `title`, `detail`, `targetValue`
- `completedAt?`, `acknowledgedAt?`, `rerollsUsed`, `rerolledAt?`

## Sync/Storage (SwiftData / CloudKit)
- **Container & Schema**
  - `Schema([Book, ReadingSession, ReadingGoal, BookCollection, ChallengeRecord])` in `Shelf Notes/AppContainerHostView.swift`.
- **CloudKit**
  - `cloudKitDatabase: .automatic` (SwiftData steuert CloudKit intern).
  - iCloud Container: `Shelf Notes/Shelf_Notes.entitlements` → `iCloud.de.marcfechner.Shelf-Notes`
- **Store Separation**
  - CloudKit Store: `ShelfNotesCloud.store`
  - Local-only Store: `ShelfNotesLocal.store`
  - Pfade: `Application Support/ShelfNotes/SwiftData/…` (siehe `storeURL(for:)`)
- **Fallback**
  - Bei Container-Failure: keine Crash → Failure Screen + Optionen (Retry, Local-only, In-memory).
  - Local-only ist explizit, inkl. Banner + Alert (Root overlay in `AppContainerHostView`).
- **Offline-Verhalten**
  - Sync passiert “best-effort” im Hintergrund (SwiftData).
  - `SyncDiagnostics` trackt “offline saves” via NWPathMonitor.

## Entry Points + Navigation (Tabs/Stacks/Sheets)

### Entry Points
- `Shelf Notes/Shelf_NotesApp.swift` → `AppContainerHostView()`
- `Shelf Notes/RootView.swift` → `TabView` (Hauptnavigation)

### Tab 1 — Library
- Host: `Shelf Notes/LibraryView.swift`
- Splits: `Shelf Notes/LibraryView+Header.swift`, `+FilteringSorting.swift`, `+Lists.swift`, `+Grid.swift`, `+AlphaIndex.swift`, `+Toolbar.swift`, `+Actions.swift`, `+BulkActions.swift`
- Patterns:
  - Derived Cache (filter/sort/alpha sections) + debounce Typing (Search) → `pendingRecomputeTask`
- Sheets/Alerts:
  - Add: `AddBookView` (Sheet)
  - Bulk add to collection: `BulkAddToCollectionSheet`
  - Delete confirms

### Tab 2 — Fortschritt
- Host: `Shelf Notes/ProgressHubView.swift`
- NavigationLinks:
  - `StatisticsView` (`Shelf Notes/Stats/*`)
  - `GoalsView` (`Shelf Notes/GoalsView.swift`)
  - `ReadingTimelineView` (`Shelf Notes/Timeline/*`)
  - `ChallengesView` (`Shelf Notes/Challenges/*`)

### Tab 3 — Listen (Collections)
- Host: `Shelf Notes/CollectionsView.swift`
- Detail: `Shelf Notes/CollectionDetailView.swift`
- Pro gating: `Shelf Notes/ProManager.swift` + `ProPaywallView` (maxFreeCollections)

### Tab 4 — Tags
- Host: `Shelf Notes/TagsView.swift`
- Tap Tag → `LibraryView(initialTag:)`

### Tab 5 — Settings
- Host: `Shelf Notes/SettingsView.swift` (NavigationStack mit `NavigationPath` + `SceneStorage`)
- Ziele:
  - `AppearanceSettingsView`
  - `CSVImportExportView`
  - `SyncDiagnosticsView`
  - Pro purchase/restore, cover cache management, session auto-stop

### Zentrale Sheets/Flows
- Add Book Flow: `Shelf Notes/AddBookView.swift`
  - `BookImportView` (Google Books) — `Shelf Notes/BookImport/BookImportView.swift`
  - `BarcodeScannerSheet` — `Shelf Notes/BarcodeScannerSheet.swift`
  - `InspirationSeedPickerView` + `ForYouSeedBuilder` — `Shelf Notes/ForYouSeedBuilder.swift`
  - `ManualBookAddSheet` — `Shelf Notes/ManualBookAddSheet.swift`
- Reading Timer:
  - Manager: `Shelf Notes/ReadingTimerManager.swift` (als EnvironmentObject)
  - Completion: `Shelf Notes/TimerSessionCompletionSheet.swift` (sheet)

## Build & Configuration (Targets, Info.plist, Entitlements, Secrets)
- Targets: `Shelf Notes`, `Shelf NotesTests`, `Shelf NotesUITests` (`Shelf Notes.xcodeproj/project.pbxproj`)
- Bundle IDs:
  - App: `de.marcfechner.Shelf-Notes`
  - Tests: `de.marcfechner.Shelf-NotesTests`
  - UI Tests: `de.marcfechner.Shelf-NotesUITests`
- Deployment Target: `IPHONEOS_DEPLOYMENT_TARGET = 26.0`
- Versions (pbxproj):
  - Marketing: `1.07` (App Release), Build: `1`
- Base Config:
  - `Shelf Notes/config/base.xcconfig` includes `secrets.xcconfig`
  - **Security Note**: `Shelf Notes/config/secrets.xcconfig` enthält aktuell einen Google API Key im Klartext.
- Info.plist: `Shelf Notes/Info.plist`
  - `GOOGLE_BOOKS_API_KEY` via `$(GOOGLE_BOOKS_API_KEY)`
  - `UIBackgroundModes = remote-notification`
  - Camera/Photos permission strings
- Entitlements: `Shelf Notes/Shelf_Notes.entitlements`
  - CloudKit enabled, iCloud container id, `aps-environment = development` (Release/Prod Setup: **UNKNOWN**, siehe Open Questions).
- StoreKit:
  - `Shelf Notes/unlimited_collections.storekit` (lokales IAP Testing)
  - `Shelf Notes/ProManager.swift` hat placeholder `productID = "001"` (App Store Connect: **UNKNOWN**).

## Conventions (Naming, Patterns, Do/Don’t)
- **Split-by-extension**:
  - Pattern: Host bleibt in `X.swift`, Sub-Responsibilites in `X+Y.swift`.
  - Achtung: `private` ist nicht sichtbar über Files → State/Helpers, die Splits nutzen, sind absichtlich nicht-private.
- **SwiftData + CloudKit**
  - No `@Attribute(.unique)`.
  - Relationships optional (CloudKit) + Inverse definieren (siehe `ReadingSession` Kommentar).
- **Saves**
  - Mutation → `saveWithDiagnostics()` (statt “blindem” save).
- **Performance**
  - Debounce bei Typing/Filter.
  - Derived “signature” für Cache Invalidations (siehe `Stats/StatisticsView+Caching.swift`).

## Typical Workflows (How-to)

### Feature: Neuer Screen
- Tab hinzufügen:
  - `Shelf Notes/RootView.swift` → neuer `TabView` Eintrag + `.tag(...)`
- Innerhalb eines Tabs:
  - `NavigationLink` (Push) oder `.sheet` (Modal) in der jeweiligen Host-View
- Navigation-State stabil halten:
  - `@SceneStorage` / `NavigationPath` nutzen, wenn globale Appearance Settings die Hierarchie rebuilden (Pattern in `RootView`/`SettingsView`).

### Feature: Neue SwiftData Entity
1. Neue `@Model`-Klasse (z.B. `Shelf Notes/MyNewModel.swift`)
   - Defaults für non-optional properties setzen (CloudKit/SwiftData)
   - Keine `@Attribute(.unique)`
2. Schema erweitern:
   - `Shelf Notes/AppContainerHostView.swift` → `ModelContainerFactory.schema`
3. Relationship-Design:
   - CloudKit: optional relationships + inverse sauber definieren.
4. Migration:
   - Kleine “one-off” Migrator (Pattern: `ReadingStatusMigrator`) bei Bedarf.

### Feature: Neue Einstellung (AppStorage)
- Storage Keys zentral:
  - `Shelf Notes/AppearancePreferences.swift` / `AppearanceStorageKey` (für Appearance)
  - sonst: explizite string keys (z.B. `session_autostop_enabled_v1` in `SettingsView`)
- UI:
  - `SettingsView` Section + `@AppStorage`
  - Bei globaler Wirkung: in `RootView` apply (tint, fonts, density).

### Feature: Google Books Import erweitern (Filter/Query)
- UI/State:
  - `Shelf Notes/BookImport/BookImportViewModel.swift` (Published filter state)
  - Query building: `Shelf Notes/BookImport/BookImportQueryBuilder.swift`
  - Local filter engine: `Shelf Notes/BookImport/BookImportFilterEngine.swift`
- Debug:
  - `GoogleBooksDebugInfo` wird in UI angezeigt (request URL, status, bytes).

## How to work on this project (Setup Steps)
1. Öffnen: `Shelf Notes.xcodeproj`
2. Signing & Capabilities:
   - iCloud/CloudKit aktiv (Entitlements)
   - Testgeräte: in iCloud eingeloggt für Sync-Tests
3. Secrets:
   - Empfohlen: `secrets.local.xcconfig` (untracked) statt Key im Repo (siehe Quick Wins)
4. Debugging:
   - Settings → Sync-Diagnose (`SyncDiagnosticsView`)
   - `SyncDiagnostics.diagnosticsReport()` für Copy/Paste in Bug Reports

## Quick Wins (max. 10, konkret, umsetzbar)
1. **API-Key aus Repo entfernen**: `Shelf Notes/config/secrets.xcconfig` → untracked `secrets.local.xcconfig` + `.gitignore`.
2. **TagsView cachen**: `Shelf Notes/TagsView.swift` (tagCounts O(n) pro Render) → Snapshot/Cache.
3. **ProgressHub Snapshot**: `Shelf Notes/ProgressHubView.swift` KPIs off-main + cached.
4. **Stats Compute off-main**: vorhandenes Caching behalten, aber compute in `Task.detached` (UI smooth).
5. **Cover Backfill batching**: `CoverThumbnailer` Saves bündeln.
6. **Naming cleanup**: `Shelf Notes/BookDetailComponents1.swift` umbenennen/verschieben (semantisch irreführend).
7. **ContentView klären**: `Shelf Notes/ContentView.swift` (Wrapper) vs tatsächlicher Entry (`AppContainerHostView`).
8. **Pro productID**: `Shelf Notes/ProManager.swift` Product ID aus App Store Connect eintragen.
9. **Release Entitlements check**: `aps-environment`/CloudKit/Push Setup für Distribution.
10. **Shared DateFormatters**: Stats/Timeline/Challenges konsolidieren (klein, aber sauber).

## Open Questions (UNKNOWN)
- Release Entitlements: Wird `aps-environment` für Release/Distribution auf `production` gesetzt?
- CloudKit Conflict UX: Gibt es definierte Regeln/UX bei Merge-Konflikten (z.B. simultanes Edit desselben Books)?
- Schema Evolution: Strategie für größere Model-Änderungen beyond one-off migrators?
- Pro Purchase: echte Product ID(s) + Pricing/Entitlements in App Store Connect?
