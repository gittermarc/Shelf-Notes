# PROJECT_CONTEXT.md

Stand: Analyse des Projekt-ZIPs `sn_context.zip` vom 2026-06-06. Der aktuelle Code ist die Quelle der Wahrheit. Es wurde keine Build- oder Testausführung durchgeführt.

## TL;DR

Shelf Notes ist eine SwiftUI-App für iOS/iPadOS zur Verwaltung einer persönlichen Buchbibliothek mit Lesestatus, Lesesessions, Zielen, Challenges, Statistiken, Tags, Listen/Sammlungen, CSV-Import/-Export, Google-Books-Import, Cover-Caching und Live-Activity-Unterstützung. Persistenz läuft über SwiftData; die primäre Store-Konfiguration nutzt CloudKit über `ModelConfiguration(cloudKitDatabase: .automatic)`. Das Deployment Target ist laut `Shelf Notes.xcodeproj/project.pbxproj` iOS 26.0.

## Key Concepts / Domänenbegriffe

- `Book`: Zentrale Entität für Bücher, Metadaten, Lesestatus, Tags, Notizen, Cover-Daten, Bewertungen und Beziehungen zu Sessions/Sammlungen. Pfad: `Shelf Notes/BookModel/Book.swift`.
- `ReadingStatus`: Fachlicher Lesestatus mit stabilen Raw Values `toRead`, `reading`, `finished`. Legacy-Werte auf Deutsch werden in `Shelf Notes/BookModel/Book+Status.swift` gemappt.
- `ReadingSession`: Einzelne Leseeinheit mit Start, Ende, Dauer, Seiten und optionaler Notiz. Pfad: `Shelf Notes/ReadingSession.swift`.
- `ReadingGoal`: Jahresziel für gelesene Bücher. Pfad: `Shelf Notes/ReadingGoal.swift`.
- `BookCollection`: Nutzerdefinierte Liste/Sammlung von Büchern. Pfad: `Shelf Notes/BookCollection.swift`.
- `ChallengeRecord`: Persistierte Challenge für Wochen-/Monatszeiträume mit Metrik, Zielwert, Completion und Reroll-Status. Pfad: `Shelf Notes/Challenges/ChallengeModels.swift`.
- Tags: Freie String-Tags am Buch, normalisiert über `TagNormalization` und verarbeitet in `Shelf Notes/TagsView/*`.
- Synced Thumbnail: Kleines Cover-Bild in SwiftData, gespeichert als `Book.userCoverData` mit `@Attribute(.externalStorage)`. Pfad: `Shelf Notes/BookModel/Book.swift`.
- Full-Res User Cover: Lokale Originaldatei im App-Group-Container; nur der Dateiname wird am Buch gespeichert. Pfad: `Shelf Notes/ImageCaching/UserCoverStore.swift`.
- `StorageMode`: Startmodus für CloudKit, lokalen Store oder In-Memory-Store. Pfad: `Shelf Notes/Persistence/StorageMode.swift`.
- Local-only Mode: Separater lokaler SwiftData-Store ohne CloudKit, sichtbar über Banner in `Shelf Notes/AppContainerHostView.swift`.
- `saveWithDiagnostics`: Wrapper um `ModelContext.save()` mit lokalen Diagnose-Breadcrumbs. Pfad: `Shelf Notes/ModelContext+Diagnostics.swift`.
- Pro/StoreKit: `ProManager` und `Shelf Notes/unlimited_collections.storekit` steuern Pro-Funktionalität, unter anderem unbegrenzte Sammlungen.

## Architecture Map

### Start und Container

- `Shelf Notes/Shelf_NotesApp.swift`
  - `@main` App-Einstieg.
  - Rendert `AppContainerHostView()`.
- `Shelf Notes/AppContainerHostView.swift`
  - Hält `AppBootstrapper` als `@StateObject`.
  - Zeigt Loading, Ready oder Failure UI.
  - Injiziert `ModelContainer` über `.modelContainer(container)` in `RootView()`.
  - Startet nach Container-Ready Reparatur- und Challenge-Vorbereitung.
- `Shelf Notes/AppBootstrap/AppBootstrapper.swift`
  - Baut den SwiftData-Container.
  - Versucht zuerst `.cloudKit`.
  - Bietet Retry, Local-only und In-Memory-Fallback.
- `Shelf Notes/Persistence/ModelContainerFactory.swift`
  - Definiert das SwiftData-Schema und die Store-Konfigurationen.

### UI-Schicht

- `RootView` ist der zentrale Tab-Host. Pfad: `Shelf Notes/RootView.swift`.
- Feature-Screens leben überwiegend in eigenen Ordnern:
  - Bibliothek: `Shelf Notes/LibraryView/*`
  - Fortschritt/Ziele/Statistiken/Timeline/Challenges: `Shelf Notes/ProgressHub/*`, `Shelf Notes/Goals/*`, `Shelf Notes/Stats/*`, `Shelf Notes/Timeline/*`, `Shelf Notes/Challenges/*`
  - Listen/Sammlungen: `Shelf Notes/Collections/*`
  - Tags: `Shelf Notes/TagsView/*`
  - Buchdetails: `Shelf Notes/BookDetail/*`
  - Import: `Shelf Notes/AddBook/*`, `Shelf Notes/BookImport/*`, `Shelf Notes/CSVImportExport/*`
  - Einstellungen: `Shelf Notes/Settings/*`

### Persistenz und Sync

- SwiftData-Modelle liegen teils im Root und teils unter `BookModel`/`Challenges`.
- CloudKit wird über SwiftData `.automatic` aktiviert. Pfad: `Shelf Notes/Persistence/ModelContainerFactory.swift`.
- CloudKit-Voraussetzungen werden im Datenmodell sichtbar berücksichtigt:
  - keine `@Attribute(.unique)` auf IDs,
  - optionale Beziehungen,
  - Default-Werte für nicht-optionale Felder.
- Diagnostik liegt in `Shelf Notes/SyncDiagnostics.swift`, `Shelf Notes/SyncDiagnosticsView.swift` und `Shelf Notes/ModelContext+Diagnostics.swift`.

### Derived-State- und Builder-Schicht

- Viele schwere Berechnungen sind in testbare Builder ausgelagert.
- Beispiele:
  - Library: `LibraryBooksIndex`, `LibraryDerivedStateBuilder`, `LibraryDisplayStore`
  - Stats: `StatisticsSourceStore`, `StatisticsComputePipeline`, `StatisticsSnapshotBuilder`
  - Tags: `TagsIndexBuilder`, `TagsDomainIndex`, `TagSuggestionEngine`, `TagHygieneBuilder`
  - Challenges: `ChallengeEngine`, `ChallengeEngine+Compute`, `ChallengeEngine+Snapshot`
  - Collections: `CollectionsDashboardBuilder`, `CollectionsSmartActionBuilder`

### Cover-/Image-Pipeline

- Remote-/Disk-/Memory-Loading: `Shelf Notes/CoverImageLoader.swift`, `Shelf Notes/CachedAsyncImage.swift`, `Shelf Notes/ImageCaching/*`.
- Disk Cache: `Shelf Notes/ImageCaching/ImageDiskCache.swift` mit Default-Limit 120 MB.
- Request-Deduping: `Shelf Notes/ImageCaching/CoverImageRequestDeduper.swift`.
- Temporärer Failure Cache: `Shelf Notes/ImageCaching/RemoteCoverFailureCache.swift`.
- Thumbnail-Erzeugung und Backfill: `Shelf Notes/CoverThumbnailer/CoverThumbnailer.swift`.
- Scroll-schonende Anzeige: `Shelf Notes/ImageViews/LibraryRowCoverView.swift` und `Shelf Notes/ImageViews/SyncedThumbnailImage.swift`.

### Live Activity

- Shared Live-Activity-Modelle: `Shelf Notes/Shared/LiveActivity/*`.
- App Extension: `ShelfNotesLiveActivity/*`.
- App-Group-Entitlement ist in App und Extension vorhanden.

## Folder Map

- `Shelf Notes/BookModel`: Book-Modell und fachliche Extensions für Status, Ratings, Fortschritt, Collections, Import und Cover-URLs.
- `Shelf Notes/Persistence`: SwiftData-Container-Fabrik und Storage-Mode-Konzept.
- `Shelf Notes/AppBootstrap`: Startlogik für Container-Aufbau und Fallbacks.
- `Shelf Notes/AppLifecycle`: Startup-Maintenance, zum Beispiel Cover-Backfill und einmalige Jobs.
- `Shelf Notes/LibraryView`: Bibliotheksansicht, Filter, Sortierung, Grid/List, Header, Derived State.
- `Shelf Notes/BookDetail`: Detailansicht, Karten, Bindings, Sessions, Notizen und Timer-Integration.
- `Shelf Notes/BookDetail/Sessions`: Session-UI, Session-Formulare, Timer-Manager, Live-Activity-Brücke.
- `Shelf Notes/AddBook`: Klassischer Buch-Hinzufügen-Flow mit Google-Books-Suche und Formularlogik.
- `Shelf Notes/BookImport`: Moderner Import-Flow mit Query Builder, Filter Engine, Result Views und Seed Queries.
- `Shelf Notes/CSVImportExport`: CSV-Import/-Export und Import-Ausführung.
- `Shelf Notes/ImageCaching`: Memory-/Disk-Caches, Cover-Deduper, Failure Cache und User-Cover-Store.
- `Shelf Notes/ImageViews`: Wiederverwendbare Cover-/Thumbnail-Views.
- `Shelf Notes/CoverThumbnailer`: Thumbnail-Erzeugung, Remote-Cover-Anwendung und Backfill.
- `Shelf Notes/ProgressHub`: Fortschritts-Hub und aggregierte Fortschrittsmetriken.
- `Shelf Notes/Goals`: Jahresziel-UI und Zielmetriken.
- `Shelf Notes/Stats`: Statistikquelle, Snapshot Builder, Compute Pipeline, Heatmaps und Präsentationsmodelle.
- `Shelf Notes/Timeline`: Timeline-UI und Builder.
- `Shelf Notes/Challenges`: Challenge-Modelle, Engine, Templates, Rewards, Dashboard, Hints und Refresh-Koordination.
- `Shelf Notes/Collections`: Collections Hub, Detail, Mutationen, Dashboard und Smart Actions.
- `Shelf Notes/TagsView`: Tags Dashboard, Detail, Index, Suggestions, Hygiene Insights und Cleanup.
- `Shelf Notes/Settings`: Einstellungen, Sync-Diagnose, Pro-Screen, Appearance und Library Appearance.
- `Shelf Notes/Analytics`: Leseanalyse-Indizes und Hilfsmodelle.
- `Shelf Notes/Shared/LiveActivity`: Gemeinsame Typen zwischen App und Live-Activity-Extension.
- `ShelfNotesLiveActivity`: Live-Activity-Extension Target.
- `Shelf NotesTests`: Unit Tests für Builder, Mutationen, Caches, Tags, Library, Stats, Challenges und Storage.
- `Shelf NotesUITests`: UI-Test-Stubs.

## Data Model Map

### `Book`

Pfad: `Shelf Notes/BookModel/Book.swift`

Wichtige Felder:

- Identität: `id`, `createdAt`
- Kernmetadaten: `title`, `author`, `subtitle`, `publisher`, `publishedDate`, `language`, `categories`, `mainCategory`, `bookDescription`
- Status: `statusRawValue`, fachlich gekapselt über `readingStatus`
- Nutzerinhalt: `tags`, `notes`, `readFrom`, `readTo`
- Import-IDs: `googleVolumeID`, `isbn13`
- Cover: `thumbnailURL`, `coverURLCandidates`, `userCoverData`, `userCoverFileName`
- Google-Books-Links: `previewLink`, `infoLink`, `canonicalVolumeLink`
- Google-Books-Verfügbarkeit: `viewability`, `isPublicDomain`, `isEmbeddable`, `isEpubAvailable`, `isPdfAvailable`, `epubAcsTokenLink`, `pdfAcsTokenLink`, `saleability`, `isEbook`
- Ratings: sechs Integer-Felder für Plot, Charaktere, Schreibstil, Atmosphäre, Genre Fit und Präsentation

Beziehungen:

- `collections: [BookCollection]?`
- `readingSessions: [ReadingSession]?` mit Cascade Delete

### `ReadingSession`

Pfad: `Shelf Notes/ReadingSession.swift`

- `id`
- `book: Book?`
- `startedAt`, `endedAt`, `durationSeconds`
- `pagesRead`
- `note`
- `createdAt`

### `ReadingGoal`

Pfad: `Shelf Notes/ReadingGoal.swift`

- `id`
- `year`
- `targetCount`
- `updatedAt`

### `BookCollection`

Pfad: `Shelf Notes/BookCollection.swift`

- `id`
- `name`
- `createdAt`, `updatedAt`
- `books: [Book]?`
- Helper: `booksSafe`, Add/Remove/Contains

### `ChallengeRecord`

Pfad: `Shelf Notes/Challenges/ChallengeModels.swift`

- `id`
- `periodStart`, `periodEnd`
- `kindRawValue`, `metricRawValue`
- `title`, `detail`
- `targetValue`
- `createdAt`, `completedAt`, `acknowledgedAt`
- `rerollsUsed`, `rerolledAt`

### Model-Schema

Pfad: `Shelf Notes/Persistence/ModelContainerFactory.swift`

Schema enthält:

- `Book`
- `ReadingSession`
- `ReadingGoal`
- `BookCollection`
- `ChallengeRecord`

## Sync / Storage

- Primärer Store: `ShelfNotesCloud.store` unter Application Support. Pfad: `Shelf Notes/Persistence/ModelContainerFactory.swift`.
- Local-only Store: `ShelfNotesLocal.store` unter Application Support. Pfad: `Shelf Notes/Persistence/ModelContainerFactory.swift`.
- In-Memory-Store: Emergency/Fallback-Modus für Startfehler. Pfad: `Shelf Notes/Persistence/ModelContainerFactory.swift`.
- CloudKit: App-Konfiguration nutzt `cloudKitDatabase: .automatic`.
- Entitlements:
  - App: `Shelf Notes/Shelf_Notes.entitlements`
  - Extension: `ShelfNotesLiveActivityExtension.entitlements`
  - Container: `iCloud.de.marcfechner.Shelf-Notes`
  - App Group: `group.de.marcfechner.Shelf-Notes`
- Offline-Verhalten:
  - Normale CloudKit-Konfiguration speichert lokal und synchronisiert über SwiftData/CloudKit im Hintergrund.
  - Detaillierter CloudKit-Fortschritt ist im Code als nicht verfügbar dokumentiert. Pfad: `Shelf Notes/SyncDiagnostics.swift`.
  - Local-only Mode verwendet absichtlich einen separaten lokalen Store und synchronisiert nicht.
- Caches:
  - Cover Disk Cache: Caches-Verzeichnis `cover-cache`, Default 120 MB. Pfad: `Shelf Notes/ImageCaching/ImageDiskCache.swift`.
  - Cover Memory Cache: `Shelf Notes/ImageCaching/ImageMemoryCache.swift`.
  - Synced Thumbnail Memory Cache: `Shelf Notes/ImageCaching/SyncedThumbnailMemoryCache.swift`.
  - Remote Failure Cache: `Shelf Notes/ImageCaching/RemoteCoverFailureCache.swift`.
  - Search History: `Shelf Notes/SearchHistoryStore.swift`.
- Migration:
  - Status-Legacy-Werte werden über `Shelf Notes/BookModel/Book+Status.swift` und `Shelf Notes/Persistence/ReadingStatusMigrator.swift` behandelt.
  - Eine explizite SwiftData-Versionierung oder umfassende Migration Strategy wurde im Scan nicht als zentrale Policy gefunden: **UNKNOWN**.

## UI Map

### Root Navigation

Pfad: `Shelf Notes/RootView.swift`

`TabView` mit fünf Tabs:

1. Bibliothek: `LibraryView()`
2. Fortschritt: `ProgressHubView()`
3. Listen: `CollectionsView()`
4. Tags: `TagsView()`
5. Einstellungen: `SettingsView()`

Root-Level Environment Objects:

- `ProManager`
- `ReadingTimerManager`
- `TagsIndexStore`

Root-Level AppStorage/SceneStorage:

- Aktiver Tab via `@SceneStorage("root_selected_tab_v1")`
- Appearance- und Library-Settings via `@AppStorage`
- CSV-First-Run-State via `@AppStorage`

### Wichtige Flows und Sheets

- CSV-Import beim ersten Start ohne Bücher: `CSVImportExportView`
- Timer-Abschluss: `TimerSessionCompletionSheet`
- Buch hinzufügen/importieren: `AddBook`, `BookImport`
- Buchdetail: `BookDetailView` mit Status, Metadaten, Tags, Ratings, Sessions, Notizen und Collections
- Collections: Hub, Detail, New Collection, Bulk Add
- Tags: Dashboard, Detail, Suggestions, Hygiene Insights, Cleanup Confirmation
- Challenges: Dashboard, Reward Sheet, Reroll, Session Action Hints
- Settings: Appearance, Library Appearance, Sync Diagnostics, Pro

## Build & Configuration

- Xcode-Projekt: `Shelf Notes.xcodeproj`
- App Target: `Shelf Notes`
- Unit-Test Target: `Shelf NotesTests`
- UI-Test Target: `Shelf NotesUITests`
- Extension Target: `ShelfNotesLiveActivityExtension`
- Deployment Target: iOS 26.0 laut `Shelf Notes.xcodeproj/project.pbxproj`
- Swift Version: 5.0 laut `Shelf Notes.xcodeproj/project.pbxproj`
- Concurrency Settings:
  - `SWIFT_APPROACHABLE_CONCURRENCY = YES`
  - `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
- Bundle IDs:
  - App: `de.marcfechner.Shelf-Notes`
  - Extension: `de.marcfechner.Shelf-Notes.ShelfNotesLiveActivity`
- Versionierung laut Projektdatei:
  - `MARKETING_VERSION = 1.08`
  - `CURRENT_PROJECT_VERSION = 5`
- Info.plist: `Shelf Notes/Info.plist`
  - `GOOGLE_BOOKS_API_KEY = $(GOOGLE_BOOKS_API_KEY)`
  - Kamera- und Foto-Library-Beschreibungen
  - `NSSupportsLiveActivities = true`
  - `UIBackgroundModes = remote-notification`
- xcconfig:
  - `Shelf Notes/config/base.xcconfig`
  - `Shelf Notes/config/secrets.xcconfig`
- Secrets:
  - `Shelf Notes/config/secrets.xcconfig` liegt im ZIP und enthält einen Google-Books-Key im Klartext.
  - `.gitignore` unter `Shelf Notes/.gitignore` schließt `config/secrets.xcconfig` aus.
  - Ob dieser Key historisch committed wurde, ist **UNKNOWN**.
- SPM:
  - Im Projekt wurden keine Package Product Dependencies gefunden.
- Privacy Manifest:
  - `Shelf Notes/PrivacyInfo.xcprivacy`
- Testpläne:
  - `ShelfNotesAppTests.xctestplan` enthält Unit- und UI-Testtargets.
  - `Shelf Notes.xctestplan` enthält keine Testtargets.

## Conventions

### SwiftData / CloudKit

- Keine `@Attribute(.unique)` auf Modell-IDs verwenden, solange CloudKit-Kompatibilität Priorität hat.
- Beziehungen optional halten, wenn CloudKit-Kompatibilität relevant ist.
- Nicht-optionale Modellfelder mit Defaults versehen.
- Neue Modelle in `ModelContainerFactory.makeSchema()` aufnehmen.
- Bei Model-Änderungen immer Migration, Backfill oder Repair-Job mitdenken.
- Mutationen möglichst über `modelContext.saveWithDiagnostics()` speichern.

### UI / SwiftUI

- Große Views werden über Extensions und kleine Subviews gesplittet.
- Teure Berechnungen in Builder/Stores auslagern, nicht direkt in `body`.
- Für Listen/Grid-Cover `LibraryRowCoverView` nutzen, weil diese View keine SwiftData-Saves aus dem Scrollpfad triggert.
- UI-State und fachliche Derived-State-Berechnung trennen.
- AppStorage-Keys stabil und versioniert benennen.

### Builder / Stores / Tests

- Fachlogik bevorzugt in pure Builder legen.
- Für neue Builder Unit Tests im Target `Shelf NotesTests` ergänzen.
- Bestehende Muster:
  - `LibraryDerivedStateBuilderTests`
  - `StatisticsSnapshotBuilderTests`
  - `Challenge*Tests`
  - `Tag*Tests`
  - `Collection*Tests`

### Projektstruktur

- Neue Feature-Dateien klein und modular halten.
- Neue Dateien innerhalb der bestehenden Feature-Ordner ablegen.
- Das Projekt nutzt synchronized file groups; neue Dateien werden automatisch vom Target erkannt.

## How to work on this project

### Setup Steps

1. Projekt in Xcode 26 öffnen: `Shelf Notes.xcodeproj`.
2. Signing Team für App und Extension prüfen.
3. iCloud Container `iCloud.de.marcfechner.Shelf-Notes` und App Group `group.de.marcfechner.Shelf-Notes` im Apple Developer Portal prüfen.
4. `Shelf Notes/config/secrets.xcconfig` lokal bereitstellen, aber nicht committen.
5. App Scheme `Shelf Notes` bauen.
6. Tests vorzugsweise über `ShelfNotesAppTests.xctestplan` laufen lassen.
7. Bei Sync-Problemen zuerst `Settings` und `SyncDiagnosticsView` prüfen.

### Wo anfangen für neue Entwickler

- App-Start: `Shelf Notes/Shelf_NotesApp.swift`, `Shelf Notes/AppContainerHostView.swift`, `Shelf Notes/RootView.swift`
- Persistenz: `Shelf Notes/Persistence/ModelContainerFactory.swift`, `Shelf Notes/BookModel/Book.swift`
- Library-Hotpath: `Shelf Notes/LibraryView/LibraryView.swift`, `Shelf Notes/LibraryView/LibraryDerivedStateBuilder.swift`
- Stats-Hotpath: `Shelf Notes/Stats/StatisticsSourceStore.swift`, `Shelf Notes/Stats/StatisticsComputePipeline.swift`
- Cover-Hotpath: `Shelf Notes/CoverImageLoader.swift`, `Shelf Notes/CoverThumbnailer/CoverThumbnailer.swift`, `Shelf Notes/ImageViews/LibraryRowCoverView.swift`

### Feature-Workflow

- Neues Datenfeld:
  - Modell anpassen.
  - CloudKit-Kompatibilität prüfen.
  - Migration/Repair/Default definieren.
  - Tests ergänzen.
- Neue UI-Funktion:
  - Kleinen Feature-Ordner oder bestehendes Feature-Modul nutzen.
  - View, Builder, Presentation Model und Tests trennen.
  - Keine schweren Berechnungen in `body`.
- Neue Persistenzmutation:
  - Mutation zentralisieren.
  - `saveWithDiagnostics()` verwenden.
  - Bei Session-/Challenge-/Stats-Relevanz passende Refresh-Signale prüfen.
- Neuer Import-/Sync-Flow:
  - Netzwerk, Parsing, Draft und Save getrennt halten.
  - Cancellation und Generation Guards einbauen.

## Quick Wins

1. Google-Books-Key rotieren und sicherstellen, dass `secrets.xcconfig` nie committed wird. Pfade: `Shelf Notes/config/secrets.xcconfig`, `Shelf Notes/.gitignore`.
2. Leeren Testplan `Shelf Notes.xctestplan` entweder entfernen oder mit denselben Targets wie `ShelfNotesAppTests.xctestplan` füllen.
3. `StatisticsSnapshotBuilder.swift` in kleinere Builder splitten, um Review- und Regression-Risiko zu senken.
4. `ChallengeEngine+Compute.swift` nach Metrikberechnung, Baseline und Auswahlpolitik trennen.
5. Challenge-Refresh nach Session-Änderungen coalescen, damit mehrere Saves nicht mehrere Fetch-/Compute-Runden auslösen.
6. Library-Index nur bei Source-Signature-Änderungen neu bauen, nicht bei jeder Root-View-Invalidation.
7. Cover-Pipeline zusätzlich mit globalem Limit für parallele unterschiedliche Remote-URLs absichern.
8. Eine kurze `MIGRATIONS.md` ergänzen: Modelländerungen, Repair-Jobs, CloudKit-Risiken.
9. `os.Logger`-Kategorien für Storage, Sync, Covers, Stats, Challenges und Import einführen.
10. Local-only Mode in Docs und UI noch klarer erklären: separater Store, keine spätere automatische CloudKit-Merge-Logik.
