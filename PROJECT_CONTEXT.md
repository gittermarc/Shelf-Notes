# PROJECT_CONTEXT.md

## TL;DR

Shelf Notes ist eine SwiftUI-App für iPhone und iPad zum Verwalten einer Buchbibliothek mit Lesestatus, Tags, Listen, Notizen, Sessions, Zielen, Challenges, Statistiken, CSV-Import/Export, Google-Books-Import, Cover-Handling und Live-Activity-Lesetimer. Die Persistenz läuft über SwiftData mit CloudKit-Sync und expliziten lokalen Fallback-Stores. Das Projekt enthält außerdem ein WidgetKit/ActivityKit-Extension-Target. Der gescannte Xcode-Build-Stand setzt `IPHONEOS_DEPLOYMENT_TARGET = 26.0` in `Shelf Notes.xcodeproj/project.pbxproj`; ob dieses sehr hohe Minimum absichtlich ist, ist **UNKNOWN**.

Scan-Hinweis: Diese Datei basiert auf statischer Analyse des ZIPs. Es wurde kein `xcodebuild` ausgeführt.

---

## Key Concepts / Domänenbegriffe

- **Book**: Zentrale Entität in `Shelf Notes/BookModel/Book.swift`. Speichert Titel, Autor, Status, Tags, Notizen, Metadaten, Cover-Daten, Bewertungen und Beziehungen.
- **ReadingStatus**: Stabil persistierter Status in `Shelf Notes/BookModel/Book+Status.swift` mit Raw Values `toRead`, `reading`, `finished`; Legacy-deutsche Strings werden gemappt.
- **ReadingSession**: Einzelne Lesesession in `Shelf Notes/ReadingSession.swift`, optional einem Book zugeordnet, mit Dauer, Seiten und Notiz.
- **ReadingGoal**: Jahresziel in `Shelf Notes/ReadingGoal.swift`.
- **BookCollection**: Manuelle Liste/Sammlung in `Shelf Notes/BookCollection.swift`, many-to-many mit Book.
- **ChallengeRecord**: Persistierte Wochen-/Monats-Challenge in `Shelf Notes/Challenges/ChallengeModels.swift`; Fortschritt wird aus Sessions und Büchern berechnet.
- **TagsIndex**: Abgeleiteter Index für Tags, gebaut in `Shelf Notes/TagsView/TagsIndexBuilder.swift`, gehalten in `Shelf Notes/TagsView/TagsIndexStore.swift`.
- **Synced Thumbnail**: Kleines JPEG in `Book.userCoverData`, mit `@Attribute(.externalStorage)` gespeichert und über CloudKit synchronisiert.
- **Full-res User Cover**: Lokale Datei in `UserCoverStore`; nur Dateiname wird am Book gehalten, die große Datei selbst ist gerätespezifisch.
- **CloudKit Store vs. Local-only Store**: Getrennte Stores `ShelfNotesCloud.store` und `ShelfNotesLocal.store`, erzeugt in `Shelf Notes/AppContainerHostView.swift`.
- **Live Activity Timer**: App-seitiger Timer in `Shelf Notes/Shared/LiveActivity/ReadingTimerManager.swift`; Extension-Kommandos in `ShelfNotesLiveActivity/ReadingSessionLiveActivityIntents.swift`.

---

## Architecture Map

### Entry / Bootstrap

- `Shelf Notes/Shelf_NotesApp.swift`
  - `@main` Entry Point.
  - `WindowGroup` startet `AppContainerHostView()`.
- `Shelf Notes/AppContainerHostView.swift`
  - Initialisiert `ModelContainer` robust ohne `fatalError`.
  - Modi: CloudKit, Local-only, In-memory.
  - Hängt `.modelContainer(container)` an `RootView()`.
  - Startet nach Container-Ready: `CollectionMembershipRepair.repairIfNeeded` und `ChallengeRefreshCoordinator.prepareCurrentChallenges`.
- `Shelf Notes/RootView.swift`
  - Haupt-TabView, globale Appearance, EnvironmentObjects, CSV-Erstimport, Status-Migration, Cover-Backfill und Timer-Completion-Sheet.

### Persistenz / Sync Layer

- SwiftData-Modelle:
  - `Shelf Notes/BookModel/Book.swift`
  - `Shelf Notes/ReadingSession.swift`
  - `Shelf Notes/ReadingGoal.swift`
  - `Shelf Notes/BookCollection.swift`
  - `Shelf Notes/Challenges/ChallengeModels.swift`
- Container/Store-Policy:
  - `Shelf Notes/AppContainerHostView.swift`
- Save-Diagnostik:
  - `Shelf Notes/ModelContext+Diagnostics.swift`
  - `Shelf Notes/SyncDiagnostics.swift`
  - `Shelf Notes/SyncDiagnosticsView.swift`
- Datenreparatur/Migration:
  - `Shelf Notes/CollectionMembershipRepair.swift`
  - `Shelf Notes/ReadingStatusMigrator.swift`

### Feature Layer

- Library: `Shelf Notes/LibraryView/*`, `Shelf Notes/BookRowView.swift`, `Shelf Notes/LibraryView/LibraryRowCoverView.swift`
- Add Book / Import: `Shelf Notes/AddBook/*`, `Shelf Notes/BookImport/*`, `Shelf Notes/GoogleBooksClient.swift`, `Shelf Notes/GoogleVolumeBookMapper.swift`
- Book Detail / Sessions: `Shelf Notes/BookDetail/*`, `Shelf Notes/TimerSessionCompletionSheet.swift`
- Collections: `Shelf Notes/CollectionsView.swift`, `Shelf Notes/CollectionDetailView.swift`, `Shelf Notes/Collections/*`
- Tags: `Shelf Notes/TagsView/*`, `Shelf Notes/TagNormalization.swift`, `Shelf Notes/TagChip.swift`
- Progress: `Shelf Notes/ProgressHub/*`, `Shelf Notes/Goals/*`, `Shelf Notes/Stats/*`, `Shelf Notes/Timeline/*`, `Shelf Notes/Challenges/*`
- Settings: `Shelf Notes/Settings/*`, `Shelf Notes/SyncDiagnosticsView.swift`
- CSV: `Shelf Notes/CSVImportExport/*`
- Cover/Image: `Shelf Notes/CoverThumbnailer/*`, `Shelf Notes/ImageCaching/*`, `Shelf Notes/ImageViews/*`, `Shelf Notes/CoverImageLoader.swift`, `Shelf Notes/CachedAsyncImage.swift`
- Monetization: `Shelf Notes/ProManager.swift`, `Shelf Notes/ProPaywallView.swift`

### Shared / Extension

- Shared app group/timer types: `Shelf Notes/Shared/LiveActivity/*`
- Live Activity extension:
  - `ShelfNotesLiveActivity/ShelfNotesLiveActivityBundle.swift`
  - `ShelfNotesLiveActivity/ShelfNotesLiveActivityLiveActivity.swift`
  - `ShelfNotesLiveActivity/ReadingSessionLiveActivityIntents.swift`
  - `ShelfNotesLiveActivity/LiveActivityCoverLoader.swift`

### Dependency Direction

- Views lesen SwiftData über `@Query` oder Environment-`modelContext`.
- Views delegieren komplexe Berechnungen an Builder, Stores oder ViewModels.
- Pure Builder erzeugen Value-Modelle für Library, Tags, Stats, Challenges, Collections und Goals.
- Services kapseln Netzwerk, Cover-Dateien, Caches, CloudKit-Diagnostik und In-App-Purchase.
- Die Live-Activity-Extension kommuniziert nicht über SwiftData, sondern über App-Group-UserDefaults und ActivityKit.

---

## Folder Map

| Pfad | Zweck |
|---|---|
| `Shelf Notes/` | Haupt-App-Target mit Root, Modellen, Services und Feature-Einstiegspunkten. |
| `Shelf Notes/BookModel/` | Book-Extensions für Status, Collections, Ratings, Import und Cover-URLs. |
| `Shelf Notes/LibraryView/` | Bibliothek, Filter, Sortierung, Grid/List, Header, Bulk Actions und Derived State. |
| `Shelf Notes/BookDetail/` | Detailansicht, Cards, Bindings, Notes, Ratings, Sessions und Cover-Picker. |
| `Shelf Notes/AddBook/` | Manuelle Anlage, Tag-Drafts, Cards und AddBook-ViewModel. |
| `Shelf Notes/BookImport/` | Google-Books-Suche, Filter, Pagination, ViewModel-Splits, Import-Mapping. |
| `Shelf Notes/Collections/` | Collection-Dashboard, Detail-Modelle, Cards, Smart Actions, Membership-Mutation. |
| `Shelf Notes/TagsView/` | Tag-Dashboard, Index, Hygiene, Suggestions, Detail, Mutation-Sheet. |
| `Shelf Notes/Challenges/` | Challenge-Modelle, Engine, Templates, Progress, Summary, Refresh-Koordinator. |
| `Shelf Notes/Stats/` | Statistik-Snapshots, Caches, Heatmap, Charts, SourceStore. |
| `Shelf Notes/Goals/` | Jahresziele, Metriken, Draft-Policy. |
| `Shelf Notes/Timeline/` | Lese-Timeline und Jahressektionen. |
| `Shelf Notes/ProgressHub/` | Fortschritt-Startscreen mit Links zu Stats, Goals, Timeline und Challenges. |
| `Shelf Notes/CoverThumbnailer/` | Thumbnail-Generierung, Backfill, Remote-Fetch, Apply-Flows, ImageIO. |
| `Shelf Notes/ImageCaching/` | Memory-, Disk- und Synced-Thumbnail-Caches. |
| `Shelf Notes/ImageViews/` | Wiederverwendbare Cover-Image-Views und Candidate-Sequenzen. |
| `Shelf Notes/CSVImportExport/` | CSV-Codec, Export, Import, Duplicate Index, Import/Export-ViewModel. |
| `Shelf Notes/Settings/` | Settings, Appearance, Library-Appearance, Sync-Diagnose-Verlinkung. |
| `Shelf Notes/Shared/LiveActivity/` | App-Group-Keys, Activity-Attributes, Timer-Manager. |
| `Shelf Notes/Persistence/` | Aktuell nur Save-Debouncer; Container-Fabrik liegt noch in `AppContainerHostView.swift`. |
| `Shelf NotesTests/` | Viele Unit-Tests für Builder, Mutations, CSV, Stats, Tags, Library, Challenges und Goals. |
| `Shelf NotesUITests/` | Basis-UI- und Launch-Tests. |
| `ShelfNotesLiveActivity/` | WidgetKit/ActivityKit-Extension. |
| `Shelf Notes.xcodeproj/` | Xcode-Projekt mit synchronisierten File-System-Gruppen. |

---

## Data Model Map

### `Book` in `Shelf Notes/BookModel/Book.swift`

- Identity: `id: UUID`; bewusst ohne `@Attribute(.unique)` wegen CloudKit/SwiftData.
- Core: `title`, `author`, `createdAt`, `statusRawValue`, `tags`, `notes`.
- Reading period: `readFrom`, `readTo`.
- Relationships:
  - `collections: [BookCollection]?`
  - `readingSessions: [ReadingSession]?` mit Cascade Delete und inverse `ReadingSession.book`.
- Import metadata: `googleVolumeID`, `isbn13`, `thumbnailURL`, `publisher`, `publishedDate`, `pageCount`, `language`, `categories`, `bookDescription`, `subtitle`, `previewLink`, `infoLink`, `canonicalVolumeLink`.
- Ratings and categories: `averageRating`, `ratingsCount`, `mainCategory`, `userRatingPlot`, `userRatingCharacters`, `userRatingWritingStyle`, `userRatingAtmosphere`, `userRatingGenreFit`, `userRatingPresentation`.
- Access/sale metadata: `viewability`, `isPublicDomain`, `isEmbeddable`, `isEpubAvailable`, `isPdfAvailable`, `epubAcsTokenLink`, `pdfAcsTokenLink`, `saleability`, `isEbook`.
- Cover: `coverURLCandidates`, `userCoverData`, `userCoverFileName`.

### `BookCollection` in `Shelf Notes/BookCollection.swift`

- Fields: `id`, `name`, `createdAt`, `updatedAt`, `books: [Book]?`.
- Relationship: many-to-many zu `Book.collections`.
- Mutations sollen über `Shelf Notes/Collections/CollectionMembershipMutation.swift` laufen.
- `booksSafe` behandelt `nil` als leeres Array.

### `ReadingSession` in `Shelf Notes/ReadingSession.swift`

- Fields: `id`, `book: Book?`, `startedAt`, `endedAt`, `durationSeconds`, `pagesRead`, `note`, `createdAt`.
- `durationSeconds` ist ein gecachter Wert und wird über Initializer bzw. `recomputeDuration()` gepflegt.
- `pagesReadNormalized` gibt nur positive Seitenwerte zurück.

### `ReadingGoal` in `Shelf Notes/ReadingGoal.swift`

- Fields: `year`, `targetCount`, `updatedAt`.
- Keine Unique-Constraint; Non-Optional-Felder haben Defaults.

### `ChallengeRecord` in `Shelf Notes/Challenges/ChallengeModels.swift`

- Fields: `id`, `periodStart`, `periodEnd`, `kindRawValue`, `metricRawValue`, `title`, `detail`, `targetValue`, `createdAt`, `completedAt`, `acknowledgedAt`, `rerollsUsed`, `rerolledAt`.
- Metrics: reading minutes, reading days, sessions, pages read, finished books, short sessions, progressed books, session notes, rated finished books, noted finished books.
- Progress wird berechnet, nicht direkt als Wert gespeichert.

---

## Sync / Storage

### SwiftData / CloudKit

- `ModelContainerFactory.schema` in `Shelf Notes/AppContainerHostView.swift` enthält `Book`, `ReadingSession`, `ReadingGoal`, `BookCollection`, `ChallengeRecord`.
- CloudKit-Modus nutzt `ModelConfiguration` mit `cloudKitDatabase: .automatic` und Store-Name `ShelfNotesCloud`.
- Local-only-Modus nutzt `cloudKitDatabase: .none` und Store-Name `ShelfNotesLocal`.
- In-memory-Modus nutzt `isStoredInMemoryOnly: true` und `cloudKitDatabase: .none`.
- Store-Dateien liegen unter Application Support: `ShelfNotes/SwiftData/<StoreName>.store`.

### CloudKit-Modellregeln im Code

- Keine `@Attribute(.unique)` bei Modellen.
- Beziehungen sind optional, zum Beispiel `Book.collections` und `BookCollection.books`.
- Nicht-optionale persistierte Felder haben Defaults.
- Lesen alter Statuswerte wird in `ReadingStatus.fromPersisted` abgefangen; eine einmalige Migration schreibt stabile Raw Values.

### Caches / Cover Storage

- `Book.userCoverData` ist das synchronisierte Thumbnail und nutzt `@Attribute(.externalStorage)`.
- `UserCoverStore` speichert Full-res User-Cover lokal im Application-Support-Verzeichnis.
- `ImageDiskCache` speichert Remote-Cover lokal in `Caches/cover-cache`; keine Größen- oder TTL-Grenze gefunden.
- `ImageMemoryCache` und `SyncedThumbnailMemoryCache` reduzieren Dekodier- und Netzwerkdruck.

### Migrations / Repairs

- `Shelf Notes/ReadingStatusMigrator.swift` migriert Legacy-Statusstrings einmalig.
- `Shelf Notes/CollectionMembershipRepair.swift` dedupliziert und symmetriert Book-Collection-Beziehungen einmalig pro Store-Scope.
- Challenge-Records werden beim App-Start und bei relevanten Aktionen über `ChallengeRefreshCoordinator` vorbereitet oder aktualisiert.

### Offline-Verhalten

- CloudKit-Sync wird über SwiftData/CloudKit implizit gehandhabt.
- `SyncDiagnostics` beobachtet Netzwerk, iCloud-Account und lokale Saves, aber nicht den CloudKit-Upload-Fortschritt.
- Local-only ist ein separater Datenstand und wird nicht automatisch in den CloudKit-Store gemerged.
- Exaktes Konfliktverhalten bei Multi-Device-Änderungen ist **UNKNOWN**.

---

## UI Map

### Root Navigation

- `RootView` nutzt `TabView(selection:)` mit `@SceneStorage("root_selected_tab_v1")`.
- Tabs:
  - `LibraryView()` als Bibliothek.
  - `ProgressHubView()` als Fortschritt.
  - `CollectionsView()` als Listen.
  - `TagsView()` als Tags.
  - `SettingsView()` als Einstellungen.

### Library Flow

- `Shelf Notes/LibraryView/LibraryView.swift`
  - `NavigationStack`.
  - `@Query(sort: \Book.createdAt, order: .reverse)`.
  - Suche, Statusfilter, Tagfilter, Sortierung, List/Grid, A-Z-Index, Bulk Actions.
  - Sheets: `AddBookView`, `BulkAddToCollectionSheet`.
  - Navigation zu `BookDetailView` über List/Grid/Alpha-Index-Dateien.

### Add / Import Flow

- `Shelf Notes/AddBook/AddBookView.swift`
  - `NavigationStack` für manuelle Anlage und Import-Aktionen.
  - Sheets über ViewModel-State: Google-Books-Import, Barcode-Scanner, Inspiration-Seed-Picker, Manual-Add-Sheet.
- `Shelf Notes/BookImport/BookImportView/BookImportView.swift`
  - Google-Books-Suche, Filter, Pagination, Quick-Add, Undo.

### Detail / Sessions Flow

- `Shelf Notes/BookDetail/BookDetailView.swift`
  - Detailscreen mit Cards, Notizen, Collections, Rating, Sessions und Cover-Auswahl.
  - Timer-Integration über `ReadingTimerManager`.
- `Shelf Notes/BookDetail/Sessions/SessionsCard.swift`
  - Session-Liste und Quick-Log/Edit-Flows.
- `Shelf Notes/TimerSessionCompletionSheet.swift`
  - Wird vom Root präsentiert, wenn eine Live-/Timer-Session abgeschlossen werden muss.

### Progress Flow

- `Shelf Notes/ProgressHub/ProgressHubView.swift`
  - `NavigationStack`.
  - Links zu `StatisticsView`, `GoalsView`, `ReadingTimelineView`, `ChallengesView`.
  - Nutzt `@Query` für Books, ChallengeRecords und ReadingGoals.

### Collections Flow

- `Shelf Notes/CollectionsView.swift`
  - `NavigationStack`.
  - Collection-Dashboard, Suche/Explorer, New-Collection-Sheet, Paywall für Pro-Limit.
  - Navigation zu `CollectionDetailView`.

### Tags Flow

- `Shelf Notes/TagsView/TagsView.swift`
  - `NavigationStack`, Suche, Tag-Dashboard, Hygiene und Suggestions.
  - Navigation zu `TagDetailView` und gefilterter Library.
  - Mutationen über `TagLibraryMutation` und `TagMutationEditorSheet`.

### Settings Flow

- `Shelf Notes/Settings/SettingsView.swift`
  - `NavigationStack(path:)` mit persistiertem Pfad.
  - Appearance, Buchsuche, CSV Import/Export, Sync-Diagnose, Auto-Stop, Cover-Cache, Pro, Version/Build.
  - Sheet: `ProPaywallView`.

---

## Build & Configuration

- Targets in `Shelf Notes.xcodeproj/project.pbxproj`:
  - `Shelf Notes` App.
  - `Shelf NotesTests` Unit Tests.
  - `Shelf NotesUITests` UI Tests.
  - `ShelfNotesLiveActivityExtension` App Extension.
- Xcode nutzt `PBXFileSystemSynchronizedRootGroup` für App, Tests, UI Tests und Live-Activity-Extension. Neue Dateien unter diesen Ordnern werden vom Projekt synchronisiert.
- Bundle IDs:
  - App: `de.marcfechner.Shelf-Notes`.
  - Extension: `de.marcfechner.Shelf-Notes.ShelfNotesLiveActivity`.
- Versionen:
  - App `MARKETING_VERSION = 1.08`, `CURRENT_PROJECT_VERSION = 4`.
  - Extension ebenfalls `MARKETING_VERSION = 1.08`, `CURRENT_PROJECT_VERSION = 4`.
- Swift:
  - `SWIFT_VERSION = 5.0`.
  - `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` im App-Target.
  - `SWIFT_APPROACHABLE_CONCURRENCY = YES`.
- Plattform:
  - `TARGETED_DEVICE_FAMILY = "1,2"` für iPhone und iPad.
  - `IPHONEOS_DEPLOYMENT_TARGET = 26.0` in Projekt-/Target-Build-Settings.
- Entitlements:
  - App: CloudKit-Container `iCloud.de.marcfechner.Shelf-Notes`, iCloud-Service `CloudKit`, App Group `group.de.marcfechner.Shelf-Notes`, Push development.
  - Extension: App Group `group.de.marcfechner.Shelf-Notes`.
- Info.plist:
  - `GOOGLE_BOOKS_API_KEY = $(GOOGLE_BOOKS_API_KEY)`.
  - Kamera und Photos Usage Strings.
  - `NSSupportsLiveActivities = true`.
  - `UIBackgroundModes = remote-notification`.
- Config:
  - `Shelf Notes/config/base.xcconfig` inkludiert `secrets.xcconfig`.
  - `Shelf Notes/config/secrets.xcconfig` war im ZIP enthalten und enthält einen Google-Books-Key. Der Wert wurde hier bewusst nicht dokumentiert.
  - `.gitignore` in `Shelf Notes/.gitignore` ignoriert `config/secrets.xcconfig`.
- SPM:
  - Keine `XCRemoteSwiftPackageReference` im Projekt gefunden.

---

## Conventions

### Persistenz

- Für CloudKit-kompatible SwiftData-Modelle keine Unique Constraints verwenden.
- Beziehungen optional halten und nil-safe Accessors anbieten.
- Persistierte Enums über stabile Raw Values speichern.
- Neue nicht-optionale Felder immer mit Defaults versehen.
- Saves über `modelContext.saveWithDiagnostics()` bevorzugen.
- Book-Collection-Mutationen über `CollectionMembershipMutation` durchführen.

### UI / SwiftUI

- Große Views werden per Extension-Dateien gesplittet, zum Beispiel `LibraryView+Grid.swift`, `BookDetailView+Cards.swift`.
- Rechenlogik aus Views in pure Builder oder Stores ziehen.
- Scroll-Zellen sollen side-effect-free sein; `LibraryRowCoverView` ist ein gutes Muster.
- Keine SwiftData-Saves aus Row-Renderpfaden.
- `@SceneStorage` wird genutzt, um Tab- und Settings-Navigation stabil zu halten.

### Concurrency

- ModelContext-Arbeit ist MainActor-gebunden.
- Teure Value-Berechnungen werden über Snapshots und `Task.detached` ausgelagert, zum Beispiel Stats.
- Tasks bei View-Disappear oder Filterwechsel canceln, wie in `BookImportViewModel+Tasks.swift`.
- Bei langen Loops regelmäßig Cancellation prüfen.

### Sync / CloudKit

- Store-Modi nicht vermischen: CloudKit und Local-only sind bewusst getrennt.
- Jeder Sync-relevante Model Change braucht Defaults, Migration/Repair-Plan und Tests.
- Cover-Sync-Policy beachten: Thumbnail sync, Full-res local.

---

## How to work on this project

### Setup Steps

1. `Shelf Notes.xcodeproj` in Xcode öffnen.
2. Lokale `Shelf Notes/config/secrets.xcconfig` bereitstellen oder aus sicherer Quelle generieren. Den echten Google-Books-Key nicht commiten und nicht in ZIPs teilen.
3. Signing prüfen: Team, iCloud Container `iCloud.de.marcfechner.Shelf-Notes`, App Group `group.de.marcfechner.Shelf-Notes`.
4. App-Target `Shelf Notes` wählen und auf Simulator oder Gerät starten.
5. Für CloudKit-Szenarien mit einem iCloud-Account testen; Local-only-Fallback separat testen.
6. Unit Tests in `Shelf NotesTests` ausführen, besonders nach Änderungen an Buildern, CSV, Tags, Stats, Challenges oder SwiftData-Mutationen.

### Feature hinzufügen

- Datenmodell zuerst prüfen:
  - Muss ein neues Feld in `Book`, `ReadingSession`, `BookCollection`, `ReadingGoal` oder `ChallengeRecord`?
  - Hat es einen Default?
  - Ist es CloudKit-kompatibel?
  - Braucht es Migration, Repair oder Dedupe?
- Danach Flow wählen:
  - Library/Detail: unter `Shelf Notes/LibraryView/` oder `Shelf Notes/BookDetail/`.
  - Progress/Stats/Goals/Challenges: unter dem jeweiligen Modul.
  - Import: `AddBook`, `BookImport`, `GoogleVolumeBookMapper`.
  - Settings: `Shelf Notes/Settings/`.
- Rechenlogik als pure Builder schreiben und mit Unit Tests absichern.
- SwiftData-Saves über `saveWithDiagnostics()` ausführen.
- Bei Collection-Membership `CollectionMembershipMutation` nutzen.
- Bei Cover-Änderungen `CoverThumbnailer` und Cache-Invalidation prüfen.
- Bei Navigation neue Ziele lokal im Feature halten; Root nur erweitern, wenn ein neuer Tab oder globaler Sheet nötig ist.

---

## Quick Wins

1. `ModelContainerFactory` und `AppBootstrapper` aus `Shelf Notes/AppContainerHostView.swift` nach `Shelf Notes/Persistence/` splitten.
2. `Shelf Notes/config/secrets.xcconfig` nie in Analyse-/Release-ZIPs packen und Key rotieren, falls das ZIP extern geteilt wurde.
3. `IPHONEOS_DEPLOYMENT_TARGET = 26.0` bestätigen oder korrigieren.
4. `BookCoverThumbnailView` an die off-main Decode-Strategie von `LibraryRowCoverView` angleichen.
5. Body-nahe O(n)-Mapps in `LibraryView.swift` durch einen gecachten `booksByID`/Display-Store ersetzen.
6. Max-Size oder LRU für `ImageDiskCache` einführen.
7. Template-/Platzhalterdateien in `ShelfNotesLiveActivity/ShelfNotesLiveActivity.swift` und `ShelfNotesLiveActivity/ShelfNotesLiveActivityControl.swift` entfernen oder finalisieren.
8. CloudKit-/Local-only-Divergenz als sichtbaren Support-Artikel oder In-App-Hinweis dokumentieren.
9. Migration-Checklist für SwiftData/CloudKit-Felder in `ARCHITECTURE_NOTES.md` oder eigenem Doc pflegen.
10. Performance-Baseline für große Bibliotheken definieren und mit Library/Stats/Tags testen.

---

## Open Questions

- **UNKNOWN**: Ist iOS 26.0 als Deployment Target beabsichtigt?
- **UNKNOWN**: Welche Zielgröße hat die Bibliothek, zum Beispiel 500, 5.000 oder 50.000 Bücher?
- **UNKNOWN**: Soll Local-only-Datenbestand jemals in CloudKit migriert oder importiert werden?
- **UNKNOWN**: Gibt es definierte CloudKit-Konfliktregeln für gleichzeitige Multi-Device-Edits?
- **UNKNOWN**: Sollen Full-res User-Cover künftig geräteübergreifend synchronisiert werden?
- **UNKNOWN**: Gibt es produktive SwiftData/CloudKit-Store-Snapshots für Migrationstests?
- **UNKNOWN**: Ist iPad first-class oder nur über Universal Target mitlaufend?
- **UNKNOWN**: Welche Observability wird in Release-Builds akzeptiert, besonders für Sync-Probleme?
- **UNKNOWN**: Sind Share/Collaboration-Flows geplant? Im Scan wurden keine expliziten Collaboration-Modelle gefunden.
