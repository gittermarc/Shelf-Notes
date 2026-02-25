# PROJECT_CONTEXT.md

## TL;DR

**Shelf Notes** ist eine iOS/iPadOS-App zum Verwalten einer persönlichen Bibliothek (Bücher + Status), inkl. **Lesesessions** (Timer + manuelles Logging), **iCloud-Sync über SwiftData+CloudKit**, **Tags/Listen**, **Jahresziele** und **Challenges**.  
Deployment Targets laut Xcode-Projekt: App **iOS 26.0**, Live-Activity-Extension **iOS 26.2** `Shelf Notes.xcodeproj/project.pbxproj`.

## Key Concepts (Domänenbegriffe)

- **Book**: Zentrales Objekt (Titel/Autor/Status/Tags/Notizen/Metadaten + Cover).
- **ReadingStatus**: `toRead`, `reading`, `finished` `Shelf Notes/Book.swift`.
- **ReadingSession**: Einzelne Lesesession zu einem Buch (Start/Ende/Dauer, optional Pages/Note) `Shelf Notes/ReadingSession.swift`.
- **Reading Timer**: Globale “laufende Session” (Start/Pause/Stop → Completion-Sheet) `Shelf Notes/BookDetail/Sessions/ReadingTimerManager/*`.
- **Collections (Listen)**: Many-to-many Buchlisten `Shelf Notes/BookCollection.swift`.
- **Tags**: String-basiert pro Buch (`Book.tags: [String]`) + Index/Caching für UI `Shelf Notes/TagsView/TagsIndexModel.swift`.
- **Goals**: Jahresziel `ReadingGoal(year, targetCount)` `Shelf Notes/ReadingGoal.swift`.
- **Challenges**: Periodische Challenges als Records, Progress wird aus Sessions/Books berechnet `Shelf Notes/Challenges/*`.
- **Cover Pipeline**:
  - Synced Thumbnail (JPEG) in `Book.userCoverData` (SwiftData externalStorage) `Shelf Notes/Book.swift`
  - Full-res User-Cover **lokal** in Application Support `Shelf Notes/CachedAsyncImage.swift` (`UserCoverStore`)
  - Backfill/Remote-Fetch/Decode `Shelf Notes/CoverThumbnailer/*`

## Architecture Map (Text)

- **UI (SwiftUI)**
  - Root Tabs + Navigation: `Shelf Notes/RootView.swift`
  - Feature Views in Feature-Ordnern (z.B. `LibraryView`, `BookDetail`, `Stats`, ...)
- **State / ViewModels / Caches**
  - ViewModels (z.B. Import): `Shelf Notes/BookImport/BookImportView/BookImportViewModel.swift`
  - Index-/Cache-Modelle für UI-Performance:
    - `TagsIndexModel` `Shelf Notes/TagsView/TagsIndexModel.swift`
    - `ProgressHubMetricsModel` `Shelf Notes/ProgressHub/ProgressHubMetricsModel.swift`
    - Stats-Caches `Shelf Notes/Stats/StatisticsView+Caching.swift`
- **Domain Models (SwiftData @Model)**
  - `Book`, `ReadingSession`, `ReadingGoal`, `BookCollection`, `ChallengeRecord`
- **Persistence / Sync**
  - SwiftData `ModelContainer` Bootstrap + Store-Separation + CloudKit on/off `Shelf Notes/AppContainerHostView.swift`
  - Diagnostics (CloudKit + Netzwerk + last-save signals) `Shelf Notes/SyncDiagnostics.swift`
- **Services / Utilities**
  - Cover decode/cache: `Shelf Notes/CoverImageLoader.swift`, `Shelf Notes/CachedAsyncImage.swift`, `Shelf Notes/CoverThumbnailer/*`
  - External APIs: Google Books `Shelf Notes/GoogleBooksClient.swift` (+ DTO/Mapper)
  - CSV Import/Export: `Shelf Notes/CSVImportExportView.swift`, `Shelf Notes/CSVCodec.swift`

Abhängigkeiten (vereinfacht):
- Views → (ViewModels/Caches) → (SwiftData Models) → SwiftData/CloudKit
- Views → Services (Cover/Import/CSV)
- Diagnostics sind optional/isoliert (Settings/Debug UI)

## Folder Map (Ordner → Zweck)

- `Shelf Notes/AddBook/` – “Buch hinzufügen” UI (Sheets, Cards, ViewModel)  
- `Shelf Notes/AppearanceSettings/` – UI + StorageKeys für Appearance/Theme/Density/Fonts  
- `Shelf Notes/BookDetail/` – Detail-Screen (split in Komponenten + Actions/Bindings/Persistence) + Sessions  
- `Shelf Notes/BookImport/` – Import/Search (Google Books), QueryBuilder, FilterEngine, ViewModel  
- `Shelf Notes/Challenges/` – Challenge Records + Engine (Snapshot + Compute off-main)  
- `Shelf Notes/CoverThumbnailer/` – Thumbnail-Generierung/Backfill/Remote fetch/Apply  
- `Shelf Notes/LibraryView/` – Bibliothek (List/Grid, Filter/Sort, Bulk, Cover Row)  
- `Shelf Notes/ProgressHub/` – “Fortschritt”-Hub (Stats/Goals/Timeline/Challenges) + Metrics Cache  
- `Shelf Notes/Shared/` – Shared Code (z.B. Live-Activity Attributes)  
- `Shelf Notes/Stats/` – StatisticsView Extensions: Sections, Data, Heatmap, Caching  
- `Shelf Notes/TagsView/` – Tags UI + Tag Index Model  
- `Shelf Notes/Timeline/` – Timeline UI + ViewModel  
- `Shelf Notes/config/` – `.xcconfig` (base + secrets)  

## Data Model Map (SwiftData Entities)

### Book `Shelf Notes/Book.swift`

Wichtige Felder (persistiert):
- `id: UUID`
- Core: `title`, `author`, `createdAt`, `statusRawValue`, `tags: [String]`, `notes`
- Read range: `readFrom: Date?`, `readTo: Date?`
- **Relationships**
  - `collections: [BookCollection]?` (many-to-many, optional wegen CloudKit)
  - `readingSessions: [ReadingSession]?` mit `@Relationship(deleteRule: .cascade, inverse: \ReadingSession.book)`
- Import metadata: `googleVolumeID`, `isbn13`, `thumbnailURL`, `publisher`, `publishedDate`, `pageCount`, `language`, `categories`, `bookDescription`, ...
- Cover:
  - `@Attribute(.externalStorage) userCoverData: Data?` (synced thumbnail)
  - `userCoverFileName: String?` (lokale Full-res Datei; Pfad via `UserCoverStore`)

### ReadingSession `Shelf Notes/ReadingSession.swift`

- `id: UUID`
- `book: Book?` (inverse via `Book.readingSessions`)
- `startedAt`, `endedAt`
- `durationSeconds` (cached)
- `pagesRead: Int?`, `note: String?`, `createdAt`

### BookCollection `Shelf Notes/BookCollection.swift`

- `id: UUID`
- `name`, `createdAt`, `updatedAt`
- `books: [Book]?` (many-to-many, optional)

### ReadingGoal `Shelf Notes/ReadingGoal.swift`

- `year: Int`
- `targetCount: Int`
- `updatedAt: Date`

### ChallengeRecord `Shelf Notes/Challenges/ChallengeModels.swift`

- `id: UUID`
- Period: `periodStart`, `periodEnd`
- Kind/Metric persisted als RawValue (`kindRawValue`, `metricRawValue`)
- Content: `title`, `detail`
- Target: `targetValue`
- Meta: `createdAt`, `completedAt`, `acknowledgedAt`, reroll fields

## Sync / Storage

### SwiftData + CloudKit Container Bootstrap `Shelf Notes/AppContainerHostView.swift`

- Bootstrapper versucht **CloudKit** zuerst; bei Fehler: Error-Screen statt Crash.
- **Storage Modes**:
  - `cloudKit`: `ModelConfiguration(... cloudKitDatabase: .automatic)`
  - `localOnly`: eigener Store ohne CloudKit (`cloudKitDatabase: .none`)
  - `inMemory`: Notfallmodus (`isStoredInMemoryOnly: true`)
- **Store-Separation** (wichtig): Cloud-Store und Local-only Store sind getrennte Dateien:
  - `ShelfNotesCloud.store`
  - `ShelfNotesLocal.store`
  in Application Support: `.../ShelfNotes/SwiftData/` `Shelf Notes/AppContainerHostView.swift`.

### Offline-Verhalten (bewusstes Divergenz-Risiko)

- Local-only Mode ist **explizit** (Banner + Alert) und speichert in eigenem lokalen Datenstand.
- Rückkehr zu CloudKit bedeutet: **nicht automatisch** Merge der Local-only Daten (designt so).

### Cover Storage

- Synced Thumbnail: `Book.userCoverData` (external storage) → Sync-Payload (CloudKit).
- Full-res User-Cover: lokal unter Application Support `user-covers/` `Shelf Notes/CachedAsyncImage.swift`.

### Background / Push

- `UIBackgroundModes = remote-notification` `Shelf Notes/Info.plist` (typisch für CloudKit Push/Sync).

## UI Map (Hauptscreens + Navigation)

### Root Tabs `Shelf Notes/RootView.swift`

TabView (persistierte Auswahl via `@SceneStorage("root_selected_tab_v1")`):
1. **Bibliothek** `LibraryView()`
2. **Fortschritt** `ProgressHubView()`
3. **Listen** `CollectionsView()`
4. **Tags** `TagsView()`
5. **Einstellungen** `SettingsView()`

### Bibliothek `Shelf Notes/LibraryView/*`

- `NavigationStack` in `LibraryView.swift`.
- Liste/Grid, Search, Filter (Status/Tag/Notizen), Sort (createdAt/readDate/rating/title/author) `LibraryView+FilteringSorting.swift`.
- Cover Rendering: `LibraryRowCoverView.swift` (SyncedThumbnail + decode/downscale + memory cache).

### Buch-Detail `Shelf Notes/BookDetail/*` + `Shelf Notes/BookDetailView.swift`

- Split: `BookDetailView+Actions.swift`, `+Bindings.swift`, `+Persistence.swift`, `+Toolbar.swift`, plus Komponenten in `BookDetail/BookDetailComponents/*`.
- Sessions:
  - Liste/Quick Log: `BookDetail/Sessions/*`
  - Timer: `ReadingTimerManager/*`
  - Live Activity Coordinator (Phase 1): `BookDetail/Sessions/LiveActivity/ReadingSessionLiveActivityCoordinator.swift`

### Fortschritt `Shelf Notes/ProgressHub/ProgressHubView.swift`

- Hub mit Quick Links zu:
  - `StatisticsView` (Charts optional)
  - `GoalsView`
  - `ReadingTimelineView`
  - `ChallengesView`
- Hero-Metriken via `ProgressHubMetricsModel` (task/id token) `Shelf Notes/ProgressHub/ProgressHubMetricsModel.swift`.

### Stats `Shelf Notes/StatisticsView.swift` + `Shelf Notes/Stats/*`

- `StatisticsView` hält UI State + Caches; Daten/Sections/Heatmap sind in Extensions.
- Caching invalidiert über Signature (order-independent Hash) `Shelf Notes/Stats/StatisticsView+Caching.swift`.

### Listen `Shelf Notes/CollectionsView.swift` + `CollectionDetailView.swift`

- `BookCollection` CRUD + Membership.
- Repair-Job: `CollectionMembershipRepair.swift` (einmalig pro Store-Scope).

### Tags `Shelf Notes/TagsView/TagsView.swift`

- Tags indexiert/cached via `TagsIndexModel` (Signature Token für `.task(id:)`) `Shelf Notes/TagsView/TagsIndexModel.swift`.

### Settings `Shelf Notes/SettingsView.swift`

- Appearance Settings UI (split in `AppearanceSettings/AppearanceSettingsView+*.swift`)
- Pro/Paywall (StoreKit) `ProManager.swift`, `ProPaywallView.swift`
- CSV Import/Export `CSVImportExportView.swift`

## Build & Configuration

### Targets `Shelf Notes.xcodeproj/project.pbxproj`

- App: `Shelf Notes` (bundle id `de.marcfechner.Shelf-Notes`)
- Widget/Live Activity: `ShelfNotesLiveActivityExtension` (bundle id `de.marcfechner.Shelf-Notes.ShelfNotesLiveActivity`)
- Tests: `Shelf NotesTests`, `Shelf NotesUITests`

### Entitlements

- iCloud Container: `iCloud.de.marcfechner.Shelf-Notes`
- iCloud Service: `CloudKit` `Shelf Notes/Shelf_Notes.entitlements`

### Config / Secrets

- `config/base.xcconfig` inkludiert `config/secrets.xcconfig`
- `secrets.xcconfig` enthält aktuell einen **klartext API-Key** (`GOOGLE_BOOKS_API_KEY`) (siehe Datei selbst).  
  **Security-Risiko**: siehe ARCHITECTURE_NOTES.md → Quick Wins / P0.

### Dependencies

- Keine SPM Packages im `.pbxproj` gefunden (nur Apple Frameworks wie SwiftData, StoreKit, Charts, VisionKit).

## Conventions / Patterns (Do/Don’t)

- **SwiftData + CloudKit**:
  - Keine `@Attribute(.unique)` auf Models (explizit kommentiert in mehreren Model-Files).
  - Relationships oft **optional**, um CloudKit/SwiftData Kompatibilität zu halten (`Book.collections`, `BookCollection.books`).
- **Performance**:
  - Keine teuren Aggregationen direkt im Renderpfad: Signatures + `.task(id:)` Tokens (`TagsView`, `Timeline`, `Stats`, `ProgressHub`).
  - Image decode/downscale off-main (z.B. `LibraryRowCoverView`).
- **Maintainability**:
  - Große Views werden per `extension` in Feature-Ordnern gesplittet (z.B. `BookDetail/*`, `LibraryView/*`, `Stats/*`).

## How to work on this project (Setup + Einstieg)

Checklist:
- [ ] Xcode öffnen: `Shelf Notes.xcodeproj`
- [ ] Signing/Team prüfen (Targets: App + Live Activity Extension)
- [ ] iCloud Capability + CloudKit Container (`Shelf Notes/Shelf_Notes.entitlements`) im Signing-Setup verifizieren
- [ ] `config/secrets.xcconfig` prüfen/ersetzen (API-Key) → **nicht** in public repos lassen
- [ ] Run auf Device testen (Barcode Scanner + Live Activities funktionieren nicht zuverlässig im Simulator)
- [ ] Optional: Sync Diagnostics Screen öffnen (`Settings` → SyncDiagnosticsView) um iCloud-Status zu prüfen

“Wo anfangen” für neue Devs:
- Einstieg: `Shelf Notes/Shelf_NotesApp.swift` → `AppContainerHostView.swift` → `RootView.swift`
- Datenmodell: `Book.swift`, `ReadingSession.swift`, `BookCollection.swift`, `ReadingGoal.swift`, `Challenges/ChallengeModels.swift`
- Performance Patterns: `Stats/StatisticsView+Caching.swift`, `TagsView/TagsIndexModel.swift`, `ProgressHub/ProgressHubMetricsModel.swift`

## Quick Wins (max 10, konkret)

1. **API-Key aus Repo entfernen**: `Shelf Notes/config/secrets.xcconfig` (siehe ARCHITECTURE_NOTES.md).
2. Add a minimal `README.md` (Setup + iCloud + Secrets) – aktuell **nicht vorhanden** (Repository-level; hier im ZIP nicht enthalten).
3. `LibraryView` Filter/Sort aus Renderpfad entkoppeln (Token + Hintergrundtask) `Shelf Notes/LibraryView/LibraryView+FilteringSorting.swift`.
4. Ein zentrales “Feature Flags / Diagnostics” Gate für Debug UI (SyncDiagnostics) hinzufügen (z.B. nur Debug builds).
5. Einheitliches Logging Interface (statt `print`/ad-hoc): startend bei `SyncDiagnostics` + Import.
6. CSV Import/Export: große Arbeit in Background Tasks (falls UI-Hänger bei großen Libraries auftreten) `Shelf Notes/CSVImportExportView.swift`.
7. Einheitliches Error-Handling für Google Books requests (Mapper/Client) `Shelf Notes/GoogleBooksClient.swift`.
8. Snapshot/Signature Helper zentralisieren (Stats/Tags/Timeline/ProgressHub nutzen ähnliche Muster).
9. Live Activity: Shared Attributes sind da – Flow für Start/Stop/Update über Coordinator in BookDetail sauber dokumentieren.
10. Tests: Smoke tests für `ReadingSessionLogging` rules (pure functions geeignet) `Shelf Notes/BookDetail/Sessions/ReadingSessionLogging.swift`.

## Open Questions (UNKNOWN)

- **CloudKit DB type**: `cloudKitDatabase: .automatic` ist gesetzt `Shelf Notes/AppContainerHostView.swift`, aber ob private/shared/public genutzt wird ist hier nicht explizit fest verdrahtet → **UNKNOWN** (Xcode Capabilities/Apple Verhalten).
- **Migration strategy**: Kein expliziter Migrationscode gefunden (SwiftData Auto-Migration?) → **UNKNOWN** (wie wird Schema-Change gehandhabt, wenn CloudKit Daten existieren?).
- **Release/Debug build differences**: xcconfig wird referenziert, aber Policies (Logging/Diagnostics) sind nicht überall getrennt → **UNKNOWN** (gewollt?).
