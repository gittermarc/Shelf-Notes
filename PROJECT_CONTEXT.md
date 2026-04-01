# PROJECT_CONTEXT.md

Stand des Scans: 2026-04-01
Projekt: `Shelf Notes`

## TL;DR

`Shelf Notes` ist eine SwiftUI-basierte iOS-/iPadOS-App zur Verwaltung einer persönlichen Bibliothek mit Fokus auf Lesestatus, Lesesessions, Ziele, Statistiken, Tags, Listen/Collections, Google-Books-Import und einer Live Activity für laufende Lesetimer. Der Hauptspeicher ist SwiftData mit CloudKit-Sync als Standardmodus; zusätzlich existieren ein expliziter Local-only-Fallback und ein In-Memory-Notmodus. Der Haupt-Target-Deployment-Stand ist laut `Shelf Notes.xcodeproj/project.pbxproj` iOS **26.0**; die Live-Activity-Extension ist auf iOS **26.2** gesetzt.

## Key Concepts / Domänenbegriffe

- **Book** (`Shelf Notes/Book.swift`)
  - Zentrale Domänenentität.
  - Enthält Basisdaten, Import-Metadaten, Cover-Informationen, User-Ratings, Collections-Beziehungen und Reading Sessions.

- **ReadingStatus** (`Shelf Notes/Book.swift`)
  - Persistierte Statuscodes: `toRead`, `reading`, `finished`.
  - UI zeigt lokalisierte Labels; persistiert werden stabile Rohwerte.

- **ReadingSession** (`Shelf Notes/ReadingSession.swift`)
  - Einzelne Lesesession mit Start/Ende, Dauer, optional gelesenen Seiten und Notiz.
  - Basis für Streaks, Minuten, Heatmap, Challenges und Fortschritt.

- **ReadingGoal** (`Shelf Notes/ReadingGoal.swift`)
  - Jahresziel für gelesene Bücher.

- **BookCollection** (`Shelf Notes/BookCollection.swift`)
  - Nutzerdefinierte Liste / Sammlung von Büchern.
  - Many-to-many zu `Book`.

- **ChallengeRecord** (`Shelf Notes/Challenges/ChallengeModels.swift`)
  - Persistierte Wochen-/Monats-Challenge mit Zielwert und Completion-/Claim-Zeitpunkten.

- **Tags Index** (`Shelf Notes/TagsView/TagsIndexBuilder.swift`, `Shelf Notes/TagsView/TagsIndexStore.swift`)
  - Zentraler, signaturbasierter App-Cache für normalisierte Tag-Häufigkeiten.

- **Library Derived State** (`Shelf Notes/LibraryView/LibraryDerivedStateBuilder.swift`)
  - Pure Derived-State-Ebene für Bibliotheksfilter, Sortierung, Counts und Alpha-Sections.

- **Statistics Snapshot / Pipeline** (`Shelf Notes/Stats/StatisticsSnapshotBuilder.swift`, `Shelf Notes/Stats/StatisticsComputePipeline.swift`)
  - Value-only Snapshot der Bibliothek plus Off-Main-Compute für Statistik- und Heatmap-Caches.

- **CoverThumbnailer** (`Shelf Notes/CoverThumbnailer/*`)
  - Erzeugt/synchronisiert kleine Cover-Thumbnails.
  - Vollauflösende Nutzercover bleiben lokal auf dem Gerät.

- **ProManager** (`Shelf Notes/ProManager.swift`)
  - Einmalkauf für zusätzliche Listen.

- **SyncDiagnostics** (`Shelf Notes/SyncDiagnostics.swift`)
  - Diagnostik-Helfer für lokale Saves, Netzwerkstatus und iCloud-Accountstatus.

- **ReadingTimerManager** (`Shelf Notes/BookDetail/Sessions/ReadingTimerManager/*`)
  - Globaler Timer-Manager für eine aktive Lesesession.
  - Persistiert aktiven Zustand in App-Group-Storage für Live Activity.

## Architecture Map

### 1) App Bootstrap / Composition Root

- `Shelf Notes/Shelf_NotesApp.swift`
  - App Entry Point.
  - Startet `AppContainerHostView()`.

- `Shelf Notes/AppContainerHostView.swift`
  - Erstellt `ModelContainer`.
  - Wählt Storage-Modus: CloudKit, Local-only oder In-Memory.
  - Zeigt Fehler-/Fallback-UI bei Container-Initialisierungsproblemen.
  - Startet One-Time-Reparaturen und Challenge-Initialisierung.

- `Shelf Notes/RootView.swift`
  - Tab-Root der App.
  - Registriert globale `EnvironmentObject`s:
    - `ProManager`
    - `ReadingTimerManager`
    - `TagsIndexStore`
  - Startet globale Aufgaben:
    - Statusmigration
    - Cover-Backfill
    - Tag-Index-Aktualisierung

### 2) Persistenz / Domain

- SwiftData-Modelle:
  - `Shelf Notes/Book.swift`
  - `Shelf Notes/ReadingSession.swift`
  - `Shelf Notes/ReadingGoal.swift`
  - `Shelf Notes/BookCollection.swift`
  - `Shelf Notes/Challenges/ChallengeModels.swift`

- Schema-Definition:
  - `Shelf Notes/AppContainerHostView.swift`

### 3) Feature-Schicht

- Bibliothek:
  - `Shelf Notes/LibraryView/*`
- Buchdetail + Sessions + Timer:
  - `Shelf Notes/BookDetail/*`
- Hinzufügen / Import:
  - `Shelf Notes/AddBook/*`
  - `Shelf Notes/BookImport/*`
  - `Shelf Notes/ManualBookAddSheet.swift`
  - `Shelf Notes/BarcodeScannerSheet.swift`
- Fortschritt:
  - `Shelf Notes/ProgressHub/*`
  - `Shelf Notes/Stats/*`
  - `Shelf Notes/Timeline/*`
  - `Shelf Notes/GoalsView.swift`
  - `Shelf Notes/Challenges/*`
- Listen / Tags / Settings:
  - `Shelf Notes/CollectionsView.swift`
  - `Shelf Notes/CollectionDetailView.swift`
  - `Shelf Notes/TagsView/*`
  - `Shelf Notes/Settings/*`

### 4) Infrastruktur / Services / Utilities

- Import / Remote APIs:
  - `Shelf Notes/GoogleBooksClient.swift`
  - `Shelf Notes/GoogleBooksDTO.swift`
  - `Shelf Notes/GoogleVolumeBookMapper.swift`

- Covers / Bilder:
  - `Shelf Notes/CachedAsyncImage.swift`
  - `Shelf Notes/CoverImageLoader.swift`
  - `Shelf Notes/CoverThumbnailer/*`
  - `Shelf Notes/LibraryView/LibraryRowCoverView.swift`

- Sync / Save / Diagnostics:
  - `Shelf Notes/SyncDiagnostics.swift`
  - `Shelf Notes/SyncDiagnosticsView.swift`
  - `Shelf Notes/ModelContext+Diagnostics.swift`
  - `Shelf Notes/CollectionMembershipRepair.swift`

- Monetarisierung:
  - `Shelf Notes/ProManager.swift`
  - `Shelf Notes/ProPaywallView.swift`
  - `Shelf Notes/unlimited_collections.storekit`

- Live Activity Shared Layer:
  - `Shelf Notes/Shared/LiveActivity/*`
  - `Shelf Notes/BookDetail/Sessions/LiveActivity/*`
  - `ShelfNotesLiveActivity/*`

### 5) Abhängigkeitsrichtung (faktisch)

- UI-Views hängen direkt von SwiftData-Modellen ab.
- Größere Compute-/Derived-State-Pfade nutzen pure Builder oder ViewModels:
  - `LibraryDerivedStateBuilder`
  - `TagsIndexBuilder`
  - `StatisticsSnapshotBuilder`
  - `StatisticsHeatmapBuilder`
  - `ChallengeEngine+Compute`
  - `ProgressHubMetricsModel`
  - `ReadingTimelineViewModel`
- Es gibt **keine** durchgängige Repository-/Service-Abstraktionsschicht zwischen UI und SwiftData.
- Für Infrastruktur werden mehrere Singletons verwendet:
  - `GoogleBooksClient.shared`
  - `SyncDiagnostics.shared`
  - `ImageMemoryCache.shared`
  - `ImageDiskCache.shared`
  - `SyncedThumbnailMemoryCache.shared`

## Folder Map

### App Root / Composition

- `Shelf Notes/Shelf_NotesApp.swift`
  - App Entry.
- `Shelf Notes/AppContainerHostView.swift`
  - Container-Bootstrap, Fallback-UI, Store-Modi.
- `Shelf Notes/RootView.swift`
  - TabView + globale Tasks + globale EnvironmentObjects.
- `Shelf Notes/ContentView.swift`
  - Nur Wrapper auf `RootView`; App startet **nicht** direkt hier.

### Domain / Models (Root-Level)

- `Shelf Notes/Book.swift`
- `Shelf Notes/ReadingSession.swift`
- `Shelf Notes/ReadingGoal.swift`
- `Shelf Notes/BookCollection.swift`
- `Shelf Notes/ImportedBook.swift`

### Features

- `Shelf Notes/LibraryView/`
  - Bibliothek, Derived State, Listen-/Grid-Darstellung, Filter-UI, Cover-Rendering.
- `Shelf Notes/BookDetail/`
  - Detailscreen, Karten, Toolbars, Bindings, Session-Logik.
- `Shelf Notes/BookImport/`
  - Google-Books-Suche, Filter, Paging, Query-Building, Kategorie-Normalisierung.
- `Shelf Notes/AddBook/`
  - Add-Book-Flow als Shell/Orchestrator um Import-, Scan-, Inspiration- und Manual-Add-Flows.
- `Shelf Notes/ProgressHub/`
  - Fortschritts-Hub.
- `Shelf Notes/Stats/`
  - Statistiken, Heatmap, Compute-Pipeline, Caches.
- `Shelf Notes/Timeline/`
  - Horizontale Lesetimeline mit Mini-Map.
- `Shelf Notes/Challenges/`
  - Persistierte Challenges plus Compute-/Snapshot-Schicht.
- `Shelf Notes/TagsView/`
  - Tag-Index und Tag-Navigation.
- `Shelf Notes/Settings/`
  - App-/Library-Appearance, Sync-Diagnose, Import/Export, Pro, Session-Settings.

### Infrastruktur / Shared

- `Shelf Notes/CoverThumbnailer/`
  - Bildverarbeitung, Thumbnail-Generierung, Backfill, Remote-Fetch.
- `Shelf Notes/Shared/LiveActivity/`
  - Shared Models, App Group Access, Activity Attributes.
- `Shelf Notes/config/`
  - Build-Konfiguration.

### Tests / Targets

- `Shelf NotesTests/`
  - Aktuell stark fokussiert auf pure Builder / Statistiken / Tags.
- `Shelf NotesUITests/`
  - Sehr klein.
- `ShelfNotesLiveActivity/`
  - Widget/Live-Activity-Extension.

## Data Model Map

### `Book` — `Shelf Notes/Book.swift`

**Wichtige Felder**

- Identität / Basis
  - `id: UUID`
  - `title: String`
  - `author: String`
  - `createdAt: Date`
  - `statusRawValue: String`
  - `tags: [String]`
  - `notes: String`
- Lesebezug
  - `readFrom: Date?`
  - `readTo: Date?`
- Beziehungen
  - `collections: [BookCollection]?`
  - `readingSessions: [ReadingSession]?` mit Cascade-Delete via inverse Beziehung
- Import-/Metadaten
  - `googleVolumeID`, `isbn13`, `thumbnailURL`
  - `publisher`, `publishedDate`, `pageCount`, `language`, `categories`, `bookDescription`
  - `subtitle`, `previewLink`, `infoLink`, `canonicalVolumeLink`
  - `averageRating`, `ratingsCount`, `mainCategory`
  - `coverURLCandidates`
  - `viewability`, `isPublicDomain`, `isEmbeddable`
  - `isEpubAvailable`, `isPdfAvailable`, `epubAcsTokenLink`, `pdfAcsTokenLink`
  - `saleability`, `isEbook`
- Cover
  - `userCoverData: Data?` mit `@Attribute(.externalStorage)`
  - `userCoverFileName: String?`
- User-Ratings
  - sechs Persistenzfelder für Kriterien-Ratings (`userRatingPlot`, `userRatingCharacters`, ...)

**Beziehungen**

- `Book` 1:n `ReadingSession`
- `Book` n:m `BookCollection`

**Wichtige abgeleitete Properties / Logik**

- `status`
- `userRatingAverage`, `userRatingAverage1`
- `coverCandidatesAll`, `bestCoverURLString`
- `readingProgressFraction`
- Collection- und Session-Helper

### `ReadingSession` — `Shelf Notes/ReadingSession.swift`

**Felder**

- `id: UUID`
- `book: Book?`
- `startedAt: Date`
- `endedAt: Date`
- `durationSeconds: Int`
- `pagesRead: Int?`
- `note: String?`
- `createdAt: Date`

**Bemerkungen**

- Dauer wird persistiert und nicht nur ad hoc berechnet.
- `pagesReadNormalized` kapselt Input-Bereinigung.

### `ReadingGoal` — `Shelf Notes/ReadingGoal.swift`

**Felder**

- `year: Int`
- `targetCount: Int`
- `updatedAt: Date`

### `BookCollection` — `Shelf Notes/BookCollection.swift`

**Felder**

- `id: UUID`
- `name: String`
- `createdAt: Date`
- `updatedAt: Date`
- `books: [Book]?`

**Bemerkungen**

- Optionales Beziehungsarray wegen CloudKit-/SwiftData-Kompatibilität.
- `booksSafe` kapselt `nil` als leeres Array.

### `ChallengeRecord` — `Shelf Notes/Challenges/ChallengeModels.swift`

**Felder**

- `id: UUID`
- `periodStart`, `periodEnd`
- `kindRawValue`, `metricRawValue`
- `title`, `detail`
- `targetValue`
- `createdAt`, `completedAt`, `acknowledgedAt`
- `rerollsUsed`, `rerolledAt`

**Bemerkungen**

- Kein Bezug zu `Book`/`Session`; Fortschritt wird aus Snapshots berechnet.

## Sync / Storage

### Verwendete Persistenz

- SwiftData wird direkt verwendet.
- Ein expliziter Core-Data-Layer wurde im Scan **nicht** gefunden.
- SwiftData-Schema wird in `Shelf Notes/AppContainerHostView.swift` gebaut.

### Store-Modi

- CloudKit-Store (Standard)
  - `ModelConfiguration(..., cloudKitDatabase: .automatic)`
- Local-only-Store
  - `ModelConfiguration(..., cloudKitDatabase: .none)`
- In-Memory-Store
  - Nur Fallback / Notmodus

### Store-Orte

In `Shelf Notes/AppContainerHostView.swift` werden getrennte Store-Dateien unter `Application Support/ShelfNotes/SwiftData/` angelegt:

- `ShelfNotesCloud.store`
- `ShelfNotesLocal.store`

Wichtig:

- CloudKit- und Local-only-Datenstände sind absichtlich getrennt.
- Ein Wechsel zwischen beiden Modi mischt Daten **nicht** automatisch zusammen.

### CloudKit / Entitlements

- `Shelf Notes/Shelf_Notes.entitlements`
  - iCloud-Container: `iCloud.de.marcfechner.Shelf-Notes`
  - iCloud-Service: `CloudKit`
  - App Group: `group.de.marcfechner.Shelf-Notes`
- `ShelfNotesLiveActivityExtension.entitlements`
  - dieselbe App Group

### Sync-Diagnostik

- `Shelf Notes/SyncDiagnostics.swift`
  - `CKContainer.default().accountStatus`
  - `fetchUserRecordID`
  - `NWPathMonitor` für Netzstatus
  - Persistenz von Save-Breadcrumbs in `UserDefaults`
- `Shelf Notes/ModelContext+Diagnostics.swift`
  - Wrappt `save()` und schreibt Diagnostik-Breadcrumbs

### Offline-Verhalten

- Normalmodus:
  - Lokale Saves werden sofort in SwiftData persistiert.
  - Bei Offline-Zustand zählt `SyncDiagnostics` Offline-Saves.
  - Synchronisierung soll später über iCloud nachziehen.
- Local-only-Modus:
  - Bewusst separater lokaler Datenstand.
  - Keine Synchronisation.
  - UI zeigt Banner + Alert.

### Caches / lokale Dateispeicher

- `Shelf Notes/CachedAsyncImage.swift`
  - `ImageMemoryCache`
  - `ImageDiskCache` unter Caches-Verzeichnis
  - `UserCoverStore` unter Application Support (`user-covers`)
- `Shelf Notes/LibraryView/LibraryRowCoverView.swift`
  - `SyncedThumbnailMemoryCache`
- `Shelf Notes/Stats/*`
  - in-memory State-Caches für Stats/Heatmap
- `Shelf Notes/TagsView/TagsIndexStore.swift`
  - signaturbasierter Tag-Cache
- `Shelf Notes/Shared/LiveActivity/LiveActivitySharedStore.swift`
  - App-Group-`UserDefaults`
  - App-Group-Dateiablage für Live-Activity-Cover

### Migration / Reparatur / Backfill

Gefundene ad-hoc-Migrations-/Repair-Pfade:

- `Shelf Notes/Book.swift`
  - `ReadingStatusMigrator`
- `Shelf Notes/CollectionMembershipRepair.swift`
  - One-Time-Repair für Book↔Collection-Beziehungen
- `Shelf Notes/CoverThumbnailer/CoverThumbnailer+Backfill.swift`
  - One-Time-Thumbnail-Backfill
- `Shelf Notes/BookDetail/Sessions/ReadingTimerManager/ReadingTimerManager+Persistence.swift`
  - Migration des alten Timer-Blobs in die App Group

**Nicht gefunden:**

- `SchemaMigrationPlan`
- `VersionedSchema`
- explizite SwiftData-Migrationsstufen

=> Für zukünftige Schemaänderungen gibt es aktuell **keine** explizit dokumentierte Migrationsarchitektur.

## UI Map

### Root Navigation

`Shelf Notes/RootView.swift`

Tabs:

1. `LibraryView()`
2. `ProgressHubView()`
3. `CollectionsView()`
4. `TagsView()`
5. `SettingsView()`

### Bibliothek

- Root: `Shelf Notes/LibraryView/LibraryView.swift`
- Navigation:
  - `NavigationStack`
  - Buch → `BookDetailView(book:)`
- Wichtige Flows:
  - Add Sheet → `AddBookView()`
  - Bulk Add to Collection → `BulkAddToCollectionSheet`
  - Delete Alert
  - Such-/Filter-/Sortier-Header
  - Listen- oder Grid-Darstellung

### Buchdetail

- Root: `Shelf Notes/BookDetail/BookDetailView.swift`
- Wichtige Inhalte:
  - Header / Status / Sessions / Read Range / Ratings / Notes / Tags / Collections / More Info
- Wichtige Sheets:
  - `NotesEditorSheet`
  - `CollectionsPickerSheet`
  - `RatingEditorSheet`
  - `AllSessionsListSheet`
  - `InlineNewCollectionSheet`
  - `ProPaywallView`
  - `ActivityView` (Share)
  - `OnlineCoverPickerSheet`
- Zusätzlicher Flow:
  - laufender Timer / pausieren / stoppen über `ReadingTimerManager`

### Add Book / Import

- Root-Shell: `Shelf Notes/AddBook/AddBookView.swift`
- Unterflüsse:
  - Google Books → `Shelf Notes/BookImport/BookImportView/BookImportView.swift`
  - Barcode → `Shelf Notes/BarcodeScannerSheet.swift`
  - Inspiration → `Shelf Notes/InspirationSeedPickerView.swift`
  - Manuell → `Shelf Notes/ManualBookAddSheet.swift`

### Fortschritt

- Root: `Shelf Notes/ProgressHub/ProgressHubView.swift`
- Ziele:
  - `StatisticsView()`
  - `GoalsView()`
  - `ReadingTimelineView()`
  - `ChallengesView()`

### Listen

- `Shelf Notes/CollectionsView.swift`
  - Listet Collections
  - Neue Liste via `NewCollectionSheet`
  - Pro-Gating via `ProPaywallView`
- `Shelf Notes/CollectionDetailView.swift`
  - Rename + Bücherliste + Entfernen aus Liste

### Tags

- `Shelf Notes/TagsView/TagsView.swift`
  - Listet normalisierte Tags mit Counts
  - Klick navigiert in `LibraryView(initialTag:)`

### Settings

- `Shelf Notes/Settings/SettingsView.swift`
  - Appearance-Navigation
  - Buchsuche-Sprache
  - CSV Import/Export
  - Sync-Diagnose
  - Session-Auto-Stop
  - Cover-Cache löschen
  - Pro / Restore Purchases
  - Version / Build

### Live Activity

- Main App:
  - `Shelf Notes/BookDetail/Sessions/LiveActivity/*`
- Extension:
  - `ShelfNotesLiveActivity/*`

## Build & Configuration

### Targets

Aus `Shelf Notes.xcodeproj/project.pbxproj`:

- `Shelf Notes`
- `Shelf NotesTests`
- `Shelf NotesUITests`
- `ShelfNotesLiveActivityExtension`

### Deployment Targets

- `Shelf Notes`: iOS 26.0
- `Shelf NotesTests`: iOS 26.0
- `Shelf NotesUITests`: **UNKNOWN** (kein klarer, separater Scan-Auszug mit Wert gesichert notiert; App-Niveau wirkt gleich, aber hier nicht als Fakt behaupten)
- `ShelfNotesLiveActivityExtension`: iOS 26.2

### Info.plist / Capabilities

- `Shelf Notes/Info.plist`
  - `GOOGLE_BOOKS_API_KEY` via Build Setting
  - `NSCameraUsageDescription`
  - `NSPhotoLibraryUsageDescription`
  - `NSSupportsLiveActivities = true`
  - `UIBackgroundModes = remote-notification`

Hinweis:

- Für `UIBackgroundModes = remote-notification` wurde im gescannten App-Code kein klarer Remote-Notification-Handling-Pfad gefunden. **UNKNOWN**, ob das geplant, alt oder extern generiert ist.

### xcconfig / Secrets

- `Shelf Notes/config/base.xcconfig`
  - inkludiert `secrets.xcconfig`
- `Shelf Notes/config/secrets.xcconfig`
  - enthält `GOOGLE_BOOKS_API_KEY`

Wichtig:

- Der API-Key liegt aktuell repo-nah im Projektstand vor.
- Das ist aus Security-/Ops-Sicht ein Risiko.

### StoreKit

- `Shelf Notes/unlimited_collections.storekit`
  - lokale StoreKit-Testdatei vorhanden
- `Shelf Notes/ProManager.swift`
  - Product-ID aktuell `001`

### SPM / externe Pakete

- In `Shelf Notes.xcodeproj/project.pbxproj` wurden **keine** Swift Package References gefunden.
- Drittabhängigkeiten laufen im gescannten Stand über Apple-Frameworks und eigenen Code.

### Tests

- `Shelf NotesTests/*`
  - nutzt `import Testing`
  - kein klassisches XCTest-first-Setup in den gescannten Testdateien
- Schwerpunkt aktuell:
  - `LibraryDerivedStateBuilder`
  - `Statistics*`
  - `TagsIndex*`

## Conventions

### Naming / Datei-Schnittmuster

- Viele große Screens sind in `View + Extensions` gesplittet:
  - Beispiel: `LibraryView.swift` + `LibraryView+Header.swift` + `LibraryView+Grid.swift` + ...
  - Beispiel: `BookDetailView.swift` + `BookDetailView+Bindings.swift` + ...
- Pure Compute ist häufig in dedizierte Builder-Dateien ausgelagert:
  - `LibraryDerivedStateBuilder.swift`
  - `TagsIndexBuilder.swift`
  - `StatisticsSnapshotBuilder.swift`
  - `StatisticsHeatmapBuilder.swift`
  - `ChallengeEngine+Compute.swift`

### Persistenzregeln

- Saves laufen typischerweise über `modelContext.saveWithDiagnostics()`.
- CloudKit-Kompatibilitätsregeln sind mehrfach explizit kommentiert:
  - keine `@Attribute(.unique)`
  - optionale Beziehungen
  - Defaults für non-optional persistierte Felder

### UI-/State-Muster

- `@Query` direkt in Views ist Standard.
- Teure Filter-/Sortierlogik wird teilweise in Builder/ViewModels verschoben.
- Signaturen/Tokens werden zur Invalidierung verwendet:
  - `TagsIndexStore.taskSignature`
  - `LibraryDerivedInputToken`
  - `StatisticsStatsCacheKey`, `StatisticsHeatmapCacheKey`
  - `ProgressHubMetricsModel.InputToken`

### Do / Don’t

**Do**

- Neue schwere Ableitungen als pure Snapshot-/Builder-Logik bauen.
- Saves bündeln, wenn mehrere zusammenhängende Mutationen passieren.
- Bei SwiftData-/CloudKit-Modelländerungen Defaults und optionale Beziehungen sauber prüfen.
- Für Scroll-/Statistikpfade Renderarbeit aus `body` herausziehen.

**Don’t**

- Keine lokalen Datei-URLs in CloudKit-synchronisierte Stringfelder schreiben (`Shelf Notes/Book.swift`).
- Keine rechenintensiven O(n)-Aggregationen direkt in `body`, wenn sie sich cachen/signieren lassen.
- Keine neuen globalen Singletons ohne klaren Grund.

## How to work on this project

### Setup Steps

1. `Shelf Notes.xcodeproj` öffnen.
2. Signing / iCloud / App Group für die lokale Team-Konfiguration prüfen.
3. `Shelf Notes/config/secrets.xcconfig` prüfen.
4. Falls nötig: Google-Books-Key lokal ersetzen statt repo-weit zu teilen.
5. Mit dem App-Target `Shelf Notes` starten.
6. Für Live Activity zusätzlich Extension-/Capability-Setup prüfen.

### Wo neue Entwickler anfangen sollten

1. `Shelf Notes/Shelf_NotesApp.swift`
2. `Shelf Notes/AppContainerHostView.swift`
3. `Shelf Notes/RootView.swift`
4. Domain-Modelle in:
   - `Shelf Notes/Book.swift`
   - `Shelf Notes/ReadingSession.swift`
   - `Shelf Notes/ReadingGoal.swift`
   - `Shelf Notes/BookCollection.swift`
   - `Shelf Notes/Challenges/ChallengeModels.swift`
5. Danach den gewünschten Feature-Root öffnen.

### Workflow: neues Feature hinzufügen

- UI-Einstiegspunkt festlegen:
  - neuer Tab?
  - neuer Flow aus bestehendem Tab?
  - neues Sheet aus `BookDetailView` / `SettingsView` / `LibraryView`?
- Datenbedarf festlegen:
  - existierende `@Model`s erweitern?
  - nur Derived State?
  - nur transientes UI?
- Bei neuer Persistenz:
  - `ModelContainerFactory.schema` prüfen
  - CloudKit-Regeln prüfen
  - Migrationsauswirkung dokumentieren
- Für teure Listen-/Statistiklogik:
  - Snapshot/Builder/ViewModel statt Logik direkt in `body`
- Save-Punkte:
  - möglichst über `saveWithDiagnostics()`
- Tests:
  - bevorzugt pure Builder/Parser/Derived-State-Schichten testen

## Quick Wins

1. `Shelf Notes/BookDetailComponents1.swift` umbenennen oder sauber einordnen; aktueller Dateiname wirkt wie Restartefakt.
2. `Shelf Notes/CSVImportExportView.swift` in View + Import-Executor + Export-Builder aufteilen.
3. `Shelf Notes/config/secrets.xcconfig` aus repo-getracktem Secret-Handling herausziehen.
4. `Shelf Notes/Info.plist` aufräumen: `remote-notification` nur behalten, wenn wirklich genutzt.
5. `Shelf Notes/Book.swift` funktional entkoppeln: Schema, Ratings, Cover-URLs, Migration, Collection-Helper trennen.
6. `Shelf Notes/Stats/StatisticsSnapshotBuilder.swift` entlang seiner Verantwortungen splitten.
7. `Shelf Notes/GoalsView.swift` Derived Values cachen oder in ViewModel auslagern.
8. Gemeinsame Analytics-/Session-Indizes für Stats, Goals, ProgressHub und Challenges prüfen.
9. Für `GoogleBooksClient` und Pro-/StoreKit-Pfade testbare Protokollabstraktionen ergänzen.
10. Eine kleine technische README ergänzen, die Store-Modi, CloudKit-Regeln und Fallback-Verhalten erklärt.
