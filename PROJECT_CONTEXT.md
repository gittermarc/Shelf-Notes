# PROJECT_CONTEXT.md

## TL;DR
Shelf Notes ist eine iOS/iPadOS-App zur Verwaltung einer persönlichen Buchbibliothek mit Import (Google Books, Barcode, CSV), Lesesessions, Jahreszielen, Statistiken, Challenges, Tags, Listen/Collections und einer Live Activity für laufende Lesetimer. Der App-Target läuft laut `Shelf Notes.xcodeproj/project.pbxproj` auf iPhone und iPad (`TARGETED_DEVICE_FAMILY = "1,2"`) mit Mindestversion `IPHONEOS_DEPLOYMENT_TARGET = 26.0`. Persistenz läuft über SwiftData; der Standardpfad ist ein CloudKit-gestützter Store, mit explizitem local-only Fallback und einem In-Memory-Notmodus in `Shelf Notes/AppContainerHostView.swift`.

---

## Key Concepts / Domänenbegriffe
- **Book**: Zentrales Domain-Objekt. Enthält Bibliotheksstatus, Metadaten, Cover-Daten, Tags, Notizen, Listen-Zuordnung und Lesebewertungen. Siehe `Shelf Notes/BookModel/Book.swift`.
- **ReadingStatus**: Persistierter Lesestatus mit stabilen Codes (`toRead`, `reading`, `finished`) statt UI-Strings. Siehe `Shelf Notes/BookModel/Book+Status.swift` und `Shelf Notes/ReadingStatusMigrator.swift`.
- **ReadingSession**: Einzelne Leseeinheit mit Start/Ende, Dauer, optionalen gelesenen Seiten und Notiz. Siehe `Shelf Notes/ReadingSession.swift`.
- **ReadingGoal**: Jahresziel mit Zielanzahl pro Jahr. Siehe `Shelf Notes/ReadingGoal.swift`.
- **BookCollection**: Benutzerdefinierte Liste/Sammlung von Büchern. Viele-zu-viele zu `Book`. Siehe `Shelf Notes/BookCollection.swift`.
- **ChallengeRecord**: Persistierte Weekly-/Monthly-Challenge pro Zeitraum. Fortschritt wird nicht gespeichert, sondern aus Sessions und gelesenen Büchern berechnet. Siehe `Shelf Notes/Challenges/ChallengeModels.swift`.
- **Tags Index**: App-weiter Cache für Tag-Häufigkeiten, damit der Tags-Tab nicht selbst alle Bücher aggregieren muss. Siehe `Shelf Notes/TagsView/TagsIndexStore.swift`.
- **Derived State**: Mehrere Screens vermeiden direkte Aggregation im `body` und bauen stattdessen Snapshots/Caches/Coordinatoren, z. B. Library, Stats, Challenges, Progress Hub. Siehe u. a. `Shelf Notes/LibraryView/LibraryDerivedStateBuilder.swift`, `Shelf Notes/Stats/StatisticsComputePipeline.swift`, `Shelf Notes/Analytics/ReadingAnalyticsIndexBuilder.swift`.
- **Synced Thumbnail vs. Full-Res Cover**: Kleinere, synchronisierbare Cover-Vorschau liegt in SwiftData (`Book.userCoverData`), ein lokal ausgewähltes Vollbild-Cover bleibt als Datei lokal. Siehe `Shelf Notes/BookModel/Book.swift`, `Shelf Notes/CoverThumbnailer/*`, `Shelf Notes/CachedAsyncImage.swift`.
- **StorageMode**: App kann im CloudKit-Modus, local-only Modus oder In-Memory-Modus starten. Siehe `Shelf Notes/AppContainerHostView.swift`.

---

## Architecture Map

### Schichten / Module
- **App Bootstrap / Runtime Shell**
  - `Shelf Notes/Shelf_NotesApp.swift`
  - `Shelf Notes/AppContainerHostView.swift`
  - Verantwortlich für App-Start, Container-Bootstrap, CloudKit/local-only Wahl, Recovery-UI.
- **Root Navigation / Global State**
  - `Shelf Notes/RootView.swift`
  - Hält `TabView`, globale Appearance-Settings, `ProManager`, `ReadingTimerManager`, `TagsIndexStore`, First-Run-Flow, globale Hintergrund-Tasks.
- **Domain Models / Persistence Schema**
  - `Shelf Notes/BookModel/*`
  - `Shelf Notes/ReadingSession.swift`
  - `Shelf Notes/ReadingGoal.swift`
  - `Shelf Notes/BookCollection.swift`
  - `Shelf Notes/Challenges/ChallengeModels.swift`
- **Feature UI**
  - Bibliothek: `Shelf Notes/LibraryView/*`
  - Detail: `Shelf Notes/BookDetail/*`
  - Import/Add: `Shelf Notes/AddBook/*`, `Shelf Notes/BookImport/*`, `Shelf Notes/CSVImportExport/*`
  - Fortschritt/Analytics: `Shelf Notes/ProgressHub/*`, `Shelf Notes/Goals/*`, `Shelf Notes/Stats/*`, `Shelf Notes/Timeline/*`, `Shelf Notes/Challenges/*`
  - Organisation: `Shelf Notes/CollectionsView.swift`, `Shelf Notes/CollectionDetailView.swift`, `Shelf Notes/TagsView/*`
  - Einstellungen: `Shelf Notes/Settings/*`, `Shelf Notes/SyncDiagnosticsView.swift`
- **Derived State / Analytics / Indexing**
  - `Shelf Notes/Analytics/*`
  - `Shelf Notes/LibraryView/LibraryDerivedState*.swift`
  - `Shelf Notes/Stats/*`
  - `Shelf Notes/TagsView/TagsIndex*.swift`
  - `Shelf Notes/ProgressHub/ProgressHubMetricsModel.swift`
- **Integrationen / Services**
  - Google Books: `Shelf Notes/GoogleBooksClient.swift`, `Shelf Notes/GoogleBooksDTO.swift`, `Shelf Notes/GoogleVolumeBookMapper.swift`
  - Cover: `Shelf Notes/CachedAsyncImage.swift`, `Shelf Notes/CoverThumbnailer/*`, `Shelf Notes/CoverImageLoader.swift`
  - Sync-Diagnose: `Shelf Notes/SyncDiagnostics.swift`, `Shelf Notes/ModelContext+Diagnostics.swift`
  - Monetarisierung: `Shelf Notes/ProManager.swift`, `Shelf Notes/ProPaywallView.swift`
  - Live Activity / Timer: `Shelf Notes/BookDetail/Sessions/ReadingTimerManager/*`, `Shelf Notes/BookDetail/Sessions/LiveActivity/*`, `Shelf Notes/Shared/LiveActivity/*`, `ShelfNotesLiveActivity/*`

### Abhängigkeiten in Textform
- SwiftUI Views lesen und mutieren SwiftData-Modelle häufig **direkt** über `@Query`, `@Bindable` und `@Environment(\.modelContext)`.
- Für teurere Lesepfade werden teils Value-Snapshots/Builder eingeschoben, damit schwere Aggregation nicht direkt im Renderpfad hängt.
- Persistenz ist **nicht** über Repositories/Stores zentralisiert; stattdessen speichern viele Views/ViewModels direkt per `modelContext.saveWithDiagnostics()` aus `Shelf Notes/ModelContext+Diagnostics.swift`.
- CloudKit-Sync hängt an SwiftData-Konfiguration (`cloudKitDatabase: .automatic`) in `Shelf Notes/AppContainerHostView.swift`.
- Live Activity und Timer-Status teilen Daten über App Group UserDefaults/Dateien (`Shelf Notes/Shared/LiveActivity/LiveActivitySharedStore.swift`).

---

## Folder Map
- `Shelf Notes/` → Haupt-App-Target
- `Shelf Notes/AddBook/` → Add-Book Shell + Auswahlkarten + ViewModel
- `Shelf Notes/Analytics/` → Pure Analytics/Derived-State Builder für Fortschrittsmetriken
- `Shelf Notes/BookDetail/` → Detailscreen, Karten, Bindings, Actions, Sessions, Notes
- `Shelf Notes/BookImport/` → Google-Books-Suche, Filter, Paging, Quick Add, Query Builder
- `Shelf Notes/BookModel/` → `Book`-Schema plus fachliche Splits (Status, Ratings, Cover URLs, Progress, Collections, Importing)
- `Shelf Notes/CSVImportExport/` → CSV Codec, Import-Executor, Export-Builder, UI/ViewModel
- `Shelf Notes/Challenges/` → Challenge-Modelle, Snapshotting, Compute, UI
- `Shelf Notes/CoverThumbnailer/` → Remote Fetch, Thumbnail-Erzeugung, Apply/Backfill
- `Shelf Notes/Goals/` → Jahresziele und Zielmetriken
- `Shelf Notes/LibraryView/` → Bibliothek, Grid/List, Header, Filter, Bulk Actions, Derived State
- `Shelf Notes/ProgressHub/` → Aggregierter Fortschritts-Hub
- `Shelf Notes/Settings/` → Settings-Root, Appearance, Library-Appearance
- `Shelf Notes/Shared/LiveActivity/` → App- und Extension-geteilte Models/Store
- `Shelf Notes/Stats/` → Statistik-Snapshots, Heatmap, Pipeline, UI-Sektionen
- `Shelf Notes/TagsView/` → Tag-Index, Store, Tag-Tab
- `Shelf Notes/Timeline/` → Lese-Zeitleiste + ViewModel + Mini-Map
- `Shelf Notes/config/` → `.xcconfig`-Konfiguration
- `Shelf NotesTests/` → Unit Tests für Modelle, Derived State, Import/Export, Stats, Goals, Tags
- `Shelf NotesUITests/` → sehr dünne UI-Test-Basis
- `ShelfNotesLiveActivity/` → Widget/Live Activity Extension

---

## Data Model Map

### `Book` — `Shelf Notes/BookModel/Book.swift`
Wichtige Felder:
- Identität: `id`
- Core: `title`, `author`, `createdAt`, `statusRawValue`, `tags`, `notes`
- Zeiträume: `readFrom`, `readTo`
- Beziehungen:
  - `collections: [BookCollection]?`
  - `readingSessions: [ReadingSession]?` mit `@Relationship(deleteRule: .cascade, inverse: \ReadingSession.book)`
- Import/Remote: `googleVolumeID`, `isbn13`, `thumbnailURL`, `coverURLCandidates`, `previewLink`, `infoLink`, `canonicalVolumeLink`
- Cover: `userCoverData` (`@Attribute(.externalStorage)`), `userCoverFileName`
- Metadaten: `publisher`, `publishedDate`, `pageCount`, `language`, `categories`, `bookDescription`, `subtitle`, `averageRating`, `ratingsCount`, `mainCategory`
- Access/Sale: `viewability`, `isPublicDomain`, `isEmbeddable`, `isEpubAvailable`, `isPdfAvailable`, `saleability`, `isEbook`
- User-Rating: sechs Einzelratings (`userRatingPlot`, `userRatingCharacters`, `userRatingWritingStyle`, `userRatingAtmosphere`, `userRatingGenreFit`, `userRatingPresentation`)

### `ReadingSession` — `Shelf Notes/ReadingSession.swift`
- `book: Book?`
- `startedAt`, `endedAt`, `durationSeconds`, `pagesRead`, `note`, `createdAt`
- Hilfen: `duration`, `pagesReadNormalized`, `recomputeDuration()`

### `ReadingGoal` — `Shelf Notes/ReadingGoal.swift`
- `year`, `targetCount`, `updatedAt`

### `BookCollection` — `Shelf Notes/BookCollection.swift`
- `id`, `name`, `createdAt`, `updatedAt`
- `books: [Book]?`
- Helper: `booksSafe`, `contains(_:)`, `addBook(_:)`, `removeBook(_:)`

### `ChallengeRecord` — `Shelf Notes/Challenges/ChallengeModels.swift`
- Zeitraum: `periodStart`, `periodEnd`
- Typ: `kindRawValue`, `metricRawValue`
- Content: `title`, `detail`, `targetValue`
- Status: `createdAt`, `completedAt`, `acknowledgedAt`, `rerollsUsed`, `rerolledAt`
- Computed API: `kind`, `metric`, `isActive`, `isCompleted`, `isClaimed`, `canReroll`, `periodLabel`

### Relationship-Notizen
- CloudKit-Kompatibilität prägt das Schema stark:
  - kein `@Attribute(.unique)`
  - viele Beziehungen optional
  - inverse Beziehung explizit bei `Book.readingSessions`
- Es gibt eine One-Time-Reparatur für `Book <-> BookCollection`, weil ältere Builds anscheinend beide Seiten manuell und nicht immer symmetrisch gepflegt haben: `Shelf Notes/CollectionMembershipRepair.swift`.

---

## Sync / Storage

### Persistenztyp
- SwiftData ist die primäre Persistenzschicht.
- Standardmodus ist CloudKit-backed SwiftData mit `cloudKitDatabase: .automatic` in `Shelf Notes/AppContainerHostView.swift`.

### Container-Strategie
- `ModelContainerFactory.schema` in `Shelf Notes/AppContainerHostView.swift` registriert:
  - `Book`
  - `ReadingSession`
  - `ReadingGoal`
  - `BookCollection`
  - `ChallengeRecord`
- Getrennte Stores:
  - CloudKit: `ShelfNotesCloud.store`
  - local-only: `ShelfNotesLocal.store`
  - In-Memory für Notfallbetrieb
- Speicherort: `Application Support/ShelfNotes/SwiftData/`

### Sync-Verhalten
- SwiftData/CloudKit übernimmt Background-Sync implizit.
- Sichtbare Diagnose ist bewusst minimal gehalten, weil SwiftData keine tiefen CloudKit-Fortschrittsdaten liefert. Siehe `Shelf Notes/SyncDiagnostics.swift`.
- `Shelf Notes/SyncDiagnostics.swift` überwacht:
  - CloudKit Account-Status
  - User Record ID (gekürzt)
  - Netzwerkstatus via `NWPathMonitor`
  - letzte lokale Saves, Save-Quelle, Save-Fehler
  - Offline-Save-Zähler
- `Shelf Notes/ModelContext+Diagnostics.swift` hängt sich an Saves und schreibt Breadcrumbs in die Diagnose.

### Migration / Repair
- `Shelf Notes/ReadingStatusMigrator.swift` migriert alte lokalisierte Statusstrings auf stabile Codes.
- `Shelf Notes/CollectionMembershipRepair.swift` repariert und dedupliziert Book/Collection-Mitgliedschaften einmalig pro Store-Scope.
- Eine versionierte, generelle Migrationsstrategie über diese punktuellen Helfer hinaus ist **UNKNOWN**.

### Offline-Verhalten
- App kann bei Container-Startfehlern explizit local-only oder in-memory starten (`Shelf Notes/AppContainerHostView.swift`).
- local-only ist **bewusst ein separater Datenstand** und nicht nur „temporär offline“. Das wird im UI per Banner/Alert kommuniziert.
- Offline-Saves werden gezählt; spätere Cloud-Merge-Strategie für local-only → cloud ist **UNKNOWN**.

### Weitere Speicherorte / Caches
- Cover-Diskcache: `Caches/cover-cache` über `Shelf Notes/CachedAsyncImage.swift`
- Full-Res User Cover lokal: `UserCoverStore` in `Shelf Notes/CachedAsyncImage.swift`
- Synced Thumbnail im SwiftData-Modell: `Book.userCoverData`
- App Group Shared Store für Live Activity: `Shelf Notes/Shared/LiveActivity/LiveActivitySharedStore.swift`
- Search History in `UserDefaults`: `Shelf Notes/SearchHistoryStore.swift`
- Appearance-/UI-Preferences über `@AppStorage` und `@SceneStorage`

---

## UI Map

### Root Navigation
- Einstieg: `Shelf Notes/Shelf_NotesApp.swift` → `AppContainerHostView()`
- Hauptnavigation: `Shelf Notes/RootView.swift`
- Tabs:
  - Bibliothek → `LibraryView()`
  - Fortschritt → `ProgressHubView()`
  - Listen → `CollectionsView()`
  - Tags → `TagsView()`
  - Einstellungen → `SettingsView()`

### Hauptscreens und Flows
- **Bibliothek** — `Shelf Notes/LibraryView/LibraryView.swift`
  - `NavigationStack`
  - Suche, Filter, Sortierung, Grid/List, Alpha-Index, Bulk Actions
  - Add-Book-Sheet
  - Navigation zu `BookDetailView`
- **Buch hinzufügen** — `Shelf Notes/AddBook/AddBookView.swift`
  - Startet Teilflüsse:
    - Google Books Import → `BookImportView`
    - Barcode Scanner → `BarcodeScannerSheet`
    - Inspiration Seeds → `InspirationSeedPickerView`
    - Manuell → `ManualBookAddSheet`
- **Buchdetail** — `Shelf Notes/BookDetail/BookDetailView.swift`
  - Cards für Status, Sessions, Lesedaten, Rating, Notizen, Tags, Collections, More Info
  - Sheets für Notes, Collections Picker, Rating Editor, Session List, neue Collection, Paywall, Share Sheet, Online Cover Picker, Photo Picker
- **Fortschritt** — `Shelf Notes/ProgressHub/ProgressHubView.swift`
  - Quick Links zu Statistiken, Ziele, Zeitleiste
  - Challenges Summary Card mit Navigation zu `ChallengesView`
- **Statistiken** — `Shelf Notes/Stats/StatisticsView.swift`
  - Sections für Header, Controls, Overview, Charts, Heatmap, Top Lists, Nerd Corner
- **Ziele** — `Shelf Notes/Goals/GoalsView.swift`
  - Jahresziel, Fortschritt, Slot-Grid mit Navigation zu Buchdetails
- **Zeitleiste** — `Shelf Notes/Timeline/ReadingTimelineView.swift`
  - Horizontaler Zeitstrahl, Year Mini-Map, Jump-Menü
- **Challenges** — `Shelf Notes/Challenges/ChallengesView.swift`
  - aktive und vergangene Challenges, Claim/Reroll
- **Listen** — `Shelf Notes/CollectionsView.swift`, `Shelf Notes/CollectionDetailView.swift`
  - Create/Delete, Pro-Gating, Listen-Detail mit Büchern
- **Tags** — `Shelf Notes/TagsView/TagsView.swift`
  - Tag-Counts, Tap führt zu gefilterter Bibliothek
- **Einstellungen** — `Shelf Notes/Settings/SettingsView.swift`
  - Appearance, Suchsprache, CSV, Sync-Diagnose, Session Auto-Stop, Cover Cache, Pro, Version

---

## Build & Configuration
- Xcode-Projekt: `Shelf Notes.xcodeproj/project.pbxproj`
- Targets:
  - `Shelf Notes`
  - `Shelf NotesTests`
  - `Shelf NotesUITests`
  - `ShelfNotesLiveActivityExtension`
- Mindest-iOS: `26.0` für App, Tests und Live Activity Target laut `project.pbxproj`
- Device Family: iPhone + iPad (`1,2`)
- App Bundle ID: `de.marcfechner.Shelf-Notes`
- Extension Bundle ID: `de.marcfechner.Shelf-Notes.ShelfNotesLiveActivity`
- Base config: `Shelf Notes/config/base.xcconfig`
- Secret include: `#include "secrets.xcconfig"`
- Info/Entitlements:
  - `Shelf Notes/Info.plist`
  - `Shelf Notes/Shelf_Notes.entitlements`
  - `ShelfNotesLiveActivityExtension.entitlements`
- Capabilities aus Entitlements/Info:
  - iCloud/CloudKit
  - App Group
  - Live Activities
  - `UIBackgroundModes = remote-notification`
- Swift Package Manager:
  - Im `project.pbxproj` sind keine Package-Produktabhängigkeiten erkennbar.
- Secrets-Handling:
  - `.gitignore` in `Shelf Notes/.gitignore` versucht `config/secrets.xcconfig` auszuschließen.
  - Im gelieferten ZIP ist `Shelf Notes/config/secrets.xcconfig` dennoch vorhanden und enthält einen konkreten Google Books API Key. Das ist ein Sicherheits-/Prozessproblem.

---

## Conventions
- Feature-orientierte Ordnerstruktur mit zusätzlicher fachlicher Aufspaltung großer Dateien über Extensions.
- Viele Kommentare dokumentieren CloudKit-/SwiftData-Zwänge direkt am Code.
- `@Query` wird breit genutzt; keine zentrale Repository-Schicht.
- Persistenz wird häufig direkt aus UI/ViewModel getriggert mit `modelContext.saveWithDiagnostics()`.
- Für teurere Aggregationen wird partiell auf Snapshot-/Builder-/Coordinator-Pattern gesetzt.
- Globale UI-/App-Zustände hängen an `@StateObject`, `@EnvironmentObject`, `@AppStorage`, `@SceneStorage`.
- Tests sind für Kernlogik relativ gut vertreten, vor allem bei:
  - Book helpers
  - CSV Import/Export
  - Library Derived State
  - Progress Hub Metrics
  - Statistics Pipeline
  - Tags Index
- Do:
  - neue schwere Aggregationen als pure Value-Builder auslagern
  - bei SwiftData/CloudKit optionale Beziehungen und migrationsfreundliche Defaults respektieren
  - bestehende `saveWithDiagnostics()`-Schiene weiterverwenden, solange es keinen zentralen Write-Service gibt
- Don’t:
  - keine neuen direkten O(n)-Aggregationen in SwiftUI-`body` ohne Cache/Token
  - keine `@Attribute(.unique)`-Experimente ohne CloudKit-Validierung
  - nicht beide Seiten manueller Beziehungen an zu vielen Stellen getrennt pflegen

---

## How to work on this project

### Setup Steps
1. Xcode-Projekt öffnen: `Shelf Notes.xcodeproj`
2. Prüfen, ob Signing/Entitlements für iCloud/CloudKit/App Group lokal korrekt konfiguriert sind.
3. Sicherstellen, dass `config/secrets.xcconfig` lokal vorhanden ist oder bewusst ersetzt wurde.
4. App im Simulator oder auf Gerät starten; bei CloudKit-Problemen existieren Fallback-Pfade über `AppContainerHostView`.
5. Relevante Test-Suite laufen lassen, mindestens `Shelf NotesTests`.

### Wo neue Entwickler anfangen sollten
- **App-Start und Storage** zuerst lesen:
  - `Shelf Notes/Shelf_NotesApp.swift`
  - `Shelf Notes/AppContainerHostView.swift`
  - `Shelf Notes/RootView.swift`
- **Schema / Domain** danach:
  - `Shelf Notes/BookModel/Book.swift`
  - `Shelf Notes/ReadingSession.swift`
  - `Shelf Notes/ReadingGoal.swift`
  - `Shelf Notes/BookCollection.swift`
  - `Shelf Notes/Challenges/ChallengeModels.swift`
- **Dann den betroffenen Feature-Ordner** lesen.
- Bei Performance-/Wartungsarbeit zusätzlich ansehen:
  - `Shelf Notes/Stats/*`
  - `Shelf Notes/LibraryView/*`
  - `Shelf Notes/ProgressHub/ProgressHubMetricsModel.swift`
  - `Shelf Notes/Challenges/ChallengeEngine+Snapshot.swift`

### Typischer Workflow für ein neues Feature
1. Prüfen, ob das Feature ein neues persistiertes Feld/Modell braucht.
2. Falls ja, CloudKit/SwiftData-Einschränkungen mitdenken.
3. UI möglichst feature-lokal anlegen, aber Aggregationen nicht direkt im `body` verstecken.
4. Für schwere Auswertung einen Builder/Snapshot ergänzen statt View-Logik aufzublasen.
5. Save-Pfade bewusst setzen; vermeiden, pro Keystroke oder pro kleinster UI-Änderung unkritisch zu speichern.
6. Tests ergänzen, bevorzugt für pure Logik zuerst.

---

## Quick Wins
1. **API-Key aus dem gelieferten Secret-File entfernen** und nur Template/CI-Injektion verwenden (`Shelf Notes/config/secrets.xcconfig`).
2. **Write-Throttling für Text/Stepper-Saves einführen** in `Shelf Notes/CollectionDetailView.swift` und `Shelf Notes/Goals/GoalsView.swift`.
3. **`ContentView.swift` aufräumen oder klar als Preview-Wrapper markieren**; aktuell ist der App-Einstieg `AppContainerHostView`, nicht `ContentView`.
4. **`CachedAsyncImage.swift` fachlich splitten** in Memory Cache, Disk Cache, User Cover Store, View Layer.
5. **`BookDetailView+Bindings.swift` splitten** nach Status/Rating/Collections/Notes.
6. **Stats-Signaturkosten weiter drücken**: `booksSignature(_:)` in `Shelf Notes/Stats/StatisticsView+Caching.swift` ist bewusst „leicht“, aber immer noch O(n) pro Update.
7. **CSV-Import batched speichern** statt pro importiertem Buch sofort zu speichern (`Shelf Notes/CSVImportExport/CSVImportExecutor.swift`).
8. **Challenge Summary Refresh robuster triggern**: `.task(id: challenges.count)` in `Shelf Notes/Challenges/ChallengesSummaryCard.swift` ignoriert Inhaltsänderungen bei gleicher Count.
9. **Template-/Restdateien der Live-Activity-Extension prüfen und ggf. löschen** (`ShelfNotesLiveActivity/ShelfNotesLiveActivity.swift`, `ShelfNotesLiveActivity/ShelfNotesLiveActivityControl.swift`, `ShelfNotesLiveActivity/AppIntent.swift`).
10. **`remote-notification` Background Mode validieren oder entfernen**, falls nicht genutzt (`Shelf Notes/Info.plist`).

---

## UNKNOWN / Open Questions (kurz)
- Wie sollen echte Schema-Migrationen jenseits der aktuellen One-Off-Migratoren langfristig gehandhabt werden? **UNKNOWN**
- Gibt es einen beabsichtigten Merge-Pfad vom local-only Store zurück in den CloudKit-Store? **UNKNOWN**
- Ist `UIBackgroundModes = remote-notification` fachlich noch notwendig? Im gescannten Code wurde kein passender Empfangspfad gefunden. **UNKNOWN**
- Sind die zusätzlichen Widget-/Control-Template-Dateien in `ShelfNotesLiveActivity/` bewusst für spätere Arbeit vorhanden oder nur Altlast? **UNKNOWN**
- Ist `ContentView.swift` absichtlich als Legacy-/Preview-Wrapper behalten worden? **UNKNOWN**
