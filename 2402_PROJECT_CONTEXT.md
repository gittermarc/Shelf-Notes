# PROJECT_CONTEXT

_Generated from repository snapshot in `Shelf-Notes.zip` (analyzed on 2026-02-24)._

## TL;DR
Shelf Notes ist eine iOS/iPadOS-App zum Verwalten einer persönlichen Bibliothek (Bücher + Lesestatus), inkl. Import (Google Books / ISBN-Scan), Lese-Sessions, Zielen, Statistiken/Heatmap, Challenges sowie iCloud-Sync via SwiftData+CloudKit. Minimum Deployment Target laut Xcode-Projekt: **iOS 26.0** (`Shelf Notes.xcodeproj/project.pbxproj`: `IPHONEOS_DEPLOYMENT_TARGET = 26.0`).

## Key Concepts / Domänenbegriffe
- **Book**: Zentrale Entität (Titel/Autor/Status/Notizen/Tags/Metadaten + Cover-Thumbnail). (`Shelf Notes/Book.swift`)
- **ReadingStatus**: persisted als stabiler Code in `Book.statusRawValue` (`toRead`/`reading`/`finished`). (`Shelf Notes/Book.swift`)
- **ReadingSession**: Zeit-/Seiten-Log pro Buch (Timer-Workflow). (`Shelf Notes/ReadingSession.swift`, `Shelf Notes/ReadingTimerManager.swift`)
- **ReadingGoal**: Jahresziel (Anzahl gelesener Bücher). (`Shelf Notes/ReadingGoal.swift`, `Shelf Notes/GoalsView.swift`)
- **BookCollection**: Benutzerdefinierte Listen / Collections (many-to-many zu Book). (`Shelf Notes/BookCollection.swift`, `Shelf Notes/CollectionsView.swift`)
- **Challenges**: wöchentliche/monatliche Challenges als persistierte Records; Fortschritt wird aus Sessions/Books berechnet. (`Shelf Notes/Challenges/ChallengeModels.swift`, `Shelf Notes/Challenges/ChallengeEngine.swift`)
- **Cover Strategy**: Vollauflösende User-Cover lokal; **nur Thumbnail wird via SwiftData/CloudKit gesynct**. (`Shelf Notes/Book.swift`, `Shelf Notes/CoverThumbnailer.swift`, `Shelf Notes/CachedAsyncImage.swift`)
- **Pro**: Einmalkauf („extra Listen“). Produkt-ID ist aktuell Platzhalter. (`Shelf Notes/ProManager.swift`)

## Architecture Map
Textuelle Layer/Abhängigkeiten (kein separates Modul-Target; alles im App-Target):
- **UI (SwiftUI Views)**
  - Root + Tabs: `Shelf Notes/RootView.swift`
  - Feature-Screens (pro Tab/Flow): `Shelf Notes/LibraryView/*`, `Shelf Notes/BookDetail/*`, `Shelf Notes/BookImport/*`, `Shelf Notes/ProgressHub/*`, `Shelf Notes/Stats/*`, `Shelf Notes/Timeline/*`, `Shelf Notes/SettingsView.swift`
- **ViewModels / State-Modelle** (typisch `ObservableObject`, häufig `@MainActor`)
  - Import: `Shelf Notes/BookImport/BookImportView/BookImportViewModel*.swift`
  - Tags-Index: `Shelf Notes/TagsIndexModel.swift`
  - Timeline: `Shelf Notes/Timeline/ReadingTimelineViewModel.swift`
  - ProgressHub Metrics: `Shelf Notes/ProgressHub/ProgressHubMetricsModel.swift`
- **Services / Utilities**
  - SwiftData bootstrap + Fallback: `Shelf Notes/AppContainerHostView.swift`
  - Save-Diagnostics: `Shelf Notes/ModelContext+Diagnostics.swift`, `Shelf Notes/SyncDiagnostics.swift` + UI `Shelf Notes/SyncDiagnosticsView.swift`
  - Covers: `Shelf Notes/CoverThumbnailer.swift`, `Shelf Notes/CoverImageLoader.swift`, `Shelf Notes/CachedAsyncImage.swift`
  - External API: `Shelf Notes/GoogleBooksClient.swift`, DTO/Mapper: `Shelf Notes/GoogleBooksDTO.swift`, `Shelf Notes/GoogleVolumeBookMapper.swift`
  - CSV: `Shelf Notes/CSVCodec.swift`, `Shelf Notes/CSVImportExportView.swift`
- **Data Model (SwiftData @Model)**
  - `Book`, `ReadingSession`, `ReadingGoal`, `BookCollection`, `ChallengeRecord` (siehe „Data Model Map“)

## Folder Map
App-Quellcode liegt unter `Shelf Notes/` (Xcode synchronized groups). Wichtige Ordner:
- `Shelf Notes/AddBook/`: Add-Flow (Sheet-Routing, Cards, ViewModel).
- `Shelf Notes/LibraryView/`: Bibliothek-Tab (Filter/Sort, Grid/List, Bulk Actions, Appearance pro Row).
- `Shelf Notes/BookDetail/`: Detail-Screen + Subviews/Sheets (Cover, Collections, Ratings, Sessions).
- `Shelf Notes/BookImport/`: Google-Books Import & Filter/Query Builder.
- `Shelf Notes/ProgressHub/`: Fortschritt-Tab (Quicklinks, KPI/Metric-Recompute).
- `Shelf Notes/Stats/`: Statistik-UI inkl. Caching/Heatmap.
- `Shelf Notes/Timeline/`: Reading-Timeline (horizontales Scrolling + Year-Minimap).
- `Shelf Notes/Challenges/`: Challenge Models, Engine, Views.
- `Shelf Notes/AppearanceSettings/`: globale Appearance/Presets (via `@AppStorage`).
- `Shelf Notes/config/`: xcconfig (`base.xcconfig` inkludiert `secrets.xcconfig`).

## Data Model Map (SwiftData)
Schema wird zentral definiert in `Shelf Notes/AppContainerHostView.swift` (`ModelContainerFactory.schema`).

### Entities + Relationships
- **Book** (`Shelf Notes/Book.swift`)
  - Core: `id: UUID`, `title`, `author`, `createdAt`, `statusRawValue`, `tags: [String]`, `notes`
  - Reading range: `readFrom`, `readTo` (optional)
  - Collections: `collections: [BookCollection]?` (many-to-many, optional wegen CloudKit)
  - Sessions: `@Relationship(... inverse: \ReadingSession.book) readingSessions: [ReadingSession]?` (1:n, cascade delete)
  - Import metadata: `googleVolumeID`, `isbn13`, `thumbnailURL`, u.a. (viele optionale Felder)
  - Cover: `@Attribute(.externalStorage) userCoverData: Data?` (synced Thumbnail), plus `userCoverFileName: String?` (lokales Full-Res)
- **BookCollection** (`Shelf Notes/BookCollection.swift`)
  - `id`, `name`, `createdAt`, `updatedAt`, `books: [Book]?` (optional, CloudKit)
- **ReadingSession** (`Shelf Notes/ReadingSession.swift`)
  - `id`, `book: Book?` (inverse in `Book.readingSessions`), `startedAt`, `endedAt`, `durationSeconds`, `pagesRead?`, `note?`, `createdAt`
- **ReadingGoal** (`Shelf Notes/ReadingGoal.swift`)
  - `year`, `targetCount`, `updatedAt`
- **ChallengeRecord** (`Shelf Notes/Challenges/ChallengeModels.swift`)
  - Period: `periodStart`, `periodEnd`; Type: `kindRawValue`, `metricRawValue`; Target/Meta: `targetValue`, `completedAt?`, `acknowledgedAt?`, `rerollsUsed`, `rerolledAt?`

### Model-Regeln / CloudKit-SwiftData Besonderheiten
- Kein `@Attribute(.unique)` (explizite Kommentare in `Shelf Notes/Book.swift`, `Shelf Notes/ReadingSession.swift`, `Shelf Notes/BookCollection.swift`, `Shelf Notes/Challenges/ChallengeModels.swift`).
- Relationships **optional** halten, damit SwiftData+CloudKit sauber synchronisiert (Kommentare in `Shelf Notes/Book.swift`, `Shelf Notes/BookCollection.swift`).
- `#Predicate` Einschränkung: Enum cases nicht direkt in Predicates referenzieren → stattdessen persisted Raw-Strings (Beispiel: `Shelf Notes/ReadingTimelineView.swift`).

## Sync / Storage
- **Primary persistence**: SwiftData `ModelContainer` mit CloudKit Sync (`cloudKitDatabase: .automatic`). (`Shelf Notes/AppContainerHostView.swift`)
- **Robust bootstrap**: Kein `fatalError` bei Container-Failure; stattdessen Error-Screen + Retry; optional „local-only“ und „in-memory“ Modes. (`Shelf Notes/AppContainerHostView.swift`)
- **Store separation**: CloudKit-store und Local-only-store werden bewusst in getrennte `.store` Files geschrieben. (`Shelf Notes/AppContainerHostView.swift`, `ModelContainerFactory.StoreName` + `storeURL(...)`)
- **Remote notifications**: `UIBackgroundModes = remote-notification` (`Shelf Notes/Info.plist`) + `aps-environment` entitlement (`Shelf Notes/Shelf_Notes.entitlements`) → typisch für CloudKit background pushes.
- **Migrations/Repairs (one-time)**:
  - `ReadingStatusMigrator.migrateIfNeeded(...)` (Legacy Strings → stabile Codes). (`Shelf Notes/Book.swift`, Trigger in `Shelf Notes/RootView.swift`)
  - `CollectionMembershipRepair.repairIfNeeded(...)` (Book<->Collection membership dedupe/repair). (`Shelf Notes/CollectionMembershipRepair.swift`, Trigger in `Shelf Notes/AppContainerHostView.swift`)
  - Cover Thumbnail Backfill (deferred + chunked). (`Shelf Notes/RootView.swift` → `Shelf Notes/CoverThumbnailer.swift`)
- **Offline-Verhalten**: SwiftData speichert lokal; CloudKit Sync ist „best effort“. Detail-Progress ist nicht verfügbar; App zeigt stattdessen Signals (Account/Network/Local saves). (`Shelf Notes/SyncDiagnostics.swift`, `Shelf Notes/SyncDiagnosticsView.swift`)

## UI Map (Hauptscreens + Navigation)
### Entry Points
- App entry: `Shelf Notes/Shelf_NotesApp.swift` → `AppContainerHostView()`
- Root: `Shelf Notes/RootView.swift` (TabView)

### Tabs (RootView)
- **Bibliothek**: `Shelf Notes/LibraryView/LibraryView.swift` (NavigationStack + List/Grid + Filter/Sort + Bulk Actions)
- **Fortschritt**: `Shelf Notes/ProgressHub/ProgressHubView.swift` (NavigationStack, Links zu Stats/Timeline/Goals/Challenges)
- **Listen**: `Shelf Notes/CollectionsView.swift` (NavigationStack, Collections CRUD)
- **Tags**: `Shelf Notes/TagsView.swift` (NavigationStack, Tag-Liste → navigiert in `LibraryView(initialTag:)`)
- **Einstellungen**: `Shelf Notes/SettingsView.swift` (NavigationStack(path:) + Subscreens wie Appearance/Sync/CSV etc.)

### Wichtige Sheets/Flows (Auswahl)
- Add Book Sheet Router: `Shelf Notes/AddBook/AddBookSheet.swift` (enum `AddBookSheet`, zentrales `.sheet(item:)` Pattern).
- Barcode Scan: `Shelf Notes/BarcodeScannerSheet.swift` (VisionKit `DataScanner` → ISBN).
- Manual add: `Shelf Notes/ManualBookAddSheet.swift`
- Import (Google Books): `Shelf Notes/BookImport/*` (Search, Filters, Pagination, Import).
- Book Detail: `Shelf Notes/BookDetailView.swift` + `Shelf Notes/BookDetail/*` (Cover Picker, Notes, Sessions, Collections, Ratings).
- CSV Import/Export: `Shelf Notes/CSVImportExportView.swift` (auch First-Run Offer in `Shelf Notes/RootView.swift`).

## Build & Configuration
- Xcode project: `Shelf Notes.xcodeproj`
- Deployment target: iOS 26.0 (`Shelf Notes.xcodeproj/project.pbxproj`)
- Device families: iPhone+iPad (`TARGETED_DEVICE_FAMILY = "1,2"` in `Shelf Notes.xcodeproj/project.pbxproj`).
- Entitlements: iCloud CloudKit + APS dev. (`Shelf Notes/Shelf_Notes.entitlements`).
- Info.plist: Kamera/Photo-Library Usage Strings + background remote-notification + API key placeholder (`Shelf Notes/Info.plist`).
- Build settings via xcconfig: `Shelf Notes/config/base.xcconfig` includes `Shelf Notes/config/secrets.xcconfig`.
  - ⚠️ `secrets.xcconfig` enthält aktuell einen echten `GOOGLE_BOOKS_API_KEY` Wert (nicht im Text hier wiedergegeben). (`Shelf Notes/config/secrets.xcconfig`)
- StoreKit local config (dev/testing): `Shelf Notes/unlimited_collections.storekit` (**Product ID in Code ist noch Platzhalter**: `Shelf Notes/ProManager.swift`).

## Conventions (Naming, Patterns, Do/Don’t)
- File-Splits per Extensions/Subviews mit `+Suffix` (z.B. `LibraryView+FilteringSorting.swift`, `BookDetailView+Actions.swift`).
- Wenn ein View in mehrere Dateien gesplittet ist: keine `private` State/Helper, die in Extensions gebraucht werden (Kommentar in `Shelf Notes/LibraryView/LibraryView.swift`).
- SwiftData+CloudKit: keine Unique-Attributes, inverse Relationships definieren, optional relationships bevorzugen (siehe Model-Dateien).
- Heavy derived data cachen und via `.task(id:)` aktualisieren (z.B. `Shelf Notes/Stats/StatisticsView+Caching.swift`, `Shelf Notes/LibraryView/LibraryView.swift`, `Shelf Notes/TagsIndexModel.swift`).
- Save calls: bevorzugt `modelContext.saveWithDiagnostics()` statt nacktem `save()` (Breadcrumbs im UI). (`Shelf Notes/ModelContext+Diagnostics.swift`)

## How to work on this project (Setup Steps)
1) `Shelf Notes.xcodeproj` öffnen.
2) Signing/iCloud prüfen: Team, Bundle ID `de.marcfechner.Shelf-Notes`, iCloud Container `iCloud.de.marcfechner.Shelf-Notes`. (`Shelf Notes/Shelf_Notes.entitlements`)
3) Google Books API Key: Build Setting `GOOGLE_BOOKS_API_KEY` bereitstellen (via xcconfig). (`Shelf Notes/Info.plist`, `Shelf Notes/config/*.xcconfig`)
4) App starten (iPhone + iPad) und iCloud Sync testen: zwei Devices, gleiche Apple ID, Bücher hinzufügen, warten, vergleichen.
5) Wenn CloudKit bootstrap fehlschlägt: Error-Screen → Retry oder bewusst „local-only“ nutzen. (`Shelf Notes/AppContainerHostView.swift`).

## Quick Wins (max. 10, konkret)
1) `Shelf Notes/config/secrets.xcconfig` aus dem Repo entfernen/ignorieren (gitignore) und `secrets.template.xcconfig` einführen; Key nur lokal setzen. (Build-Sicherheit)
2) `ProManager.productID` von "001" auf echte App Store Connect Product ID setzen + StoreKit config anpassen. (`Shelf Notes/ProManager.swift`, `Shelf Notes/unlimited_collections.storekit`)
3) In `TagsView` und `ReadingTimelineView` Task-IDs vereinfachen (nicht Arrays als `.task(id:)` verwenden) → reduziert View invalidation overhead. (`Shelf Notes/TagsView.swift`, `Shelf Notes/ReadingTimelineView.swift`)
4) `CoverThumbnailer.backfillAllBooksIfNeeded` optional an eine „Idle“-Heuristik koppeln (z.B. nur wenn Gerät am Strom / Low Power Mode off) – um Akku zu schonen. (`Shelf Notes/RootView.swift`, `Shelf Notes/CoverThumbnailer.swift`) **UNKNOWN** ob erwünscht.
5) `SyncDiagnostics` Logging-Hook erweitern: CloudKit userRecord fetch errors sichtbar machen (nur UI/Debug). (`Shelf Notes/SyncDiagnostics.swift`, `Shelf Notes/SyncDiagnosticsView.swift`)
6) BookDetail: Top-Tags Berechnung aus `BookDetailView` herausziehen (dedizierter Cache wie `TagsIndexModel`) – vermeidet wiederholte O(n) Arbeit in Detail-UI. (`Shelf Notes/BookDetailView.swift`)
7) Langfristig: `Book.swift` ist bereits sehr groß → Metadaten in separaten Struct kapseln oder in Extensions auslagern (rein mechanisch, keine Model-Änderung). (`Shelf Notes/Book.swift`)
8) Prüfen ob `UIBackgroundModes` remote-notification wirklich gebraucht wird, wenn kein Sync genutzt werden soll (sonst ok). (`Shelf Notes/Info.plist`) **UNKNOWN** ob optional.
9) Tests: Snapshot/Unit Tests fehlen praktisch (nur Basic Test target). Minimal: Tag-normalization + CSV codec als Unit Tests ergänzen. (`Shelf Notes/CSVCodec.swift`, `Shelf Notes/BookImport/*`)
10) `AppContainerHostView`/`ModelContainerFactory` in eigene Datei auslagern (Bootstrapping vs UI trennen) – compile-time/Orientierung. (`Shelf Notes/AppContainerHostView.swift`)

## Feature Map (wo finde ich was?)
- **Bibliothek-Listing & Filter**: `Shelf Notes/LibraryView/LibraryView.swift` +
  - Filtering/Sorting/Derived caching: `Shelf Notes/LibraryView/LibraryView+FilteringSorting.swift`
  - Header UI (Filter-Chips, Search, Counts): `Shelf Notes/LibraryView/LibraryView+Header.swift`
  - List/Grid layouts: `Shelf Notes/LibraryView/LibraryView+Lists.swift`, `Shelf Notes/LibraryView/LibraryView+Grid.swift`
  - Bulk Actions: `Shelf Notes/LibraryView/LibraryView+BulkActions.swift`
  - Covers/Row: `Shelf Notes/LibraryView/LibraryRowCoverView.swift`, `Shelf Notes/BookRowView.swift`
- **Add Book**: `Shelf Notes/AddBook/AddBookView.swift` (+ Cards `AddBookView+Cards.swift`) → Sheets via `AddBookSheet.swift`
- **Import (Google Books)**:
  - Client: `Shelf Notes/GoogleBooksClient.swift`
  - DTO/Mapping: `Shelf Notes/GoogleBooksDTO.swift`, `Shelf Notes/GoogleVolumeBookMapper.swift`, `Shelf Notes/Book+Importing.swift`
  - UI: `Shelf Notes/BookImport/BookImportResultsView.swift`, `Shelf Notes/BookImport/BookImportSearchPanel.swift`
  - ViewModel: `Shelf Notes/BookImport/BookImportView/BookImportViewModel*.swift` (Search/Debounce/Pagination/Cancellation)
- **Book Detail**:
  - Host: `Shelf Notes/BookDetailView.swift`
  - Actions/Save/Logic split: `Shelf Notes/BookDetail/BookDetailView+Actions.swift`, `+Persistence.swift`, `+Logic.swift`, `+Bindings.swift`, `+Toolbar.swift`
  - Components/Sheets: `Shelf Notes/BookDetail/BookDetailComponents.swift`, `Shelf Notes/BookDetail/Sessions/*`
- **Reading Timer / Sessions**: `Shelf Notes/ReadingTimerManager.swift` + Session UI in `Shelf Notes/BookDetail/Sessions/*`
- **Stats (Charts/Heatmap)**: `Shelf Notes/StatisticsView.swift` + `Shelf Notes/Stats/*`
- **Timeline**: `Shelf Notes/ReadingTimelineView.swift` + `Shelf Notes/Timeline/*`
- **Collections**: `Shelf Notes/CollectionsView.swift`, `Shelf Notes/CollectionDetailView.swift`, `Shelf Notes/NewCollectionSheet.swift`
- **CSV Import/Export**: `Shelf Notes/CSVCodec.swift`, `Shelf Notes/CSVImportExportView.swift`
- **Appearance**: `Shelf Notes/AppearanceSettings/*` + Library spezifisch: `Shelf Notes/LibraryView/LibraryAppearanceSettingsView.swift`
- **Sync Diagnostics**: `Shelf Notes/SyncDiagnostics.swift` + UI `Shelf Notes/SyncDiagnosticsView.swift`

## Typical Data Flows
### Import → Persist → Cover
1) User startet Import (AddBook → Import Sheet). (`Shelf Notes/AddBook/*`, `Shelf Notes/BookImport/*`)
2) `BookImportViewModel` baut Query, ruft `GoogleBooksClient` auf und mappt DTO → `Book`. (`Shelf Notes/BookImport/BookImportView/BookImportViewModel*.swift`, `Shelf Notes/GoogleBooksClient.swift`, `Shelf Notes/GoogleVolumeBookMapper.swift`)
3) Persist via SwiftData `ModelContext` (idealerweise `saveWithDiagnostics`). (`Shelf Notes/ModelContext+Diagnostics.swift`, Save-Call-Sites: **UNKNOWN** wo überall konsequent genutzt)
4) Cover: aus Remote-URL wird Thumbnail erzeugt/synced. (`Shelf Notes/CoverThumbnailer.swift`, `Shelf Notes/Book.swift` `userCoverData`)

### Timer Session → Completion Sheet → Persist
1) Timer starten/pausieren/stoppen: `ReadingTimerManager`. (`Shelf Notes/ReadingTimerManager.swift`)
2) Stop erzeugt `pendingCompletion` → Sheet in `RootView`. (`Shelf Notes/RootView.swift`, `ReadingTimerManager.swift`)
3) Persistiert `ReadingSession` + optional pages/note. (`Shelf Notes/ReadingSession.swift`, Save-Sites: **UNKNOWN**)

## “How do I add feature X?” (Mini-Playbook)
- **Neuer Screen**: neuen Ordner unter `Shelf Notes/<Feature>/` anlegen, Host-View schlank halten, Subviews/Extensions in `+*.swift` auslagern (Pattern siehe `LibraryView`/`BookDetail`).
- **Neues SwiftData-Feld**: Feld in `@Model` hinzufügen, Default-Wert für non-optional setzen (CloudKit/SwiftData). Danach: auf iCloud-Schema/Migration achten (**UNKNOWN**: aktuelle Migrationsstrategie außerhalb der vorhandenen one-time Repairs).
- **Neue derived stats/list counts**: niemals im `body` über gesamte `books` Liste sortieren/aggregieren; stattdessen Snapshot + Cache-Model + `.task(id:)` (siehe `TagsIndexModel`, `StatisticsView+Caching`).


## Storage on Disk (wo liegen die Daten?)
- SwiftData Stores: `Application Support/ShelfNotes/SwiftData/<StoreName>.store` (erzeugt via `ModelContainerFactory.storeURL(...)`). (`Shelf Notes/AppContainerHostView.swift`)
  - CloudKit StoreName: `ShelfNotesCloud`
  - Local-only StoreName: `ShelfNotesLocal`
- User Full-Res Cover Files: `Application Support/user-covers/<generated>.jpg` (Dateiname in `Book.userCoverFileName`). (`Shelf Notes/CachedAsyncImage.swift` `UserCoverStore`, Nutzung u.a. in `Shelf Notes/CoverThumbnailer.swift`)
- Disk Cache für Remote-Covers: `Caches/cover-cache/<sha256(url)>.<ext>` (`ImageDiskCache`). (`Shelf Notes/CachedAsyncImage.swift`, Nutzung in `Shelf Notes/CoverImageLoader.swift`)

## Debugging / Observability (im App-UI)
- Sync/Network/Account Status: `SyncDiagnosticsView` ist ein eigener Screen. (`Shelf Notes/SyncDiagnosticsView.swift`, Datenquelle `Shelf Notes/SyncDiagnostics.swift`)
- Local Save Breadcrumbs: `ModelContext.saveWithDiagnostics()` speichert „zuletzt gespeichert“ + Quelle (FileID:Line). (`Shelf Notes/ModelContext+Diagnostics.swift`)

## Open Questions (für Onboarding/Docs)
- **CloudKit DB Mode**: `cloudKitDatabase: .automatic` → Welche DB nutzt SwiftData hier konkret (private/shared/public)? (`Shelf Notes/AppContainerHostView.swift`) **UNKNOWN**
- **Conflict resolution**: Gibt es definierte Regeln/Policy für Merge-Konflikte (z.B. gleichzeitige Edits auf zwei Geräten)? **UNKNOWN** (SwiftData abstrahiert das).
- **Secrets handling**: Soll `Shelf Notes/config/secrets.xcconfig` committed bleiben oder lokal sein? Aktuell liegt es im ZIP/Repo. **UNKNOWN**
- **Pro Monetization**: Welche echte Product ID / Preis / AppStoreConnect-Setup? Aktuell Platzhalter. (`Shelf Notes/ProManager.swift`) **UNKNOWN**
- **Telemetry/Logging**: Gibt es (außer SyncDiagnostics) ein Logging-Konzept (os.Logger, signposts)? **UNKNOWN**