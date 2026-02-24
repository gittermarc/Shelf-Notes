# Shelf Notes — PROJECT_CONTEXT (Start Here)

_Last updated: 2026-02-24_

## TL;DR

Shelf Notes ist eine iOS/iPadOS-App zum Verwalten einer persönlichen Bibliothek (Bücher) inkl. Status (Will lesen / Lese ich / Gelesen), Notizen, Tags, Listen/Collections, Reading-Timer-Sessions, Statistiken (Charts/Heatmap), Leseziele und periodische Challenges. Persistenz + Sync laufen über **SwiftData** mit **CloudKit** (automatic) und einem expliziten Fallback auf **Local-only** oder **In-Memory** bei Container-Startfehlern.

- Plattformen: iOS + iPadOS (ein Target: **"Shelf Notes"**)
- Mindest-iOS: **26.0** (Xcode-Projektsetting) — siehe `Shelf Notes.xcodeproj/project.pbxproj` (`IPHONEOS_DEPLOYMENT_TARGET = 26.0;`)
- Bundle ID: `de.marcfechner.Shelf-Notes` — siehe `Shelf Notes.xcodeproj/project.pbxproj`
- CloudKit Container: `iCloud.de.marcfechner.Shelf-Notes` — siehe `Shelf Notes/Shelf_Notes.entitlements`

---

## Key Concepts / Domänenbegriffe

- **Book** (`Shelf Notes/Book.swift`): Zentrales Objekt (Titel, Autor, Status, Tags, Notizen, Metadaten, Cover, Ratings).
- **ReadingStatus** (`Shelf Notes/Book.swift`): Persistiert als stabiler Code (`toRead/reading/finished`) via `statusRawValue`. Migration von Legacy-Strings: `ReadingStatusMigrator`.
- **ReadingSession** (`Shelf Notes/ReadingSession.swift`): Zeitbasierte Lesesession pro Buch (Start/Ende, Dauer, optional Seiten, Notiz).
- **ReadingTimer** (`Shelf Notes/ReadingTimerManager.swift`): Globaler Timer, der eine laufende Session verwaltet und beim Stop eine **PendingCompletion** (Sheet) auslöst.
- **ReadingGoal** (`Shelf Notes/ReadingGoal.swift`): Jahresziel (Jahr → Zielanzahl Bücher).
- **BookCollection** (`Shelf Notes/BookCollection.swift`): Benutzerdefinierte Liste/Collection (many-to-many zu Books; optional wegen CloudKit).
- **Tags** (`Shelf Notes/TagNormalization.swift`, `Shelf Notes/TagsIndexModel.swift`): Freitext-Tags mit Normalisierung + Count-Index (Cache) für UI.
- **Challenges** (`Shelf Notes/Challenges/*`): Weekly/Monthly ChallengeRecords, Progress aus Sessions/Books berechnet.
- **Cover-System**:
  - **Synced Thumbnail**: `Book.userCoverData` (`@Attribute(.externalStorage)`) — syncfähiges Thumbnail
  - **Full-res User Cover**: lokal als Datei (`UserCoverStore` in `Shelf Notes/CachedAsyncImage.swift`)
  - **Remote Cover Cache**: Disk-/Memory-Cache (`ImageDiskCache`, `ImageMemoryCache` in `Shelf Notes/CachedAsyncImage.swift`)
- **Pro / Paywall** (`Shelf Notes/ProManager.swift`, `Shelf Notes/ProPaywallView.swift`): Einmalkauf (StoreKit2) für mehr Collections.

---

## Architecture Map (Text)

**UI Layer (SwiftUI Views)**
- Root + App Shell:
  - `Shelf Notes/Shelf_NotesApp.swift` → `AppContainerHostView()`
  - `Shelf Notes/AppContainerHostView.swift` (Bootstrap + Failure UI + Local-only Banner)
  - `Shelf Notes/RootView.swift` (TabView, globale Appearance, Timer-Sheet, One-time Migrations)
- Feature Screens (Tabs / NavigationStacks):
  - Library: `Shelf Notes/LibraryView/*`
  - Progress Hub (Stats/Goals/Timeline/Challenges Einstieg): `Shelf Notes/ProgressHubView.swift`
  - Collections: `Shelf Notes/CollectionsView.swift`, `Shelf Notes/CollectionDetailView.swift`, `Shelf Notes/NewCollectionSheet.swift`
  - Tags: `Shelf Notes/TagsView.swift`, `Shelf Notes/TagsIndexModel.swift`
  - Settings: `Shelf Notes/SettingsView.swift`, `Shelf Notes/AppearanceSettingsView.swift`, `Shelf Notes/SyncDiagnosticsView.swift`, `Shelf Notes/CSVImportExportView.swift`
- Detail/Sheets:
  - Book Detail: `Shelf Notes/BookDetail/*` + `Shelf Notes/BookDetailView.swift` (Host)
  - Add Book / Import: `Shelf Notes/AddBook/*`, `Shelf Notes/BookImport/*`
  - Timer completion sheet: `Shelf Notes/TimerSessionCompletionSheet.swift`

**Domain / Data Layer (SwiftData Models)**
- Modelle: `Book`, `ReadingSession`, `ReadingGoal`, `BookCollection`, `ChallengeRecord`
- Schema + Container: `ModelContainerFactory.schema` in `Shelf Notes/AppContainerHostView.swift`

**Services / Infrastructure**
- SwiftData + CloudKit bootstrap/fallback: `Shelf Notes/AppContainerHostView.swift`
- Save diagnostics: `Shelf Notes/ModelContext+Diagnostics.swift` + `Shelf Notes/SyncDiagnostics.swift`
- Google Books API: `Shelf Notes/GoogleBooksClient.swift`, DTOs: `Shelf Notes/GoogleBooksDTO.swift`, Mapping: `Shelf Notes/GoogleVolumeBookMapper.swift`
- Cover IO + Thumbnail pipeline: `Shelf Notes/CoverImageLoader.swift`, `Shelf Notes/CachedAsyncImage.swift`, `Shelf Notes/CoverThumbnailer.swift`
- Search History: `Shelf Notes/SearchHistoryStore.swift`

**Cross-cutting**
- Appearance/Theming via AppStorage + Environment modifiers: `Shelf Notes/RootView.swift`, `Shelf Notes/AppearancePreferences.swift`, `Shelf Notes/AppearanceSettingsView.swift`
- Performance Caches in Views: Library derived cache (`Shelf Notes/LibraryView/LibraryView.swift`), Stats caches (`Shelf Notes/Stats/StatisticsView.swift` + `...+Caching.swift`), TagsIndexModel.

---

## Folder Map (Ordner → Zweck)

Repo-Root: `Shelf-Notes/`

- `Shelf Notes/`  
  App Target Sources (SwiftUI, Models, Services).
- `Shelf Notes/AddBook/`  
  "Buch hinzufügen" Flow (Scanner, Seeds, Import-Sheet, Manual Add).  
  Einstieg: `Shelf Notes/AddBook/AddBookView.swift`.
- `Shelf Notes/BookImport/`  
  Suche/Import von Büchern (Google Books) inkl. Filter, Pagination, Quick-Add.  
  VM: `Shelf Notes/BookImport/BookImportView/BookImportViewModel.swift`.
- `Shelf Notes/BookDetail/`  
  Detailansicht + Subviews/Logic + Sessions UI.  
  Host: `Shelf Notes/BookDetailView.swift`, Logic: `Shelf Notes/BookDetail/BookDetailView+Logic.swift`.
- `Shelf Notes/LibraryView/`  
  Bibliotheksliste/grid, Filterbar, Bulk actions, Header, Appearance-Sektion etc.  
  Host: `Shelf Notes/LibraryView/LibraryView.swift` (split via Extensions).
- `Shelf Notes/Stats/`  
  Statistiken (Charts, Heatmap, Top-Listen, Caches).  
  Host: `Shelf Notes/StatisticsView.swift`, Daten: `Shelf Notes/Stats/StatisticsView+Data.swift`.
- `Shelf Notes/Timeline/`  
  Reading timeline UI (Zeitstrahl).  
  Einstieg: `Shelf Notes/ReadingTimelineView.swift`.
- `Shelf Notes/Challenges/`  
  ChallengeEngine + Modelle + UI.  
  Engine: `Shelf Notes/Challenges/ChallengeEngine.swift`.
- `Shelf Notes/config/`  
  `.xcconfig` für Build Settings (inkl. Secrets).  
  **Achtung:** `Shelf Notes/config/secrets.xcconfig` enthält einen API-Key → siehe "Quick Wins".
- `Shelf NotesTests/`, `Shelf NotesUITests/`  
  Test Targets (aktuell minimal; Inhalte siehe Ordner).

---

## Data Model Map (SwiftData Entities)

> Quelle: SwiftData `@Model` Klassen + `ModelContainerFactory.schema` in `Shelf Notes/AppContainerHostView.swift`.

### Book (`Shelf Notes/Book.swift`)
- Primär: `id: UUID` (kein `@Attribute(.unique)`; explizit kommentiert)
- Core:
  - `title: String`
  - `author: String`
  - `createdAt: Date`
  - `statusRawValue: String` (persistierter Status-Code)
  - `tags: [String]`
  - `notes: String`
- Zeit/Goals:
  - `readFrom: Date?`, `readTo: Date?`
- Beziehungen:
  - `collections: [BookCollection]?` (many-to-many, optional wegen CloudKit)
  - `readingSessions: [ReadingSession]?` (`@Relationship(.cascade, inverse: \ReadingSession.book)`)
- Import-Metadaten (Auszug):
  - `googleVolumeID: String?`, `isbn13: String?`
  - `thumbnailURL: String?`
  - viele zusätzliche Felder (Publisher, PublishedDate, Links, Kategorien, Ratings, AccessInfo, SaleInfo)
- Cover:
  - `userCoverData: Data?` (`@Attribute(.externalStorage)`) — synced thumbnail
  - `userCoverFileName: String?` — lokale full-res Datei (nicht synced)
  - `coverURLCandidates: [String]` — best-first Kandidatenliste (persistiert)
- User Rating:
  - 6 Kriterien `userRating*` (Int 0–5), `userRatingAverage` computed
- Regeln/Migration:
  - `ReadingStatusMigrator` migriert Legacy `statusRawValue` Strings → stabile Codes.
  - `status` computed property setzt Regeln (bei != finished: read range + ratings reset).

### ReadingSession (`Shelf Notes/ReadingSession.swift`)
- `id: UUID`
- Beziehung: `book: Book?` (inverse: `Book.readingSessions`)
- Zeiten:
  - `startedAt: Date`, `endedAt: Date`
  - `durationSeconds: Int` (cached)
- Optional:
  - `pagesRead: Int?`, `note: String?`
- `createdAt: Date`
- Helper: `recomputeDuration()`

### ReadingGoal (`Shelf Notes/ReadingGoal.swift`)
- `year: Int` (default: aktuelles Jahr)
- `targetCount: Int`
- `updatedAt: Date`

### BookCollection (`Shelf Notes/BookCollection.swift`)
- `id: UUID`
- `name: String`
- `createdAt: Date`, `updatedAt: Date`
- Beziehung: `books: [Book]?` (many-to-many, optional)
- Helpers: `booksSafe`, `addBook`, `removeBook`, `contains`

### ChallengeRecord (`Shelf Notes/Challenges/ChallengeModels.swift`)
- `id: UUID`
- Period: `periodStart`, `periodEnd`
- Typ: `kindRawValue`, `metricRawValue`
- Content: `title`, `detail`
- Target: `targetValue: Int`
- Meta: `createdAt`, `completedAt`, `acknowledgedAt`, reroll tracking

---

## Sync / Storage

### SwiftData Container + Stores
- Bootstrapper + Factory: `Shelf Notes/AppContainerHostView.swift`
  - `AppBootstrapper` startet standardmäßig `StorageMode.cloudKit`.
  - Fehler → `ModelContainerFailureView` mit Optionen:
    - Retry CloudKit
    - Start **localOnly** (persistenter Store ohne CloudKit)
    - Start **inMemory** (Notfall)
- Store-URLs:
  - AppSupport → `ShelfNotes/SwiftData/<StoreName>.store` (siehe `ModelContainerFactory.storeURL(...)`)
  - StoreNames: `ShelfNotesCloud`, `ShelfNotesLocal`
- CloudKit:
  - `ModelConfiguration(..., cloudKitDatabase: .automatic)` in CloudKit-Mode
  - Entitlements: `Shelf Notes/Shelf_Notes.entitlements` (iCloud container)
- Offline-Verhalten:
  - Im CloudKit-Mode speichert SwiftData lokal und synchronisiert später (SwiftData-Standard).
  - `SyncDiagnostics` zählt offline Saves (`offlineSaveCount`) und zeigt Netzwerkstatus.

### Diagnostik / Save-Breadcrumbs
- `ModelContext.saveWithDiagnostics()` in `Shelf Notes/ModelContext+Diagnostics.swift`
  - ruft `try save()` und schreibt "last local save" + ggf. Fehler in `SyncDiagnostics`.
- UI:
  - `Shelf Notes/SettingsView.swift` → NavigationLink zu `SyncDiagnosticsView`
  - `Shelf Notes/SyncDiagnosticsView.swift` zeigt Report + Buttons (Reset etc.)

### One-time Repairs / Migrations (beim App-Start)
- ReadingStatus Migration: `ReadingStatusMigrator.migrateIfNeeded(...)` in `Shelf Notes/Book.swift` (triggered in `Shelf Notes/RootView.swift` `.task`)
- Collection Membership Repair: `CollectionMembershipRepair.repairIfNeeded(...)` in `Shelf Notes/CollectionMembershipRepair.swift`  
  Trigger: `Shelf Notes/AppContainerHostView.swift` `.task(id: mode)` (pro Store-Scope: cloudKit vs localOnly)
- Cover thumbnail backfill: `CoverThumbnailer.backfillAllBooksIfNeeded(...)` in `Shelf Notes/CoverThumbnailer.swift`  
  Trigger: `Shelf Notes/RootView.swift` (deferred + batch + cancellable, nur wenn App active)

### Cover Storage Strategy (wichtig für Sync)
- Synced thumbnail: `Book.userCoverData` (`@Attribute(.externalStorage)`)  
  => kleines JPEG, syncfähig
- Full-res Cover:
  - lokal gespeichert (`UserCoverStore` in `Shelf Notes/CachedAsyncImage.swift`)
  - `Book.userCoverFileName` hält nur den Dateinamen
- Remote covers:
  - Download + Cache: `ImageDiskCache` (Caches/cover-cache) + `ImageMemoryCache` in `Shelf Notes/CachedAsyncImage.swift`
  - Thumbnail generation: ImageIO off-main in `Shelf Notes/CoverThumbnailer.swift`

---

## UI Map (Hauptscreens + Navigation + wichtige Flows)

### App Entry / Bootstrap
- `Shelf Notes/Shelf_NotesApp.swift` → `AppContainerHostView`
- `AppContainerHostView`:
  - Loading: `ProgressView`
  - Ready: `RootView().modelContainer(container)` + repairs/backfill tasks
  - Failed: `ModelContainerFailureView` (Retry / Local-only / In-memory)

### Tabs (RootView)
Quelle: `Shelf Notes/RootView.swift`

1. **Bibliothek** (`Shelf Notes/LibraryView/LibraryView.swift`)
   - NavigationStack intern.
   - List/Grid, Filterbar, Search (`.searchable`), Bulk-Selection + Bulk-Actions.
   - "Add book" via Sheet: `AddBookView()` (siehe `showingAddSheet`).
   - Detail: typischerweise NavigationLink zu `BookDetailView` (siehe Library extensions; Pfade in `Shelf Notes/LibraryView/*`).

2. **Fortschritt** (`Shelf Notes/ProgressHubView.swift`)
   - NavigationStack.
   - Hero metrics (year progress, last7 days, streak), Quick links:
     - Statistiken (`Shelf Notes/StatisticsView.swift`)
     - Ziele (`Shelf Notes/GoalsView.swift`)
     - Zeitleiste (`Shelf Notes/ReadingTimelineView.swift`)
     - Challenges (`Shelf Notes/ChallengesView.swift`)

3. **Listen** (`Shelf Notes/CollectionsView.swift`)
   - Overview + Create.
   - Detail: `CollectionDetailView` + Bulk Add Sheet (`Shelf Notes/BulkAddToCollectionSheet.swift`).
   - Paywall/Limit: gesteuert durch `ProManager.maxFreeCollections` (siehe `Shelf Notes/ProManager.swift` + UI in `Shelf Notes/ProPaywallView.swift`).

4. **Tags** (`Shelf Notes/TagsView.swift`)
   - Tag index/counts via `TagsIndexModel` (Cache) → vermeidet O(n) Aggregation im Renderpfad.
   - Tap auf Tag navigiert typischerweise in Library-Filter (siehe `LibraryView.init(initialTag:)`).

5. **Einstellungen** (`Shelf Notes/SettingsView.swift`)
   - NavigationStack mit persistentem `NavigationPath` via SceneStorage (stabil bei Appearance-Changes).
   - Unterseiten:
     - Appearance: `Shelf Notes/AppearanceSettingsView.swift`
     - Sync Diagnose: `Shelf Notes/SyncDiagnosticsView.swift`
     - CSV Import/Export: `Shelf Notes/CSVImportExportView.swift`
   - Cover Cache clear: `ImageDiskCache.shared.clearAll()` etc.
   - Pro: Paywall + Restore via StoreKit2.

### Zentrale Sheets / Flows
- **Add Book**: `Shelf Notes/AddBook/AddBookView.swift`
  - Sheets: Import (`BookImportView`), Scanner (`BarcodeScannerSheet`), Inspiration seeds (`InspirationSeedPickerView`), Manual Add (`ManualBookAddSheet`).
- **Book Import**: `Shelf Notes/BookImport/*`
  - VM mit Debounce + Cancellation + Pagination: `BookImportViewModel.swift` + `BookImportViewModel+Tasks.swift`.
- **Book Detail**: `Shelf Notes/BookDetailView.swift` + `Shelf Notes/BookDetail/*`
  - Sheets: NotesEditor, CollectionsPicker, RatingEditor, Sessions list, OnlineCoverPicker, Paywall.
  - Parallax Header + `.task(id: book.id)` refresh/backfill synced thumbnail (siehe `Shelf Notes/BookDetail/BookDetailComponents.swift`).
- **Reading Timer Completion**:
  - Root-level sheet: `RootView` `.sheet(item: $timer.pendingCompletion)` → `TimerSessionCompletionSheet` (`Shelf Notes/TimerSessionCompletionSheet.swift`)

---

## Build & Configuration

### Targets
- `Shelf Notes` (app)
- `Shelf NotesTests` (unit tests)
- `Shelf NotesUITests` (UI tests)  
Quelle: `Shelf Notes.xcodeproj/project.pbxproj`

### Info.plist / Entitlements
- Info.plist: `Shelf Notes/Info.plist`
  - `GOOGLE_BOOKS_API_KEY` via `$(GOOGLE_BOOKS_API_KEY)` (aus `.xcconfig`)
  - `UIBackgroundModes`: `remote-notification`
  - Usage strings: Kamera/Photos
- Entitlements: `Shelf Notes/Shelf_Notes.entitlements`
  - iCloud container identifiers
  - CloudKit service
  - `aps-environment` ist auf `development` gesetzt (**UNKNOWN**, ob für Release angepasst wird)

### xcconfig / Secrets
- Base config: `Shelf Notes/config/base.xcconfig` (`#include "secrets.xcconfig"`)
- Secrets: `Shelf Notes/config/secrets.xcconfig` (enthält `GOOGLE_BOOKS_API_KEY`)  
  → **Sicherheitsrisiko**, siehe "Quick Wins".

### Dependencies
- Keine externen SPM-Packages im `.xcodeproj` sichtbar (packageProductDependencies sind leer).  
  Apple Frameworks: SwiftData, StoreKit, CloudKit, Network, Charts (conditional).

---

## Conventions (Naming, Patterns, Do/Don't)

### SwiftData + CloudKit
- Kein `@Attribute(.unique)` für CloudKit-synced Models (siehe Kommentare in `Book.swift`, `ReadingSession.swift`, `BookCollection.swift`, `ChallengeModels.swift`).
- Relationships:
  - CloudKit: viele Beziehungen sind optional (`[BookCollection]?`, `[Book]?`) um CloudKit-Anforderungen zu erfüllen.
  - Inverse bei 1:n zwingend (`Book.readingSessions` hat inverse `\ReadingSession.book`).
- Speichern über `modelContext.saveWithDiagnostics()` nutzen (statt `try? modelContext.save()`), um Sync-Breadcrumbs zu haben.

### SwiftUI Compile-Time / Wartbarkeit
- Große Views werden über Extensions gesplittet:
  - Beispiel: `Shelf Notes/LibraryView/LibraryView.swift` + `LibraryView+Header.swift` + weitere `LibraryView+*.swift`
- Achtung bei `private`: private Members sind nicht in anderen Dateien sichtbar (Kommentar in `LibraryView.swift`).

### Performance Patterns (bereits im Projekt)
- Derived caches statt "Filter/Sort im body":
  - `LibraryView` cachedDisplayedBooks + Debounce (siehe `Shelf Notes/LibraryView/LibraryView.swift`)
  - `StatisticsView` StatsCache/HeatmapCache (siehe `Shelf Notes/Stats/StatisticsView.swift`, `...+Caching.swift`)
  - `TagsIndexModel` (siehe `Shelf Notes/TagsIndexModel.swift`)
- Async/Task Hygiene:
  - `.task(id:)` für deterministisches Re-Run bei Inputänderung
  - explizite `Task`-References + cancel in VMs (z.B. `BookImportViewModel`)

---

## How to work on this project (Setup + Einstieg)

### Setup Steps (neue Devs)
1. Öffne `Shelf Notes.xcodeproj` in Xcode.
2. Signierung:
   - Stelle Team/Bundle ID korrekt ein (Bundle ID: `de.marcfechner.Shelf-Notes`).
3. iCloud/CloudKit:
   - Entitlements prüfen: `Shelf Notes/Shelf_Notes.entitlements`
   - iCloud container `iCloud.de.marcfechner.Shelf-Notes` muss im Developer Account existieren und für die App aktiviert sein.
4. Google Books API Key:
   - Setze `GOOGLE_BOOKS_API_KEY` per `.xcconfig` (siehe `Shelf Notes/config/*`).
   - **Empfohlen:** `secrets.xcconfig` nicht committen; Key lokal/CI injecten (siehe Quick Wins).
5. Run auf Gerät (für CloudKit realistischer als Simulator):
   - iCloud-Login aktiv
   - Internetverbindung
6. Debugging Sync:
   - Settings → "Sync-Diagnose" (`SyncDiagnosticsView`) öffnen.

### Wo anfangen (Orientierung)
- App Bootstrapping + Storage: `Shelf Notes/AppContainerHostView.swift`
- Root tabs + global settings: `Shelf Notes/RootView.swift`
- Data model: `Shelf Notes/Book.swift` + weitere `@Model` Dateien
- Hauptscreen Bibliothek: `Shelf Notes/LibraryView/LibraryView.swift`
- Import: `Shelf Notes/AddBook/AddBookView.swift` + `Shelf Notes/BookImport/*`

### Typische Workflows

#### Neues SwiftData Model hinzufügen
- Neues `@Model` in `Shelf Notes/<Feature>/<Entity>.swift`.
- `ModelContainerFactory.schema` in `Shelf Notes/AppContainerHostView.swift` erweitern.
- CloudKit-Regeln beachten:
  - Defaults für non-optional properties
  - keine Unique-Constraints
  - inverse Relationships sauber definieren
- Bei Relationship-Änderungen: ggf. One-time Repair/Migration planen (ähnlich `CollectionMembershipRepair`).

#### Neue Screen/Flow hinzufügen
- Wenn Tab: `Shelf Notes/RootView.swift` TabView erweitern.
- Wenn Subscreen: NavigationLink in passendem Feature-Screen, eigenes `NavigationStack` nur wenn screen standalone ist.
- Große Views splitten (Host + `+Sections` / `+Logic` / `+State`), siehe existierende Patterns.

#### Neue Remote API/Import hinzufügen
- Service in Root `Shelf Notes/` (oder Feature-Unterordner) anlegen.
- Konfiguration über Info.plist / xcconfig (nicht hardcoden).
- Debug-info sammeln (Pattern: `GoogleBooksDebugInfo` in `Shelf Notes/GoogleBooksClient.swift`).

---

## Quick Wins (max. 10, konkret)

1. **Secret aus Repo entfernen**: `Shelf Notes/config/secrets.xcconfig` enthält `GOOGLE_BOOKS_API_KEY`.  
   → in `.gitignore`, Key über lokale Datei/CI-Secret injecten, und ggf. Key rotieren.
2. **`.DS_Store` aus Source entfernen**: `Shelf Notes/config/.DS_Store` ist im Projekt; rauswerfen + `.gitignore`.
3. **Disk Cache begrenzen**: `ImageDiskCache` (`Shelf Notes/CachedAsyncImage.swift`) hat kein Eviction/Limit → kann unbounded wachsen.
4. **Stats Compute off-Main**: `StatisticsView.computeStatsCache/computeHeatmapCache` (`Shelf Notes/Stats/StatisticsView+Caching.swift`) laufen aktuell auf MainActor → für große Libraries potentiell UI hitching.
5. **ProgressHub hero computations cachen**: `ProgressHubView.finishedBooks(...)` + `last7DaysSessionStats()` (`Shelf Notes/ProgressHubView.swift`) laufen im Renderpfad und iterieren über `books`/`sessions`.
6. **Entitlements aps-environment prüfen**: `Shelf Notes/Shelf_Notes.entitlements` hat `aps-environment=development` → Release/Prod Setup verifizieren (**UNKNOWN**).
7. **Dead/duplicate file check**: `Shelf Notes/BookDetailComponents1.swift` wirkt wie ein "Altbestand" neben `Shelf Notes/BookDetail/BookDetailComponents.swift` → prüfen ob genutzt, ggf. löschen/umbenennen.
8. **Centralize UserDefaults keys**: mehrere `@AppStorage` keys sind als Strings verteilt (z.B. `RootView.swift`, `SettingsView.swift`) → kleine `enum` für Keys schafft Ordnung.
9. **Audit for save frequency**: Stellen wie `BookDetailView.onDisappear { _ = modelContext.saveWithDiagnostics() }` (`Shelf Notes/BookDetailView.swift`) können bei häufigen Navigationen viele Saves triggern → prüfen ob nötig.
10. **Add minimal tests**: aktuell sind Test Targets da, aber Coverage/Smoke Tests sind (scheinbar) gering → 2–3 smoke tests (Model saves, Tag normalization, GoogleBooks URL build).

---
