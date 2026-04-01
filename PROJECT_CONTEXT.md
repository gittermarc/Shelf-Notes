# PROJECT_CONTEXT.md

## TL;DR

Shelf Notes ist eine iOS-App zum Verwalten einer privaten Buchbibliothek mit Lesestatus, Lesesessions, Zielen, Challenges, Listen/Sammlungen, Tags, Timeline, Statistiken, CSV-Import/Export, Google-Books-Import, Pro-Gating für mehr Listen und einer separaten Live-Activity-/Widget-Extension. Der Persistenzkern ist SwiftData; Standardmodus ist ein CloudKit-Store, bei Bootstrap-Fehlern gibt es explizite Fallbacks auf einen separaten lokalen Store oder In-Memory (`Shelf Notes/AppContainerHostView.swift`). App-Target: iOS 26.0, Extension: iOS 26.2 (`Shelf Notes.xcodeproj/project.pbxproj`). iPad-Unterstützung ist im UI-Code klar erkennbar, Catalyst/macOS bleibt **UNKNOWN**.

## Key Concepts / Domänenbegriffe

- **Book** — Hauptmodell für Bibliothekseintrag, Metadaten, Cover, Tags, Notizen, Ratings und Beziehungen (`Shelf Notes/Book.swift`).
- **ReadingStatus** — persistierter stabiler Code `toRead` / `reading` / `finished` plus Legacy-Migration (`Shelf Notes/Book.swift`).
- **ReadingSession** — einzelne Lesesession mit Dauer, Seiten, Notiz (`Shelf Notes/ReadingSession.swift`).
- **ReadingGoal** — Jahresziel für gelesene Bücher (`Shelf Notes/ReadingGoal.swift`).
- **BookCollection** — benutzerdefinierte Liste/Sammlung, many-to-many zu `Book` (`Shelf Notes/BookCollection.swift`).
- **ChallengeRecord** — persistierte Wochen-/Monats-Challenge (`Shelf Notes/Challenges/ChallengeModels.swift`).
- **Synced Thumbnail** — kleines synchronisiertes Cover-JPEG in `Book.userCoverData` (`Shelf Notes/Book.swift`).
- **UserCoverStore** — lokale Vollauflösungen für Nutzer-Cover auf Disk, nicht in CloudKit (`Shelf Notes/CachedAsyncImage.swift`).
- **StorageMode** — `cloudKit`, `localOnly`, `inMemory` (`Shelf Notes/AppContainerHostView.swift`).
- **SyncDiagnostics** — UI-nahe Diagnoseebene für lokale Saves, Netzwerk, iCloud-Status; kein echter CloudKit-Progress-Feed (`Shelf Notes/SyncDiagnostics.swift`).

## Architecture Map

### Layer / Module + Verantwortlichkeiten

- **App Bootstrap / Composition Root**
  - `Shelf Notes/Shelf_NotesApp.swift`
  - `Shelf Notes/AppContainerHostView.swift`
  - Startet den `ModelContainer`, wählt Storage-Modus, zeigt Fehler-/Fallback-UI und stößt Startarbeiten an.

- **Domain / Persistence**
  - `Shelf Notes/Book.swift`
  - `Shelf Notes/ReadingSession.swift`
  - `Shelf Notes/ReadingGoal.swift`
  - `Shelf Notes/BookCollection.swift`
  - `Shelf Notes/Challenges/ChallengeModels.swift`
  - Enthält SwiftData-Modelle, CloudKit-Regeln, kleine Modellhilfen und einige Runtime-Migratoren.

- **Feature Screens**
  - Bibliothek: `Shelf Notes/LibraryView/*`
  - Hinzufügen / Import: `Shelf Notes/AddBook/*`, `Shelf Notes/BookImport/*`
  - Detail / Sessions / Timer: `Shelf Notes/BookDetail/*`
  - Fortschritt: `Shelf Notes/ProgressHub/*`
  - Stats: `Shelf Notes/Stats/*`
  - Timeline: `Shelf Notes/Timeline/*`
  - Tags: `Shelf Notes/TagsView/*`
  - Listen: `Shelf Notes/CollectionsView.swift`
  - Einstellungen: `Shelf Notes/Settings/*`

- **Supporting Services / Infra**
  - `Shelf Notes/GoogleBooksClient.swift`
  - `Shelf Notes/CoverThumbnailer/*`
  - `Shelf Notes/CachedAsyncImage.swift`
  - `Shelf Notes/SyncDiagnostics.swift`
  - `Shelf Notes/ModelContext+Diagnostics.swift`
  - `Shelf Notes/Challenges/ChallengeEngine*.swift`
  - `Shelf Notes/SearchHistoryStore.swift`

- **Cross-Target / Extension Shared**
  - `Shelf Notes/Shared/LiveActivity/*`
  - `ShelfNotesLiveActivity/*`

### Abhängigkeitsbild

- SwiftUI-Features hängen direkt an SwiftData und `@Query`.
- Es gibt keinen durchgängigen Repository-/Store-Layer zwischen UI und Persistence.
- Rechenintensive Logik ist teils sauber in Compute-/Snapshot-Dateien ausgelagert, teils noch viewnah.
- CloudKit wird nicht durch einen separaten Sync-Service abstrahiert, sondern über `ModelConfiguration(... cloudKitDatabase: .automatic)` aktiviert (`Shelf Notes/AppContainerHostView.swift`).
- Singletons / globale Owner:
  - `SyncDiagnostics.shared`
  - `GoogleBooksClient.shared`
  - `ImageMemoryCache.shared`
  - `ImageDiskCache.shared`
  - `ProManager` als EnvironmentObject
  - `ReadingTimerManager` als EnvironmentObject

### Kurzfazit Architektur

Featureorientiert, pragmatisch, produktiv brauchbar, aber mit direkter UI↔SwiftData-Kopplung. Starke Pfade: CloudKit-sensible Modellregeln, Challenge-Compute über Value-Snapshots, einige Caches gegen Renderkosten. Schwächere Pfade: große Dateien, MainActor-nahe Aggregationen, verteilt liegende `@AppStorage`-/Konfigurationslogik, fehlende formale Migrationsschicht.

## Folder Map

- `Shelf Notes/` — App-Target Root.
- `Shelf Notes/AddBook/` — Add-Book-Flow, Router, ViewModel, Karten/Subviews.
- `Shelf Notes/BookDetail/` — Detail, Notes, Collections, Ratings, Sessions, Timer, Live Activity.
- `Shelf Notes/BookImport/` — Google-Books-Import, Query-Building, Paging, Filter.
- `Shelf Notes/Challenges/` — Challenge-Modelle und Engine.
- `Shelf Notes/CoverThumbnailer/` — Cover-Download, Thumbnailing, Apply, Backfill.
- `Shelf Notes/LibraryView/` — Hauptbibliothek, Filterung, Sortierung, Grid/List, Bulk-Actions, Row-Cover-Optimierung.
- `Shelf Notes/ProgressHub/` — zentraler Fortschritts-Hub.
- `Shelf Notes/Settings/` — Settings-Root plus Appearance-Unterbereiche.
- `Shelf Notes/Shared/LiveActivity/` — App-Group-Shared-Modelle und Pfade.
- `Shelf Notes/Stats/` — Statistiken, Heatmap, Cache- und Snapshot-Building.
- `Shelf Notes/TagsView/` — Tag-Index, Tags-Screen, Suggestions.
- `Shelf Notes/Timeline/` — Reading Timeline + ViewModel.
- `Shelf Notes/config/` — `.xcconfig`-Dateien.
- `ShelfNotesLiveActivity/` — WidgetKit-/Live-Activity-Target.
- `Shelf NotesTests/` — Unit-/Integrationstests.
- `Shelf NotesUITests/` — UI-Tests.

## Data Model Map

### `Book` — `Shelf Notes/Book.swift`

**Kernfelder**
- `id`, `title`, `author`, `createdAt`
- `statusRawValue`
- `tags`, `notes`
- `readFrom`, `readTo`
- `googleVolumeID`, `isbn13`, `thumbnailURL`
- `userCoverData` mit `@Attribute(.externalStorage)`
- `userCoverFileName`
- `publisher`, `publishedDate`, `pageCount`, `language`, `categories`, `bookDescription`
- weitere Import-/Link-/Verfügbarkeitsfelder
- 6 Nutzer-Rating-Felder

**Beziehungen**
- `collections: [BookCollection]?`
- `readingSessions: [ReadingSession]?` mit inverse auf `ReadingSession.book`

**Wichtige Helfer**
- `status`
- `userRatingAverage`
- `coverCandidatesAll`
- `pagesReadTotalFromSessions`
- `readingProgressFraction`

### `ReadingSession` — `Shelf Notes/ReadingSession.swift`

**Felder**
- `id`
- `book`
- `startedAt`, `endedAt`
- `durationSeconds`
- `pagesRead`
- `note`
- `createdAt`

**Beziehung**
- many-to-one zu `Book`

### `ReadingGoal` — `Shelf Notes/ReadingGoal.swift`

**Felder**
- `year`
- `targetCount`
- `updatedAt`

### `BookCollection` — `Shelf Notes/BookCollection.swift`

**Felder**
- `id`
- `name`
- `createdAt`
- `updatedAt`
- `books`

### `ChallengeRecord` — `Shelf Notes/Challenges/ChallengeModels.swift`

**Felder**
- `id`
- `periodStart`, `periodEnd`
- `kindRawValue`, `metricRawValue`
- `title`, `detail`
- `targetValue`
- `createdAt`
- `completedAt`, `acknowledgedAt`
- `rerollsUsed`, `rerolledAt`

### Relationship Summary

- `Book` ↔ `BookCollection`
  - many-to-many
  - beide Seiten optional
  - Konsistenzreparatur über `Shelf Notes/CollectionMembershipRepair.swift`

- `Book` → `ReadingSession`
  - one-to-many
  - `deleteRule: .cascade`

- `ReadingGoal`, `ChallengeRecord`
  - ohne direkte Beziehungen

## Sync / Storage

### Primäre Persistenz

- SwiftData ist der primäre Datenspeicher.
- Das zentrale Schema sitzt in `ModelContainerFactory.schema` (`Shelf Notes/AppContainerHostView.swift`) und enthält:
  - `Book`
  - `ReadingSession`
  - `ReadingGoal`
  - `BookCollection`
  - `ChallengeRecord`

### Storage Modes

- **cloudKit** — Standardmodus mit `cloudKitDatabase: .automatic`
- **localOnly** — separater persistenter Store ohne CloudKit
- **inMemory** — Notfallmodus ohne Persistenz

### Store Separation

- Getrennte Dateinamen:
  - `ShelfNotesCloud.store`
  - `ShelfNotesLocal.store`
- Ziel: keine stille Vermischung von Cloud- und Local-Daten.
- Konsequenz: `localOnly` erzeugt einen eigenständigen Datenstand.

### Store-Ort

- `Application Support/ShelfNotes/SwiftData/<StoreName>.store`
- Implementiert in `storeURL(for:)` (`Shelf Notes/AppContainerHostView.swift`).

### CloudKit / Entitlements

- iCloud-Container: `iCloud.de.marcfechner.Shelf-Notes`
- App Group: `group.de.marcfechner.Shelf-Notes`
- Quelle:
  - `Shelf Notes/Shelf_Notes.entitlements`
  - `ShelfNotesLiveActivityExtension.entitlements`

### Runtime-Reparaturen / Migrationen / Backfills

- `ReadingStatusMigrator.migrateIfNeeded` (`Shelf Notes/Book.swift`)
- `CollectionMembershipRepair.repairIfNeeded` (`Shelf Notes/CollectionMembershipRepair.swift`)
- `ChallengeEngine.ensureCurrentChallengesAndRefreshCompletion` (`Shelf Notes/Challenges/ChallengeEngine.swift`)
- Cover-Backfill (`Shelf Notes/RootView.swift`, `Shelf Notes/CoverThumbnailer/*`)

### Diagnostik

- `saveWithDiagnostics()` wrapped Saves (`Shelf Notes/ModelContext+Diagnostics.swift`)
- `SyncDiagnostics.shared` speichert:
  - letztes lokales Save
  - Offline-Save-Zähler
  - iCloud-Accountstatus
  - UserRecord-Short-ID
  - Netzwerkstatus (`NWPathMonitor`)
- `Settings > Sync-Diagnose` hängt an `Shelf Notes/SyncDiagnosticsView.swift`

### Caches / sekundäre Speicherorte

- `ImageMemoryCache` — RAM-Cache (`Shelf Notes/CachedAsyncImage.swift`)
- `ImageDiskCache` — lokaler Cover-Cache im Caches-Verzeichnis (`Shelf Notes/CachedAsyncImage.swift`)
- `UserCoverStore` — lokale Vollauflösungen im Application Support (`Shelf Notes/CachedAsyncImage.swift`)
- Live-Activity-App-Group-Store — `Shelf Notes/Shared/LiveActivity/LiveActivitySharedStore.swift`

### Migration Plan / Conflict Strategy

- `VersionedSchema` / `SchemaMigrationPlan` wurden im gescannten Stand nicht gefunden.
- explizite fachliche Konfliktstrategie für Multi-Device-Änderungen ist **UNKNOWN**.

## UI Map

### Entry Points

- `Shelf Notes/Shelf_NotesApp.swift` → startet `AppContainerHostView()`
- `Shelf Notes/AppContainerHostView.swift` → bootstrappt den Store und hängt `RootView()` an
- `Shelf Notes/ContentView.swift` → nur Wrapper auf `RootView()`, aktuell kein primärer Einstieg

### Root Tabs — `Shelf Notes/RootView.swift`

- `LibraryView()` — Bibliothek
- `ProgressHubView()` — Fortschritt
- `CollectionsView()` — Listen
- `TagsView()` — Tags
- `SettingsView()` — Einstellungen

Zusätzlich in `RootView`:
- globales Appearance/Tint/Font/Density über `@AppStorage`
- `selectedTab` per `@SceneStorage("root_selected_tab_v1")`
- CSV-First-Run-Sheet (`CSVImportExportView`)
- Timer-Completion-Sheet
- Cover-Backfill-Scheduling

### Hauptflows

- **Bibliothek**
  - `Shelf Notes/LibraryView/LibraryView.swift`
  - eigener `NavigationStack`
  - Flows: Add Book, Bulk Add to Collection, Bulk Delete, Tag-Bulk-Actions, Detail

- **Buchdetail**
  - `Shelf Notes/BookDetail/BookDetailView.swift`
  - Sheets: Notes, Collections, Ratings, All Sessions, neue Collection, Paywall, Share, Online Cover Picker, Photo Picker

- **Buch hinzufügen**
  - `Shelf Notes/AddBook/AddBookView.swift`
  - Sheet-Router über `AddBookSheet`
  - Ziele: `BookImportView`, `BarcodeScannerSheet`, `InspirationSeedPickerView`, `ManualBookAddSheet`

- **Import**
  - `Shelf Notes/BookImport/BookImportView/BookImportView.swift`
  - Google Books Suche mit Filter, Paging und Quick Add

- **Fortschritt**
  - `Shelf Notes/ProgressHub/ProgressHubView.swift`
  - Quick Links zu `StatisticsView`, `GoalsView`, `ReadingTimelineView`, `ChallengesView`

- **Listen**
  - `Shelf Notes/CollectionsView.swift`
  - `NavigationLink` nach `CollectionDetailView`

- **Tags**
  - `Shelf Notes/TagsView/TagsView.swift`
  - `NavigationLink` nach `LibraryView(initialTag:)`

- **Einstellungen**
  - `Shelf Notes/Settings/SettingsView.swift`
  - eigener persistierter `NavigationStack(path:)`
  - Ziele: Appearance, CSV Import/Export, Sync-Diagnose, Paywall

## Build & Configuration

### Targets

- `Shelf Notes`
- `Shelf NotesTests`
- `Shelf NotesUITests`
- `ShelfNotesLiveActivityExtension`

Quelle: `Shelf Notes.xcodeproj/project.pbxproj`

### Deployment Targets

- App / Tests / UI-Tests: iOS 26.0
- Extension: iOS 26.2

### Konfiguration

- `Shelf Notes/config/base.xcconfig` inkludiert `Shelf Notes/config/secrets.xcconfig`
- `GOOGLE_BOOKS_API_KEY` wird via `Info.plist` injiziert (`Shelf Notes/Info.plist`)

### Security / Config Risk

- `Shelf Notes/config/secrets.xcconfig` enthält aktuell einen echten Google-Books-API-Key.
- Das ist ein klarer Quick Win.

### Capabilities / Plists

- `Shelf Notes/Shelf_Notes.entitlements`
  - CloudKit
  - iCloud container
  - App Group
  - APS environment = development
- `Shelf Notes/Info.plist`
  - `GOOGLE_BOOKS_API_KEY`
  - `UIBackgroundModes = remote-notification`
  - Kamera-/Foto-Usage Descriptions
  - `NSSupportsLiveActivities = true`
- `Shelf Notes/PrivacyInfo.xcprivacy`
  - vorhanden

### SPM / externe Dependencies

- Im `.pbxproj` wurden keine Swift Package References gefunden.
- Genutzte Apple-Frameworks / Plattformdienste:
  - SwiftData
  - CloudKit
  - StoreKit
  - ActivityKit / WidgetKit
  - UIKit / PhotosUI / Charts
- Externer HTTP-Dienst:
  - Google Books API

### StoreKit Test Config

- `Shelf Notes/unlimited_collections.storekit`

### Projektstil

- Xcode-Projekt nutzt file-system-synchronized groups.
- Konsequenz: neue Dateien im Ordner werden in Xcode 15 typischerweise automatisch sichtbar.

## Conventions

### Wiederkehrende Muster

- große SwiftUI-Dateien werden per `extension` in thematische Dateien gesplittet
- teure Derived Data wird per `.task(id: signature)` aus dem direkten Renderpfad gezogen
- `@AppStorage` ist Standard für Appearance- und UI-Präferenzen
- `saveWithDiagnostics()` ist der bevorzugte Save-Pfad
- zentrale Appearance-Keys leben in `Shelf Notes/Settings/AppearanceSettings/AppearancePreferences.swift`

### CloudKit-/SwiftData-Regeln aus dem Code

- kein `@Attribute(.unique)` in synchronisierten Modellen
- Defaults für nicht-optionale Properties
- Relationships optional halten, wenn CloudKit/Makros sonst instabil werden
- Inversen bewusst modellieren
- lokale Vollbild-/Dateipfade nicht blind in synchronisierte Felder persistieren

Quellen:
- `Shelf Notes/Book.swift`
- `Shelf Notes/BookCollection.swift`
- `Shelf Notes/ReadingSession.swift`
- `Shelf Notes/ReadingGoal.swift`
- `Shelf Notes/Challenges/ChallengeModels.swift`

### Do / Don’t

**Do**
- neue Models in `ModelContainerFactory.schema` ergänzen
- Signaturen/Snapshots für teure Derived Data einführen
- große Views weiter in kleine thematische Dateien zerlegen
- Save-Pfade über `saveWithDiagnostics()` führen
- CloudKit-Regeln aus bestehenden Models kopieren

**Don’t**
- vollständige Bibliotheks-Fetches in häufigen UI-Pfaden verstecken
- MainActor für lange Datei-/Netzwerk-/Aggregationstätigkeiten missbrauchen
- Full-Res-Bilder in SwiftData/CloudKit schieben
- verstreute String-Keys ohne zentrale Ownership einführen

## How to work on this project

### Setup

- [ ] `Shelf Notes.xcodeproj` in Xcode 15 öffnen
- [ ] Signing, iCloud, App Group und CloudKit für App + Extension korrekt setzen
- [ ] `config/secrets.xcconfig` lokal prüfen
- [ ] optional `unlimited_collections.storekit` für Pro-Tests einbinden
- [ ] App starten und Container-Bootstrap beobachten
- [ ] Sync-Diagnose in Settings einmal prüfen

### Wo neue Entwickler anfangen sollten

- `Shelf Notes/AppContainerHostView.swift`
- `Shelf Notes/RootView.swift`
- `Shelf Notes/Book.swift`
- `Shelf Notes/ReadingSession.swift`
- `Shelf Notes/BookCollection.swift`
- `Shelf Notes/Challenges/ChallengeEngine.swift`
- `Shelf Notes/LibraryView/LibraryView.swift`
- `Shelf Notes/Stats/StatisticsView.swift`
- `Shelf Notes/Settings/SettingsView.swift`

### Typische Workflows

- **neues persistiertes Feld / neues Modell**
  - Modell anlegen/erweitern
  - CloudKit-Regeln prüfen
  - `ModelContainerFactory.schema` anpassen
  - Runtime-Migration/Reparaturbedarf prüfen

- **neuer Tab / globaler Screen**
  - `Shelf Notes/RootView.swift`

- **neuer Settings-Bereich**
  - `Shelf Notes/Settings/SettingsView.swift`
  - Schlüssel möglichst zentral bündeln

- **neuer Import-/Add-Flow**
  - `Shelf Notes/AddBook/*`
  - `Shelf Notes/BookImport/*`

- **neue Statistik / neue Aggregation**
  - zuerst Stats-/Snapshot-Struktur prüfen:
    - `Shelf Notes/Stats/StatisticsSnapshotBuilder.swift`
    - `Shelf Notes/Stats/StatisticsView+Caching.swift`
    - `Shelf Notes/ProgressHub/ProgressHubMetricsModel.swift`

- **neuer Cover-/Media-Pfad**
  - `Shelf Notes/CachedAsyncImage.swift`
  - `Shelf Notes/CoverThumbnailer/*`

## Quick Wins

1. API-Key aus `Shelf Notes/config/secrets.xcconfig` entfernen und auf Template + lokale Override-Datei umstellen.
2. `BookDetailView.updateTagsIndexModelFromLibrary()` ersetzen; der Detail-Screen sollte nicht die komplette Bibliothek laden.
3. Stats-Rebuild in einen detached/value-only Compute-Pfad verlagern.
4. `CSVImportExportView.swift` in UI + Import-Service + Duplicate-Index zerlegen.
5. `ContentView.swift` entweder entfernen oder bewusst als Legacy-Einstieg dokumentieren.
6. Startarbeiten (`Repair`, `ChallengeEnsure`, Migration, Cover-Backfill) orchestration-seitig bündeln.
7. `LibraryView`-Derived-State in einen dedizierten Builder/Store auslagern.
8. weitere `@AppStorage`-Key-Gruppen zentralisieren.
9. strukturierte Logs/Signposts für Bootstrap, Stats und Import ergänzen.
10. formale Migrationsstrategie dokumentieren; aktuell sind nur Runtime-Migratoren sichtbar.

## Open Questions

- **UNKNOWN:** Gibt es außerhalb des ZIPs einen formalen SwiftData-Migrationspfad?
- **UNKNOWN:** Wie werden echte CloudKit-Konflikte zwischen Geräten fachlich bewertet oder aufgelöst?
- **UNKNOWN:** Wird `UIBackgroundModes = remote-notification` aktiv genutzt?
- **UNKNOWN:** Gibt es zusätzliche `.xcconfig`-Layer oder Build-Skripte außerhalb des gescannten Standes?
- **UNKNOWN:** Ist `ContentView.swift` absichtliche Kompatibilität oder technischer Restbestand?
