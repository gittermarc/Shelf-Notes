# PROJECT_CONTEXT.md

## TL;DR

Shelf Notes ist eine SwiftUI-basierte iOS/iPadOS App (iPhone+iPad), die Bücher verwaltet und Lese-Fortschritt trackt (Status, Tags, Listen/Collections, Lesesessions + Timer, Statistik/Heatmap/Zeitleiste, Challenges) und Bücher via Google Books importieren kann. Persistenz läuft über SwiftData; Sync über iCloud/CloudKit ist standardmäßig aktiv, mit explizitem **Local-Only Fallback** bei iCloud-Problemen. Deployment Target laut Xcode-Projekt: iOS 26.0.

## Key Concepts / Domänenbegriffe

- **Book**: Zentrales Objekt (Metadaten, Status, Tags, Cover, Ratings).
- **ReadingSession**: Einzelne Lesesession (Start/Ende, Dauer, optional Seiten/Notiz) pro Book.
- **ReadingGoal**: Jahresziel (Anzahl Bücher) für Progress/Stats.
- **BookCollection**: Nutzerdefinierte Listen/Collections (many-to-many mit Books).
- **ChallengeRecord**: Persistierte Weekly/Monthly Challenge + Zielwert; Fortschritt wird aus Sessions/Books berechnet.
- **Cover Pipeline**: Synced Thumbnail in SwiftData (`Book.userCoverData`), Full-Res User-Cover lokal als Datei (`Book.userCoverFileName`).
- **Local-Only Mode**: Separater SwiftData Store ohne CloudKit (eigener Datenstand!).
- **Pro**: StoreKit Einmalkauf (aktuell Product-ID als Platzhalter in `Shelf Notes/ProManager.swift`).

## Architecture Map

**UI (SwiftUI Views)** → **Domain Models (SwiftData @Model)** → **Services/Utilities** → **Storage/Sync (SwiftData + CloudKit)**

- **App bootstrap & container**
  - `Shelf Notes/Shelf_NotesApp.swift` → startet `AppContainerHostView()`.
  - `Shelf Notes/AppContainerHostView.swift` enthält `AppBootstrapper` + `ModelContainerFactory` (CloudKit/localOnly/inMemory).
- **Domain / Persistenz**
  - `Shelf Notes/Book.swift`, `ReadingSession.swift`, `ReadingGoal.swift`, `BookCollection.swift`, `Challenges/ChallengeModels.swift`.
  - `ModelContext.saveWithDiagnostics()` in `Shelf Notes/ModelContext+Diagnostics.swift` (Breadcrumbs in `SyncDiagnostics`).
- **Services / Engines**
  - `Challenges/ChallengeEngine.swift` (Challenge-Erzeugung + Progress Compute).
  - `GoogleBooksClient.swift` (+ DTO/Mapper) für Import.
  - `CoverThumbnailer/*` + `CoverImageLoader.swift` + `CachedAsyncImage.swift` (Disk cache) für Cover.
- **Cross-cutting State**
  - `ProManager` (`Shelf Notes/ProManager.swift`) als `@EnvironmentObject`.
  - `ReadingTimerManager` (`Shelf Notes/Timeline/ReadingTimerManager.swift`) als `@EnvironmentObject`.
  - `SyncDiagnostics.shared` (`Shelf Notes/SyncDiagnostics.swift`) als Observability-Helfer.

## Folder Map

| Ordner | Zweck |
| --- | --- |
| `Shelf Notes/AddBook` | UI + ViewModel für “Buch hinzufügen” Flow (manuell / Scanner / Import-Einstieg). |
| `Shelf Notes/AppearanceSettings` | Globale Appearance-/Theme-Settings, StorageKeys, Presets/Optionen. |
| `Shelf Notes/BookDetail` | Detail-Screen für ein Buch inkl. Actions/Bindings/Toolbar + Unterbereiche (Sessions etc.). |
| `Shelf Notes/BookImport` | Google-Books Import UI + ViewModel + Filter/Query/Mapping Helper. |
| `Shelf Notes/Challenges` | Challenges: Modelle + Engine + UI (Weekly/Monthly). |
| `Shelf Notes/CoverThumbnailer` | Cover-Pipeline: Remote fetch, ImageIO resize/JPEG, Backfill, Apply user/remote cover. |
| `Shelf Notes/LibraryView` | Bibliothek Tab: Listen/Grid, Filter/Sort, Bulk Actions, Header + Row Cover Rendering. |
| `Shelf Notes/ProgressHub` | Fortschritt Tab: KPI/Hero-Karten, Quick Links, gecachte Metriken. |
| `Shelf Notes/Stats` | Statistik-Screen: Sections, Data helpers, Heatmap, Formatting, Caching. |
| `Shelf Notes/TagsView` | Tags Tab: Tag-Counts Index + Navigation in gefilterte LibraryView. |
| `Shelf Notes/Timeline` | Zeitleiste + Timer/Session-Flow (ReadingTimelineView, ReadingTimerManager, VM). |
| `Shelf Notes/config` | Build-Konfiguration (.xcconfig): base.xcconfig inkludiert secrets.xcconfig (API Keys). |

## Data Model Map (SwiftData)

### `Book` (`Shelf Notes/Book.swift`)

- **Identity/Core**: `id: UUID`, `title`, `author`, `createdAt`, `statusRawValue`, `tags: [String]`, `notes`.
- **Reading range** (für Timeline/Goals): `readFrom`, `readTo`.
- **Relationships**:
  - `collections: [BookCollection]?` (many-to-many, optional wegen CloudKit).
  - `readingSessions: [ReadingSession]?` mit `@Relationship(deleteRule: .cascade, inverse: \ReadingSession.book)`.
- **Cover/Images**:
  - `userCoverData: Data?` (`@Attribute(.externalStorage)`) = **synced Thumbnail**.
  - `userCoverFileName: String?` = lokales Full-Res User-Cover (siehe `UserCoverStore` in `Shelf Notes/CachedAsyncImage.swift`).
  - `thumbnailURL`, `coverURLCandidates` (Remote candidates).
- **Import-Metadaten** (Auszug): `googleVolumeID`, `isbn13`, `publisher`, `publishedDate`, `pageCount`, `language`, `categories`, `bookDescription`, Rating-/Access-/Sale-Felder.
- **User Ratings**: `userRatingPlot`, `userRatingCharacters`, `userRatingWritingStyle`, `userRatingAtmosphere`, `userRatingGenreFit`, `userRatingPresentation`.

### `ReadingSession` (`Shelf Notes/ReadingSession.swift`)
- `id: UUID` (ohne `.unique`), `book: Book?` (inverse in `Book.readingSessions`).
- `startedAt`, `endedAt`, `durationSeconds` (persistierter Cache), optional `pagesRead`, `note`.

### `ReadingGoal` (`Shelf Notes/ReadingGoal.swift`)
- `year`, `targetCount`, `updatedAt`.

### `BookCollection` (`Shelf Notes/BookCollection.swift`)
- `id: UUID`, `name`, `createdAt`, `updatedAt`.
- `books: [Book]?` (many-to-many, optional wegen CloudKit).

### `ChallengeRecord` (`Shelf Notes/Challenges/ChallengeModels.swift`)
- Period: `periodStart`, `periodEnd`.
- Type: `kindRawValue`, `metricRawValue`.
- Content/Target: `title`, `detail`, `targetValue`.
- Meta: `createdAt`, `completedAt`, `acknowledgedAt`, `rerollsUsed`, `rerolledAt`.

## Sync/Storage

- **SwiftData Container bootstrap**: `Shelf Notes/AppContainerHostView.swift`
  - Schema in `ModelContainerFactory.schema` (Book, ReadingSession, ReadingGoal, BookCollection, ChallengeRecord).
  - **CloudKit**: `ModelConfiguration(... cloudKitDatabase: .automatic)`.
  - **Local-only**: separater Store (`cloudKitDatabase: .none`) – eigener lokaler Datenstand.
  - **Store URLs**: Application Support unter `ShelfNotes/SwiftData/<StoreName>.store` (siehe `storeURL(for:)`).
  - **inMemory**: Notfallmodus (nicht persistent).
- **Offline-Verhalten**:
  - Bei CloudKit-Init-Failure wird ein Error-Screen angezeigt; User kann CloudKit retryen oder Local-only starten (`ModelContainerFailureView`).
  - Local-only Mode zeigt Banner + Alert.
- **CloudKit Identität/Entitlements**:
  - Entitlements: `Shelf Notes/Shelf_Notes.entitlements` mit iCloud container `iCloud.de.marcfechner.Shelf-Notes` + CloudKit Service.
  - Info.plist: Background Mode `remote-notification` (`Shelf Notes/Info.plist`) – typisch für CloudKit/SwiftData silent pushes.
- **Migrations/Repairs (one-time)**:
  - `ReadingStatusMigrator` in `Shelf Notes/Book.swift`, getriggert in `Shelf Notes/RootView.swift`.
  - `CollectionMembershipRepair.repairIfNeeded(...)` läuft pro Store-Scope beim Ready-State (`Shelf Notes/AppContainerHostView.swift`).
- **Cover Storage**:
  - Remote image disk cache: `cover-cache` in Caches (`ImageDiskCache` in `Shelf Notes/CachedAsyncImage.swift`).
  - Full-res User cover: `Application Support/user-covers` (`UserCoverStore` in `Shelf Notes/CachedAsyncImage.swift`).
  - Synced thumbnail: `Book.userCoverData` (`@Attribute(.externalStorage)`).

## UI Map (Screens + Navigation)

- **Entry**
  - `Shelf Notes/Shelf_NotesApp.swift` → `AppContainerHostView` → `RootView`.
- **Root Tabs** (`Shelf Notes/RootView.swift`)
  - **Bibliothek**: `LibraryView()` (`Shelf Notes/LibraryView/LibraryView.swift`) — NavigationStack + List/Grid, Filter/Sort, Bulk actions.
  - **Fortschritt**: `ProgressHubView()` (`Shelf Notes/ProgressHub/ProgressHubView.swift`) — KPI/Hero, Links zu Stats/Goals/Timeline/Challenges.
  - **Listen**: `CollectionsView()` (`Shelf Notes/CollectionsView.swift`) — Listenübersicht, Navigation zu `CollectionDetailView`.
  - **Tags**: `TagsView()` (`Shelf Notes/TagsView/TagsView.swift`) — Tag-Counts + Navigation in `LibraryView(initialTag:)`.
  - **Einstellungen**: `SettingsView()` (`Shelf Notes/SettingsView.swift`) — Appearance, SyncDiagnostics, Cache-Clear, Pro-Paywall.
- **Key Flows / Sheets** (Auszug, Pfade sind load-bearing)
  - **Book Detail**: `Shelf Notes/BookDetailView.swift` (Sheets u.a. Notes/Collections/Rating/Sessions/NewCollection/Paywall/Share/OnlineCoverPicker).
  - **Add Book**: `Shelf Notes/AddBook/*` + `BarcodeScannerSheet.swift`.
  - **CSV Import/Export**: `Shelf Notes/CSVImportExportView.swift` + `CSVCodec.swift`.
  - **Statistics**: `Shelf Notes/StatisticsView.swift` (+ Extensions in `Shelf Notes/Stats/*`).
  - **Timeline**: `Shelf Notes/Timeline/ReadingTimelineView.swift` + `ReadingTimelineViewModel.swift`.
  - **Timer Session Completion**: `Shelf Notes/TimerSessionCompletionSheet.swift` (sheet in `RootView`).

## Build & Configuration

- Xcode-Projekt: `Shelf Notes.xcodeproj`.
- Targets: App + Unit Tests (`Shelf NotesTests`) + UI Tests (`Shelf NotesUITests`).
- Bundle ID (App): `de.marcfechner.Shelf-Notes` (aus `project.pbxproj`).
- Deployment Target: iOS 26.0; Device Family: "1,2" ("1,2" = iPhone+iPad).
- Entitlements: `Shelf Notes/Shelf_Notes.entitlements` (iCloud/CloudKit, APS=development).
- Build Config Files:
  - `Shelf Notes/config/base.xcconfig` inkludiert `secrets.xcconfig`.
  - `Shelf Notes/config/secrets.xcconfig` ist in `.gitignore` (enthält `GOOGLE_BOOKS_API_KEY`).
- Info.plist: `Shelf Notes/Info.plist` setzt `GOOGLE_BOOKS_API_KEY` via Build Setting und hat `UIBackgroundModes = remote-notification`.
- Privacy Manifest: `Shelf Notes/PrivacyInfo.xcprivacy` (u.a. UserDefaults/FileTimestamp API Gründe).

## Conventions (Naming, Patterns, Do/Don’t)

- **SwiftData + CloudKit constraints** (im Code mehrfach dokumentiert):
  - Kein `@Attribute(.unique)` (CloudKit/SwiftData Kompatibilität).
  - Beziehungen oft **optional** (`[Type]?`) wegen CloudKit.
  - In Predicates lieber mit stabilen Raw-Strings arbeiten (siehe `ReadingTimelineView` Filter auf `statusRawValue`).
- **Performance**:
  - Keine O(n)-Aggregationen im Renderpfad (`body` / computed Views). Stattdessen: Snapshots/Signatures + Cache-Modelle (z.B. `TagsIndexModel`, `ProgressHubMetricsModel`, Stats caches).
  - Wenn `TabView` + Appearance Updates: Selection/Paths stabil halten (`RootView` nutzt `@SceneStorage` fürs Tab, `SettingsView` für NavigationPath).
- **Code-Organisation**:
  - Große Views werden in Extensions/Files gesplittet (z.B. `LibraryView+*.swift`, `Stats/*`, `BookDetail/*`).
  - Achtung Access-Control: `private` Members sind über Datei-Grenzen nicht sichtbar (siehe Hinweis in `LibraryView.swift`).
- **Saving**:
  - Möglichst `modelContext.saveWithDiagnostics()` verwenden (statt `try? save()`), damit `SyncDiagnostics` Signale bekommt.

## How to work on this project (Setup + Einstieg)

### Setup
- Xcode öffnen: `Shelf Notes.xcodeproj`.
- Sicherstellen, dass `Shelf Notes/config/secrets.xcconfig` **lokal** existiert (und nicht committed wird) und `GOOGLE_BOOKS_API_KEY` gesetzt ist.
- iCloud/CloudKit:
  - Device/Simulator mit iCloud Account (für echten CloudKit-Test i.d.R. Device).
  - Entitlements prüfen (`Shelf_Notes.entitlements`).
- Run:
  - Beim ersten Start kann CloudKit-Init fehlschlagen → nutze den Failure-Screen (Retry / Local-only / inMemory).

### Wo anfangen (neue Devs)
- App-Start/Storage: `Shelf Notes/AppContainerHostView.swift` (Container, Store-Separation, one-time repairs).
- Root UI: `Shelf Notes/RootView.swift` (Tabs, globale EnvironmentObjects, Migrations/Backfills).
- Domain model: `Shelf Notes/Book.swift` (größtes Modell + Migrationslogik) und die übrigen @Model-Dateien.
- Import: `Shelf Notes/BookImport/*` (Google Books Flow).
- Cover Pipeline: `Shelf Notes/CoverThumbnailer/*` + `CoverImageLoader.swift`.

## Quick Wins (max. 10)

1. **Secrets hygiene**: Prüfen, dass `Shelf Notes/config/secrets.xcconfig` wirklich nie in Git landet (aktuell in `.gitignore`). Falls bereits committed: Historie bereinigen.
2. **Pro Product ID**: `Shelf Notes/ProManager.swift` enthält Platzhalter `productID = "001"` → als Build-Config/xcconfig pro Environment konfigurieren.
3. **Book deletion cleanup**: Sicherstellen, dass bei jeder Löschung eines Books auch `UserCoverStore.delete(...)` aufgerufen wird (aktuell in `BookDetailView+Actions.swift` und `LibraryView+BulkActions.swift`).
4. **ChallengeEngine MainActor**: `ChallengeEngine.ensureCurrentChallenges(...)` läuft im Ready-State auf dem MainActor (`AppContainerHostView.swift`). Wenn Daten wachsen: Compute/Fetch in Snapshot off-main auslagern.
5. **Stats caches vereinheitlichen**: In `StatisticsView.swift` existieren zwei Cache-Pfade (StatsCache/HeatmapCache). Eine gemeinsame Cache-Struktur + ein Update-Task reduziert Komplexität.
6. **Library derived recompute**: `LibraryView` cached Filter/Sort/Alpha. Prüfen, ob Recompute an `@Query`-Änderungen exakt und nicht über-triggered ist (Files: `LibraryView+FilteringSorting.swift`, `LibraryView.swift`).
7. **SyncDiagnostics Entry**: `SettingsView.swift` nutzt `SyncDiagnostics.shared`. Einen klaren “Refresh” Button/Trigger (falls nicht vorhanden) hält Debugging simpel.
8. **Predicate robustness**: Where predicates use raw strings (e.g. "Gelesen") – nach Migration kann Legacy Value entfallen → zentralisieren (z.B. `ReadingStatus.finished.rawValue` + legacy list), um Drift zu vermeiden.
9. **CSV Import guardrails**: In `CSVImportExportView.swift` klare Limits/Validations für große Dateien (Progress UI, cancellation) prüfen.
10. **Add tests for migrations**: `ReadingStatusMigrator` + `CollectionMembershipRepair` sind one-time, aber kritisch → minimaler Unit-Test/fixture gegen Regressionen.
