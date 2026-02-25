# Shelf Notes — PROJECT_CONTEXT

## TL;DR
Shelf Notes ist eine iOS-App (SwiftUI) zum Verwalten einer persönlichen Bücher-Bibliothek inkl. Status (Will lesen/Lese ich/Gelesen), Tags, Listen (Collections), Lese-Sessions/Timer, Zielen, Statistiken/Heatmap und „Challenges“. Persistenz via SwiftData; Sync via iCloud/CloudKit (mit explizitem Local-Only Fallback). Mindest-iOS: 26.0.

## Key Concepts / Domänenbegriffe
- **Book**: Kern-Entity (Titel/Autor/Status/Tags/Notizen/Import-Metadaten/Cover). `Shelf Notes/Book.swift`
- **ReadingStatus**: Persistiert als stabiler String-Code (`toRead|reading|finished`), inkl. One-Time-Migration von alten lokalisierten Werten. `Shelf Notes/Book.swift`
- **ReadingSession**: Einzelne Lese-Session (Start/Ende/Dauer/Seiten/Notiz), gehört optional zu einem Book. `Shelf Notes/ReadingSession.swift`
- **ReadingTimerManager**: Timer-Flow für Sessions inkl. Completion-Sheet. `Shelf Notes/Timeline/ReadingTimerManager.swift`, `Shelf Notes/TimerSessionCompletionSheet.swift`
- **BookCollection**: Benutzerdefinierte Listen/Collections (many-to-many mit Book). `Shelf Notes/BookCollection.swift`, Repair: `Shelf Notes/CollectionMembershipRepair.swift`
- **Tags**: Freitext-Strings am Book; Normalisierung via `normalizeTagString(_)`. `Shelf Notes/TagNormalization.swift`
- **Import**: Google Books Import/Filter/Quick-Add. `Shelf Notes/BookImport/*`, DTO/Mapper: `Shelf Notes/GoogleBooksDTO.swift`, `Shelf Notes/GoogleVolumeBookMapper.swift`
- **Cover**: Synced Thumbnail (SwiftData external storage) + optional Full-Res lokal auf Disk. Loader/Cache/Thumbnailer: `Shelf Notes/CoverImageLoader.swift`, `Shelf Notes/CachedAsyncImage.swift`, `Shelf Notes/CoverThumbnailer/*`
- **Challenges**: Periodische Challenges (weekly/monthly), Compute/Snapshots getrennt. `Shelf Notes/Challenges/*`
- **Pro/Paywall**: StoreKit 2 Einmalkauf für mehr Listen. `Shelf Notes/ProManager.swift`, Test-Konfig: `Shelf Notes/unlimited_collections.storekit`
- **Sync Diagnostics**: In-App Diagnostik für iCloud/Network/letzte Saves. `Shelf Notes/SyncDiagnostics.swift`, UI: `Shelf Notes/SyncDiagnosticsView.swift`

## Architecture Map (Layer + Abhängigkeiten)
- **App Bootstrap / Storage**
  - App Entry: `Shelf Notes/Shelf_NotesApp.swift` → `AppContainerHostView()` (`Shelf Notes/AppContainerHostView.swift`).
  - Container-Bootstrap: `AppBootstrapper` + `ModelContainerFactory` erstellen `ModelContainer` in 3 Modi: CloudKit / LocalOnly / InMemory. `Shelf Notes/AppContainerHostView.swift`
- **Persistence (SwiftData Models)**
  - Entities: `Book`, `ReadingSession`, `ReadingGoal`, `BookCollection`, `ChallengeRecord`. `Shelf Notes/Book.swift`, `Shelf Notes/ReadingSession.swift`, `Shelf Notes/ReadingGoal.swift`, `Shelf Notes/BookCollection.swift`, `Shelf Notes/Challenges/ChallengeModels.swift`
- **UI (SwiftUI Features)**
  - Root Tabs: `RootView` (TabView) → Library / Fortschritt / Listen / Tags / Einstellungen. `Shelf Notes/RootView.swift`
  - Pro/Timer als `EnvironmentObject`: `ProManager`, `ReadingTimerManager`. `Shelf Notes/RootView.swift`, `Shelf Notes/ProManager.swift`, `Shelf Notes/Timeline/ReadingTimerManager.swift`
- **Services / Utilities**
  - Import (Google Books), CSV, Cover Pipeline, Tag Normalization, Diagnostics. (siehe Folder Map)

## Folder Map (Ordner → Zweck)
- `Shelf Notes/` (App-Sources, SwiftUI + SwiftData)
  - `AddBook/`: Add-Book Sheet + ViewModel (Import/Barcode/Manual). `Shelf Notes/AddBook/*`
  - `AppearanceSettings/`: UI/Theme/Typografie/Density Einstellungen. `Shelf Notes/AppearanceSettings/*`
  - `BookDetail/`: Detail-Screen Split (Bindings/Components/Sessions/Cover etc.). `Shelf Notes/BookDetail/*` + `Shelf Notes/BookDetailView.swift`
  - `BookImport/`: Import UI + ViewModels/Filter/Query Builder. `Shelf Notes/BookImport/*`
  - `Challenges/`: Challenge Engine + Models + Views. `Shelf Notes/Challenges/*`
  - `CoverThumbnailer/`: Thumbnail-Generierung, Remote-Fetch, Backfill, Apply. `Shelf Notes/CoverThumbnailer/*`
  - `LibraryView/`: Bibliotheks-Listen/Grid UI, Header, Row, Bulk Actions, Appearance-Subsettings. `Shelf Notes/LibraryView/*`
  - `ProgressHub/`: Fortschritt-Hub (Quick Links, Hero Metrics, Einstieg zu Stats/Goals/Timeline/Challenges). `Shelf Notes/ProgressHub/*`
  - `Stats/`: StatisticsView Splits (Data/Sections/Heatmap/Caching/Formatting/Components). `Shelf Notes/Stats/*` + `Shelf Notes/StatisticsView.swift`
  - `TagsView/`: Tags Tab + Index/Caching. `Shelf Notes/TagsView/*`
  - `Timeline/`: Reading Timeline + Timer Manager. `Shelf Notes/Timeline/*`
  - `config/`: Build-Konfiguration (xcconfig). `Shelf Notes/config/*`

## Data Model Map (Entities, Relationships, wichtige Felder)
### Book (`@Model`)
- Datei: `Shelf Notes/Book.swift`
- Wichtige Felder (Auszug): `id: UUID`, `title`, `author`, `createdAt`, `statusRawValue`, `tags: [String]`, `notes`
- Reading-Period: `readFrom`, `readTo` (Timeline/Goals)
- Import-Metadaten: `googleVolumeID`, `isbn13`, `thumbnailURL`, `publisher`, `publishedDate`, `pageCount`, `language`, `categories`, `bookDescription`, Links (`previewLink`/`infoLink`/`canonicalVolumeLink`) u.a.
- Cover:
  - `userCoverData: Data?` ist `@Attribute(.externalStorage)` (synced Thumbnail).
  - `userCoverFileName: String?` referenziert lokale Full-Res Datei (nicht synced).
- Relationships:
  - `collections: [BookCollection]?` (many-to-many, optional für CloudKit).
  - `readingSessions: [ReadingSession]?` mit `@Relationship(deleteRule: .cascade, inverse: \ReadingSession.book)`.

### ReadingSession (`@Model`)
- Datei: `Shelf Notes/ReadingSession.swift`
- Felder: `id`, `book: Book?`, `startedAt`, `endedAt`, `durationSeconds`, `pagesRead`, `note`, `createdAt`
- Inverse: `Book.readingSessions` (cascade delete).

### BookCollection (`@Model`)
- Datei: `Shelf Notes/BookCollection.swift`
- Felder: `id`, `name`, `createdAt`, `updatedAt`, `books: [Book]?` (many-to-many, optional).

### ReadingGoal (`@Model`)
- Datei: `Shelf Notes/ReadingGoal.swift`
- Felder: `year`, `targetCount`, `updatedAt`

### ChallengeRecord (`@Model`)
- Datei: `Shelf Notes/Challenges/ChallengeModels.swift`
- Felder (Auszug): `periodStart`, `periodEnd`, `kindRawValue`, `metricRawValue`, `title`, `detail`, `targetValue`, `completedAt`, `acknowledgedAt`, `rerollsUsed` …

## Sync / Storage
- SwiftData Schema/Container-Erzeugung: `Shelf Notes/AppContainerHostView.swift` (`ModelContainerFactory.schema` + `makeContainer(mode:)`).
- CloudKit Sync: `ModelConfiguration(..., cloudKitDatabase: .automatic)` in CloudKit-Mode. `Shelf Notes/AppContainerHostView.swift`
- iCloud Container ID: `iCloud.de.marcfechner.Shelf-Notes` (Entitlements). `Shelf Notes/Shelf_Notes.entitlements`
- Explizite Store-Trennung:
  - CloudKit-Store: `ShelfNotesCloud.store`
  - Local-Only-Store: `ShelfNotesLocal.store`
  - Beide liegen unter `Application Support/ShelfNotes/SwiftData/…` (siehe `storeURL(for:)`). `Shelf Notes/AppContainerHostView.swift`
- Bootstrap-Flow:
  - Start versucht CloudKit; bei Fehler: Error-Screen mit Retry / Local-Only / In-Memory. `Shelf Notes/AppContainerHostView.swift`
- One-time Repairs/Migrations:
  - `CollectionMembershipRepair.repairIfNeeded(...)` beim Container-Ready (pro Store-Scope). `Shelf Notes/AppContainerHostView.swift`, `Shelf Notes/CollectionMembershipRepair.swift`
  - `ReadingStatusMigrator.migrateIfNeeded(...)` beim RootView-Start. `Shelf Notes/RootView.swift`, `Shelf Notes/Book.swift`
- Offline-Fallback:
  - Local-Only Mode zeigt Banner + Alert. `Shelf Notes/AppContainerHostView.swift`
  - Sync Diagnostik zählt „offline saves“ (Signal, nicht echte Sync-Queue). `Shelf Notes/SyncDiagnostics.swift`, `Shelf Notes/ModelContext+Diagnostics.swift`

## UI Map (Screens + Navigation + wichtige Sheets/Flows)
### Root Tabs (`RootView`) — `Shelf Notes/RootView.swift`
- **Bibliothek** → `LibraryView()` (`Shelf Notes/LibraryView/LibraryView.swift`)
- **Fortschritt** → `ProgressHubView()` (`Shelf Notes/ProgressHub/ProgressHubView.swift`)
- **Listen** → `CollectionsView()` (`Shelf Notes/CollectionsView.swift`)
- **Tags** → `TagsView()` (`Shelf Notes/TagsView/TagsView.swift`)
- **Einstellungen** → `SettingsView()` (`Shelf Notes/SettingsView.swift`)

### Wichtige Flows / Sheets (Auszug)
- **Add Book**: aus Library → Sheet `AddBookView` → Import/Barcode/Manual. `Shelf Notes/LibraryView/LibraryView.swift`, `Shelf Notes/AddBook/AddBookView.swift`
- **Book Detail**: NavigationLink aus Library-Row → `BookDetailView`. `Shelf Notes/LibraryView/*`, `Shelf Notes/BookDetailView.swift` + `Shelf Notes/BookDetail/*`
- **Timer Completion**: `ReadingTimerManager.pendingCompletion` → `TimerSessionCompletionSheet`. `Shelf Notes/RootView.swift`, `Shelf Notes/TimerSessionCompletionSheet.swift`
- **Statistiken/Goals/Timeline/Challenges**: Einstieg über `ProgressHubView` NavigationLinks. `Shelf Notes/ProgressHub/ProgressHubView.swift`
- **CSV Import/Export**: Sheet beim First-Run (wenn keine Bücher). `Shelf Notes/RootView.swift`, `Shelf Notes/CSVImportExportView.swift`
- **Sync Diagnostics**: in Settings verlinkt (siehe SettingsView). `Shelf Notes/SettingsView.swift`, `Shelf Notes/SyncDiagnosticsView.swift`

## Build & Configuration
- Xcode Projekt: `Shelf Notes.xcodeproj` (`Shelf Notes.xcodeproj/project.pbxproj`).
- Bundle IDs: App `{'"de.marcfechner.Shelf-NotesUITests"', '"de.marcfechner.Shelf-NotesTests"', '"de.marcfechner.Shelf-Notes"'}` (siehe pbxproj).
- Mindest-iOS: `26.0` (pbxproj: `IPHONEOS_DEPLOYMENT_TARGET`).
- Targeted device family: `1,2` (pbxproj: `TARGETED_DEVICE_FAMILY`).
- Info.plist: `Shelf Notes/Info.plist`
  - `GOOGLE_BOOKS_API_KEY` ist via xcconfig-Substitution (`$(GOOGLE_BOOKS_API_KEY)`) verdrahtet.
  - `UIBackgroundModes`: `remote-notification` (CloudKit Push/Background Sync).
  - Privacy Strings: Kamera/Photo Library für Barcode & Cover.
- Entitlements: `Shelf Notes/Shelf_Notes.entitlements` (iCloud Container + CloudKit Service, APS environment = development).
- xcconfig:
  - `Shelf Notes/config/base.xcconfig` inkludiert `secrets.xcconfig`.
  - `Shelf Notes/config/secrets.xcconfig` definiert `GOOGLE_BOOKS_API_KEY` (ist in `.gitignore` ausgeschlossen).
- Dependencies: keine `Package.resolved` im Repo; Frameworks aus SDK: SwiftUI, SwiftData, CloudKit, StoreKit, Network, CryptoKit, Charts (optional via `#if canImport(Charts)`).

## Conventions (Naming, Patterns, Do/Don't)
- **Split via Extensions/Files**: große Views werden in `FooView+Something.swift` oder Folder-Splits aufgeteilt (z. B. `BookDetail/*`, `Stats/*`, `CoverThumbnailer/*`).
- **SwiftData Writes**: bevorzugt `modelContext.saveWithDiagnostics()` statt `try? modelContext.save()` (Breadcrumbs in SyncDiagnostics). `Shelf Notes/ModelContext+Diagnostics.swift`
- **CloudKit + Relationships**: Beziehungen in Models oft optional gehalten („CloudKit requires optional relationships“). Beispiel `Book.collections: [BookCollection]?`. `Shelf Notes/Book.swift`
- **Avoid heavy work in `body`**: Caches/Signatures/Tasks werden genutzt, um O(n) Aggregationen nicht bei jedem Render zu wiederholen. Beispiele: `TagsIndexModel` (`Shelf Notes/TagsView/TagsIndexModel.swift`), `ProgressHubMetricsModel` (`Shelf Notes/ProgressHub/ProgressHubMetricsModel.swift`), Library derived-state caching (`Shelf Notes/LibraryView/LibraryView.swift`).
- **User-facing Strings**: Status persistiert als stabile Codes, UI-Labels sind getrennt (Migration vorhanden). `Shelf Notes/Book.swift`

## How to work on this project (Setup + wo anfangen)
### Setup (neuer Dev-Rechner)
1. Xcode öffnen: `Shelf Notes.xcodeproj`.
2. Secrets anlegen: `Shelf Notes/config/secrets.xcconfig` mit `GOOGLE_BOOKS_API_KEY = …` (wird über `base.xcconfig` eingebunden). `Shelf Notes/config/base.xcconfig`, `Shelf Notes/Info.plist`
3. iCloud Capability prüfen: Entitlements enthalten `iCloud.de.marcfechner.Shelf-Notes`; in Xcode Signing & Capabilities muss das Container-Mapping passen. `Shelf Notes/Shelf_Notes.entitlements`
4. (Optional) StoreKit Tests: `Shelf Notes/unlimited_collections.storekit` im Scheme als StoreKit Configuration auswählen.
5. Run auf 2 Geräten (oder Simulator + Gerät), um CloudKit-Sync zu verifizieren.

### Wo anfangen (Onboarding für neue Devs)
- Einstiegspunkte:
  - App Bootstrap/Storage: `Shelf Notes/AppContainerHostView.swift`
  - Root Navigation + global Appearance: `Shelf Notes/RootView.swift`
  - Datenmodell: `Shelf Notes/Book.swift` + weitere `@Model` Files
- Für ein UI-Feature im Library-Bereich: `Shelf Notes/LibraryView/LibraryView.swift` + Extensions (`LibraryView+*.swift`).
- Für Stats/Charts: `Shelf Notes/StatisticsView.swift` + `Shelf Notes/Stats/*`.

## Quick Wins (max 10, konkret)
1. **Secrets harden**: Sicherstellen, dass `Shelf Notes/config/secrets.xcconfig` nie committed wird; API-Key rotieren, wenn er irgendwo gelandet ist. (`Shelf Notes/config/secrets.xcconfig`, `.gitignore`) 
2. **Stats compute entkoppeln**: `computeStatsCache`/Heatmap off-main via Value-Snapshots (siehe `Shelf Notes/StatisticsView.swift`, `Shelf Notes/Stats/*`).
3. **Inspiration Seeds cachen**: `ForYouSeedBuilder.build(from:)` nicht als computed property über `@Query books` im Renderpfad laufen lassen; stattdessen Task/Cache. (`Shelf Notes/InspirationSeedPickerView.swift`, `Shelf Notes/ForYouSeedBuilder.swift`) 
4. **Mehr Logging mit OSLog**: Sync/Import/Cover-Pipeline (gezielt, nicht überall). Startpunkt: `Shelf Notes/SyncDiagnostics.swift`, `Shelf Notes/BookImport/*`, `Shelf Notes/CoverThumbnailer/*`.
5. **Big-file Split**: `Shelf Notes/LibraryView/LibraryRowAppearanceSettingsSection.swift` in kleinere Subviews/Sections splitten (Merge-Konflikt-Killer).
6. **Challenge Engine invalidation**: prüfen, ob `ensureCurrentChallengesAndRefreshCompletion` wirklich nur beim Launch/Store-Wechsel laufen muss. (`Shelf Notes/AppContainerHostView.swift`, `Shelf Notes/Challenges/ChallengeEngine.swift`) 
7. **Background modes audit**: `UIBackgroundModes.remote-notification` & `aps-environment` (dev/prod) konsistent halten. (`Shelf Notes/Info.plist`, `Shelf Notes/Shelf_Notes.entitlements`) 
8. **Test coverage**: es gibt nur 1 Unit-Test File + 2 UI-Test Files; minimalen Smoke-Test für Container bootstrap + basic CRUD ergänzen. (`Shelf NotesTests/*`, `Shelf NotesUITests/*`) 
