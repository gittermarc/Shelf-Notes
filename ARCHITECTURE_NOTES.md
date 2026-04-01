# ARCHITECTURE_NOTES.md

## Scope

Diese Notizen basieren auf dem gelieferten ZIP-Projektstand. Aussagen sind nur dann als Fakt formuliert, wenn sie direkt im Code oder im Xcode-Projekt sichtbar waren. Alles, was nicht belastbar aus dem Scan hervorgeht, ist als **UNKNOWN** markiert und am Ende gesammelt.

---

## Big Files List — Top 15 nach Zeilen

> Zeilenzahlen stammen aus dem gescannten Swift-Quellbestand des App-Targets.

1. **641** — `Shelf Notes/Stats/StatisticsSnapshotBuilder.swift`  
   **Zweck:** zentrale Statistikaggregation und Cache-Building für die Stats-Ansicht.  
   **Warum riskant:** viel Domänenlogik in einer Datei; hohe Änderungskosten; potenzieller CPU-Hotspot, wenn Rebuilds häufig angestoßen werden.

2. **435** — `Shelf Notes/Challenges/ChallengeEngine+Compute.swift`  
   **Zweck:** value-only Compute-Logik für Challenge-Generierung und Fortschritt.  
   **Warum riskant:** großer Algorithmusblock; Änderungen an Balancing/Perioden/Units sind fehleranfällig; positiv ist, dass die Datei SwiftData-frei ist.

3. **428** — `Shelf Notes/Book.swift`  
   **Zweck:** zentrales Hauptmodell inklusive Domain-Logik, Migration, Cover-Helfern und Ratings.  
   **Warum riskant:** sehr hohe Verantwortungsdichte; Modell-, Migrations-, Medien- und UI-nahe Hilfslogik vermischt sich.

4. **426** — `Shelf Notes/Stats/StatisticsView+Sections.swift`  
   **Zweck:** große UI-Sektionensammlung der Statistik-Ansicht.  
   **Warum riskant:** viel SwiftUI-Layout in einer Datei; hoher Compiler-/Wartungsdruck; UI-Änderungen und Datenabhängigkeiten liegen nah beieinander.

5. **421** — `Shelf Notes/Stats/StatisticsView+Data.swift`  
   **Zweck:** Statistik-Helfer, Filterung, Monats-/Jahresdatenaufbereitung.  
   **Warum riskant:** weitere Aggregationslogik im View-Kontext; Gefahr, dass Compute in UI-nahe Schichten diffundiert.

6. **418** — `Shelf Notes/LibraryView/LibraryView+Header.swift`  
   **Zweck:** Header, Counts, Quick-Sort, Hero-Text, Header-bezogene Derived State.  
   **Warum riskant:** Bibliotheks-Root ist bereits komplex; Header-Logik ist sichtbar nur ein Teil einer größeren Zustandsmaschine.

7. **373** — `Shelf Notes/Stats/StatisticsView+Heatmap.swift`  
   **Zweck:** Heatmap-Berechnung und -Darstellung.  
   **Warum riskant:** rechenintensive und visuelle Verantwortung in derselben Datei; anfällig für UI-Ruckler bei Recompute.

8. **364** — `Shelf Notes/CSVImportExportView.swift`  
   **Zweck:** CSV Import/Export inkl. Parsing, Duplicate-Handling, Google-Books-Fetch und Persistierung.  
   **Warum riskant:** UI, File-I/O, Netzwerk, Persistenz und Fortschrittsanzeige in einem Baustein.

9. **357** — `Shelf Notes/BookDetail/BookDetailView+Bindings.swift`  
   **Zweck:** Bindings und abgeleitete Properties des Detail-Screens.  
   **Warum riskant:** Zustandsschreibzugriffe und Persistenz-triggernde Bindings bündeln sich hier; Detail-Screen-Verhalten wird schwerer testbar.

10. **356** — `Shelf Notes/LibraryView/LibraryRowCoverView.swift`  
    **Zweck:** performanter Cover-Renderer für Liste/Grid inklusive Thumbnail-/High-Res-Logik.  
    **Warum riskant:** Scroll-Path-relevant; viele Async-/Cache-/Decode-Aspekte; Fehler hier spürt man sofort in der Bibliothek.

11. **355** — `Shelf Notes/ForYouSeedBuilder.swift`  
    **Zweck:** Personalisierte Inspirations-Queries aus Bibliotheksdaten.  
    **Warum riskant:** textuelle Heuristiken, Tokenisierung und Normalisierung wachsen erfahrungsgemäß unkontrolliert.

12. **354** — `Shelf Notes/Settings/AppearanceSettings/AppearancePreferences.swift`  
    **Zweck:** zentrales Set an Appearance-Keys und Enums.  
    **Warum riskant:** starker `UserDefaults`-/Key-Sprawl; Änderungen wirken appweit; gute Zentralisierung, aber großes Blast Radius.

13. **342** — `Shelf Notes/CachedAsyncImage.swift`  
    **Zweck:** lokaler Bildcache, Diskcache, UserCoverStore, AsyncImage-Infrastruktur.  
    **Warum riskant:** mehrere Verantwortungen in einer Datei; Medienpfad und Cache-Invariante hängen davon ab.

14. **340** — `Shelf Notes/LibraryView/LibraryView+Grid.swift`  
    **Zweck:** Grid-Darstellung der Bibliothek.  
    **Warum riskant:** primärer Scroll-/Renderpfad mit vielen Appearance-Optionen und Cover-Renderern.

15. **340** — `Shelf Notes/AddBook/AddBookView+Cards.swift`  
    **Zweck:** großer Teil der Add-Book-UI.  
    **Warum riskant:** komplexe Karten-UI; hoher Änderungsdruck, wenn Import-/Add-Flows wachsen.

### Beobachtung

Die größten Dateien konzentrieren sich auf:
- Stats
- Library
- Domain-Hauptmodell
- Import/Cover
- Appearance-Konfiguration

Das ist ein plausibles Bild der echten Risikooberfläche: weniger “App Root”, mehr datenintensive Mittel-/Oberflächen.

---

## Hot Path Analyse

## 1) Rendering / Scrolling

### A. Bibliothek: Filter/Sort/A-Z-Sektionen

**Dateien**
- `Shelf Notes/LibraryView/LibraryView.swift`
- `Shelf Notes/LibraryView/LibraryView+FilteringSorting.swift`
- `Shelf Notes/LibraryView/LibraryView+Grid.swift`
- `Shelf Notes/LibraryView/LibraryRowCoverView.swift`

**Was passiert**
- `LibraryView` hält `@Query(sort: \Book.createdAt, order: .reverse) var books: [Book]`.
- Darüber werden Suchtext, Status, Tag, Notizfilter und Sortierung angewandt.
- Zusätzlich werden A-Z-Sektionen für Titel-Sortierung gebaut.

**Konkreter Hotspot-Grund**
- volle O(n)-Filterung über die Bibliothek
- plus O(n log n)-Sortierung
- plus Alpha-Bucketing
- Trigger auf viele UI-Änderungen (`searchText`, `selectedStatus`, `selectedTag`, `onlyWithNotes`, Sortierung, Layout)

**Positiv**
- Der Code hat das Problem erkannt und `cachedDisplayedBooks`, `cachedCounts`, `cachedAlphaSections` eingeführt (`Shelf Notes/LibraryView/LibraryView.swift`).
- Suche wird per `scheduleDerivedCacheRecomputeDebounced()` entkoppelt.

**Rest-Risiko**
- Die Recompute-Logik läuft weiter auf dem MainActor/UI-nahen Pfad.
- Bei sehr großen Bibliotheken bleibt das ein Skalierungsrisiko.
- `onChange(of: books.count)` reagiert nur auf Count-Änderungen; andere Buchmutationen werden über andere Zustände indirekt eingefangen, aber nicht zentral modelliert.

### B. Bibliotheks-Cover im Scrollpfad

**Dateien**
- `Shelf Notes/LibraryView/LibraryRowCoverView.swift`
- `Shelf Notes/CachedAsyncImage.swift`
- `Shelf Notes/CoverThumbnailer/*`

**Konkreter Hotspot-Grund**
- per-row/per-tile Async-Work (`.task(id: cacheKey)`)
- Bilddecode
- Cache-Lookups
- High-Res-Upgrades auf größeren Oberflächen
- potenziell viele gleichzeitige Tasks im Scrollpfad

**Positiv**
- dedizierter Thumbnail-Memory-Cache
- off-main Decode-Pfade
- synced Thumbnail als kleine, scrollfreundliche Quelle

**Rest-Risiko**
- Der Renderpfad ist performant gedacht, aber komplex. Das ist klassischer “works until a corner case explodes”-Code.
- Jede Änderung an Cache-Keys, Auflösungslogik oder Task-Lifetime kann Hitches oder Flackern erzeugen.

### C. Statistik-Screen

**Dateien**
- `Shelf Notes/Stats/StatisticsView.swift`
- `Shelf Notes/Stats/StatisticsView+Caching.swift`
- `Shelf Notes/Stats/StatisticsSnapshotBuilder.swift`
- `Shelf Notes/Stats/StatisticsView+Heatmap.swift`

**Was passiert**
- `StatisticsView` baut Signaturen über `books`.
- Zwei `.task(id:)`-Pfade aktualisieren `statsCache` und `heatmapCache`.

**Konkreter Hotspot-Grund**
- große Aggregationen über die komplette Bibliothek
- Heatmap-Berechnung
- Snapshot-Building
- Recompute aktuell ohne explizites `Task.detached`

**Wichtiger Punkt**
- `await Task.yield()` hilft nur beim “UI erst rendern”.
- Das verlagert CPU-Arbeit **nicht** automatisch off-main.

**Rest-Risiko**
- MainActor contention
- spürbare UI-Hänger bei großem Bestand oder häufigen Mutationen
- mehrere große Stats-Dateien erhöhen Refactor-Risiko

### D. Buchdetail lädt komplette Bibliothek für Tags

**Datei**
- `Shelf Notes/BookDetail/BookDetailView.swift`

**Konkreter Hotspot-Grund**
- `updateTagsIndexModelFromLibrary()` macht `modelContext.fetch(FetchDescriptor<Book>())`
- dieser Pfad wird in `.task(id: tagsIndexTaskKey)` aufgerufen
- Trigger ist aktuelles Buch / aktuelle Tags, aber die Arbeit lädt die **gesamte Bibliothek**

**Warum das weh tut**
- Detail-Screen sollte idealerweise lokal zum aktiven Buch arbeiten
- hier hängt ein library-wide Fetch an einer Detail-Interaktion
- das ist unnötige Kopplung zwischen Detail und globalem Index

### E. Timeline-Rebuild

**Dateien**
- `Shelf Notes/Timeline/ReadingTimelineView.swift`
- `Shelf Notes/Timeline/ReadingTimelineViewModel.swift`

**Konkreter Hotspot-Grund**
- `vm.setBooks(finishedBooks)` baut bei Signaturänderung die komplette Timeline neu
- Sortierung aller Einträge
- Gruppierung nach Jahren
- Year-Stats-Aufbau
- zusätzliche Auto-Highlight-Logik beim Scrollen

**Bewertung**
- für moderate Datenmengen okay
- bei sehr großer Historie ein Kandidat für inkrementelle Indizes oder persistierten Derived Snapshot

### F. Progress Hub

**Dateien**
- `Shelf Notes/ProgressHub/ProgressHubView.swift`
- `Shelf Notes/ProgressHub/ProgressHubMetricsModel.swift`

**Konkreter Hotspot-Grund**
- Recompute über `books`, `goals`, `sessions`
- Scans über Sessions für Last-7-Days/Streak

**Positiv**
- Input-Token-Pattern ist sauber
- Scope ist kleiner als im Statistik-Screen
- gute Blaupause für weitere “kleine Snapshot”-Pfade

---

## 2) Sync / Storage

### A. Bootstrap-Pfad

**Dateien**
- `Shelf Notes/Shelf_NotesApp.swift`
- `Shelf Notes/AppContainerHostView.swift`
- `Shelf Notes/RootView.swift`

**Ablauf**
- App startet
- `AppBootstrapper` versucht CloudKit-Store
- bei Erfolg:
  - `RootView` erhält `modelContainer`
  - `CollectionMembershipRepair.repairIfNeeded(...)`
  - `ChallengeEngine.ensureCurrentChallengesAndRefreshCompletion(...)`
- parallel/anschließend startet `RootView` weitere Tasks:
  - `ReadingStatusMigrator.migrateIfNeeded(...)`
  - Cover-Backfill-Scheduling

**Konkreter Hotspot-Grund**
- mehrere potenziell teure Startarbeiten nahe beieinander
- Store-Init
- Vollfetch-Reparaturen
- Challenge Snapshotting
- Backfill-Scheduling

**Risiko**
- längerer Cold Start
- schwer reproduzierbare Start-Ruckler
- Mehrfacharbeit bei “erstes Öffnen nach Update” oder großem Legacy-Bestand

### B. Store Separation: Cloud vs Local

**Datei**
- `Shelf Notes/AppContainerHostView.swift`

**Stärke**
- absichtliche Trennung von `ShelfNotesCloud.store` und `ShelfNotesLocal.store`
- verhindert stillen Datenmischmasch

**Risiko / Edge Case**
- Nutzer können in `localOnly` einen separaten Datenstand erzeugen
- Rückwechsel zu CloudKit bedeutet nicht automatisch Merge
- ob es eine UX für diesen Übergang gibt, ist begrenzt
- das Verhalten ist technisch sauber, aber UX-seitig erklärungsbedürftig

### C. SwiftData ohne expliziten Versioned Migration Plan

**Dateien**
- keine `VersionedSchema` / `SchemaMigrationPlan` gefunden
- ad-hoc Runtime-Migrationen/Reparaturen:
  - `Shelf Notes/Book.swift`
  - `Shelf Notes/CollectionMembershipRepair.swift`

**Konkreter Hotspot-Grund**
- schema-nahe Änderungen werden aktuell eher über Laufzeit-Reparatur und Feld-Migrationen abgefangen
- das skaliert nur begrenzt
- bei mehr Modellen/Beziehungen steigt Risiko für Datenmigrationsfehler

### D. Cover-Sync und Medienstrategie

**Dateien**
- `Shelf Notes/Book.swift`
- `Shelf Notes/CachedAsyncImage.swift`
- `Shelf Notes/CoverThumbnailer/*`

**Stärke**
- kleine Thumbnails synchronisieren, Full-Res lokal halten
- das ist für CloudKit-Payloads vernünftig

**Rest-Risiko**
- Cover-Backfill, Remote Fetch, lokale Disk-Dateien, Thumbnail-Apply und UI-Load verteilen sich über mehrere Dateien
- Invalidation/Consistency ist nicht an einer Stelle zentral erklärt
- potentiell schwer zu debuggen, wenn “Cover auf Gerät A da, auf Gerät B unscharf/fehlend”

### E. Sync-Diagnose ist heuristisch

**Dateien**
- `Shelf Notes/SyncDiagnostics.swift`
- `Shelf Notes/SyncDiagnosticsView.swift`
- `Shelf Notes/ModelContext+Diagnostics.swift`

**Wichtige Einordnung**
- Die App misst lokales Save, Netzwerk, CK-Account-Status.
- Sie misst **nicht** echten SwiftData/CloudKit-Sync-Fortschritt oder serverseitige Zustände.
- Das ist gut für Support, aber kein echter Sync-Monitor.

### F. Remote Notifications Background Mode

**Datei**
- `Shelf Notes/Info.plist`

**Fakt**
- `UIBackgroundModes` enthält `remote-notification`.

**UNKNOWN**
- ein klarer App-Code-Pfad für Remote-Push-Handling wurde im gescannten Stand nicht gefunden.

---

## 3) Concurrency

### A. Gute Muster

#### ChallengeEngine verwendet value-only Snapshots + detached Compute

**Dateien**
- `Shelf Notes/Challenges/ChallengeEngine.swift`
- `Shelf Notes/Challenges/ChallengeEngine+Compute.swift`

**Warum gut**
- Fetch auf MainActor
- schwere Compute-Arbeit in `Task.detached(priority: .utility)`
- `ChallengeEngine+Compute.swift` ist SwiftData-frei

**Das ist ein Muster, das man kopieren sollte.**

#### Import-Suche schützt sich gegen stale Ergebnisse

**Datei**
- `Shelf Notes/BookImport/BookImportView/BookImportViewModel+Tasks.swift`

**Warum gut**
- `searchGeneration`
- explizite Cancel-Pfade (`cancelSearchWork`)
- getrennte Tasks für Debounce / Search / Load More

### B. Problematische oder fragilere Muster

#### Stats-Compute nicht klar off-main

**Dateien**
- `Shelf Notes/Stats/StatisticsView.swift`
- `Shelf Notes/Stats/StatisticsView+Caching.swift`

**Problem**
- CPU-intensive Aggregation wird aus `.task(id:)` gestartet, aber nicht explizit auf einen detached/value-only Worker verlagert.

#### CSV-Import läuft UI-nah

**Datei**
- `Shelf Notes/CSVImportExportView.swift`

**Problem**
- `runImport(from:)` ist `@MainActor`
- darin passieren:
  - `Data(contentsOf:)`
  - row-weises Parsing
  - Netzwerkaufrufe
  - Inserts/Saves
  - Cover-Backfill
- technisch funktional, architektonisch ein ziemlicher Bauchladen

#### Root Cover Backfill Task

**Datei**
- `Shelf Notes/RootView.swift`

**Problem**
- `Task(priority: .utility) { @MainActor in ... }`
- Priorität ist nett, aber durch `@MainActor` bleibt die Closure actor-seitig gebunden
- ob die eigentliche Last sauber off-main landet, hängt an den darunterliegenden Implementierungen

#### Save-Diagnostics fire-and-forget

**Datei**
- `Shelf Notes/ModelContext+Diagnostics.swift`

**Problem**
- `saveWithDiagnostics()` startet nach Save jeweils ein fire-and-forget `Task { @MainActor in ... }`
- das ist okay für kleine Breadcrumbs, aber nicht ideal, wenn man künftig mehr Logging/Tracing daran hängt

### C. Task Lifetimes / Cancellation

**Stellen**
- `Shelf Notes/BookImport/BookImportView/BookImportViewModel+Tasks.swift`
- `Shelf Notes/LibraryView/LibraryView.swift`

**Bewertung**
- Import-Flow: explizite Cancellations vorhanden, gut
- Library: `pendingRecomputeTask` für debounced Search okay
- Stats: `.task(id:)` basiert auf SwiftUI-Lifetimes, was grundsätzlich okay ist
- Globale Task-Lifetime-Strategie projektweit:
  - nicht einheitlich
  - kein generisches Abstraktionsmuster sichtbar

---

## Refactor Map

## 1) Konkrete Splits

### A. `StatisticsSnapshotBuilder.swift` zerlegen

**Heute**
- `Shelf Notes/Stats/StatisticsSnapshotBuilder.swift`

**Vorschlag**
- `StatisticsSnapshotBuilder+Summary.swift`
- `StatisticsSnapshotBuilder+MonthlySeries.swift`
- `StatisticsSnapshotBuilder+TopLists.swift`
- `StatisticsSnapshotBuilder+NerdCorner.swift`
- `StatisticsBookSnapshot.swift` separat halten/neu auslagern, falls noch nicht separat

**Nutzen**
- kleinere Blast Radius
- gezieltere Tests
- leichteres Profiling

### B. `CSVImportExportView.swift` trennen

**Heute**
- UI + Parsing + Duplicate Detection + Remote Fetch + Persistierung + Reporting in einer Datei

**Vorschlag**
- `CSVImportExportView.swift` (UI)
- `CSVImportRunner.swift` oder `CSVImportService.swift`
- `CSVImportDuplicateIndex.swift`
- `CSVImportProgress.swift`
- `CSVImportErrorMapper.swift`

**Nutzen**
- UI wird schlanker
- Import kann besser off-main verlagert werden
- Duplicate-/Matching-Logik wird testbarer

### C. `Book.swift` entlasten

**Heute**
- Modell + Migration + Cover-URL-Helfer + Ratings

**Vorschlag**
- `Book+ReadingStatus.swift`
- `Book+Ratings.swift`
- `Book+CoverCandidates.swift`
- `ReadingStatusMigrator.swift`

**Nutzen**
- Modell wird wieder lesbarer
- CloudKit-Regeln bleiben sichtbar
- Migrationslogik ist separat testbar

### D. `CachedAsyncImage.swift` aufspalten

**Heute**
- ImageMemoryCache
- ImageDiskCache
- UserCoverStore
- CachedAsyncImage
- CoverCandidatesImage

**Vorschlag**
- `ImageMemoryCache.swift`
- `ImageDiskCache.swift`
- `UserCoverStore.swift`
- `CachedAsyncImage.swift`
- `CoverCandidatesImage.swift`

**Nutzen**
- weniger “god file”
- Medienpfad besser nachvollziehbar

### E. Library Derived Data in eigenen Baustein

**Heute**
- `LibraryView.swift` hält Cache-State direkt selbst

**Vorschlag**
- `LibraryDerivedStateBuilder.swift`
- `LibraryDerivedState.swift`
- optional `LibraryDerivedStateModel.swift` (`@MainActor ObservableObject`)

**Nutzen**
- filter/sort/sections werden aus View-State entkoppelt
- leichter testbar
- klarere Invalidation-Regeln

---

## 2) Cache- / Index-Ideen

### A. Globaler Tag-Index statt Full Fetch aus dem Detail

**Ist-Zustand**
- `BookDetailView` lädt die ganze Bibliothek für den Tag-Index

**Vorschlag**
- einen zentralen Tag-Snapshot-/Index-Service einführen
- Invalidation über Bücher-Signatur oder Save-Hook
- Detail-Screen konsumiert nur Snapshot/Index

**Key-Struktur**
- `TagIndexKey = booksSignature`
- optional scoped auf einzelne Bibliotheken/Filter, falls das Projekt das später braucht

### B. Persistierbarer Derived Stats Snapshot

**Ist-Zustand**
- Stats werden bei Bedarf neu berechnet

**Vorschlag**
- in-memory cache reicht zuerst
- später optional persistierbarer Derived Snapshot mit:
  - input signature
  - selected year
  - scope
  - generatedAt

**Wichtig**
- Invalidation muss an echte Datenänderung gebunden sein
- nicht an beliebige View-Rebuilds

### C. Duplicate Index für CSV Import

**Ist-Zustand**
- Sets für ISBNs, Volume IDs und Titel werden pro Importlauf aufgebaut

**Vorschlag**
- eigener `CSVImportDuplicateIndex`
- Vorverarbeitung einmalig
- klar benannte Matching-Regeln

### D. Timeline-Index

**Ist-Zustand**
- `ReadingTimelineViewModel.setBooks(_:)` baut alles neu

**Vorschlag**
- `ReadingTimelineSnapshot`
- optional:
  - `entriesByYear`
  - `yearStats`
  - `sortedEntries`
- Invalidation über task signature

---

## 3) Vereinheitlichungen

### A. Compute-Muster vereinheitlichen

**Vorbild**
- `ChallengeEngine`: Fetch on main, compute detached, apply on main

**Übertragen auf**
- Stats
- CSV Import Matching/Transformation
- Timeline-Building
- Tag-Index-Building

### B. Save-Pfade vereinheitlichen

**Heute**
- viele Stellen verwenden bereits `saveWithDiagnostics()`, gut

**Weiterer Schritt**
- mutierende Feature-Actions noch systematischer über benannte Action-Funktionen laufen lassen
- statt direkt in Bindings / UI-Closures mehrere Modellfelder zu setzen und zu speichern

### C. Preference-Key-Verwaltung

**Heute**
- Appearance zentral, andere `@AppStorage`-Keys verteilt

**Vorschlag**
- weitere Key-Gruppen einführen:
  - `SessionSettingsKey`
  - `ImportSettingsKey`
  - `RootSettingsKey`

### D. Root-/Bootstrap-Jobs orchestration

**Heute**
- Bootstrap, Repair, Challenge-Ensure, Migration und Cover-Backfill hängen verteilt an Root und Container Host

**Vorschlag**
- `StartupWorkCoordinator.swift`
- benennt, ordnet und priorisiert Startarbeiten
- verbessert Observability und Testbarkeit

---

## Risiken & Edge Cases

### A. Datenverlust / Divergenz

- `localOnly` ist absichtlich separater Datenstand.
- Nutzer können dort weiterarbeiten.
- Rückwechsel zu CloudKit führt nicht automatisch zur Datenzusammenführung.
- Technisch sauber, UX-seitig heikel.

### B. Migrationen

- Runtime-Migratoren sind da, aber kein formaler Versioned-Schema-Pfad sichtbar.
- Bei künftigen Schemaänderungen steigt Migrationsrisiko deutlich.

### C. CloudKit-Kompatibilität

- Das Projekt kennt die üblichen SwiftData/CloudKit-Stolpersteine bereits.
- Trotzdem bleiben many-to-many und optionale Beziehungen klassische Problemzonen.
- `CollectionMembershipRepair` existiert genau deshalb.

### D. Medien / Cover

- Thumbnails sind syncbar, Full-Res lokal.
- Das ist sinnvoll.
- Edge Cases:
  - Gerät A hat Full-Res lokal, Gerät B nur Thumbnail
  - Remote Cover wurde gewählt, aber Backfill/Apply ist unvollständig
  - lokale Cache-Löschung vs. persistierte Thumbnail-Quelle

### E. Multi-Device / Offline

- `SyncDiagnostics` erkennt Netzwerk-/iCloud-Signale, aber löst keine Konflikte.
- Conflict Resolution / Merge-Verhalten auf Domänenebene:
  - **UNKNOWN**

### F. Import / Rate Limits / API Errors

- Google Books hängt an einem API-Key.
- Bei Rate Limits oder API-Ausfall hängen Import und Suche sichtbar am externen Dienst.
- Retry-/Backoff-Strategie auf Service-Ebene ist im gescannten Stand nicht prominent.

### G. Live Activity / Extension Coupling

- App Group ID ist hart codiert in `Shelf Notes/Shared/LiveActivity/LiveActivitySharedStore.swift`.
- Das ist okay, aber ein Konfigurationskopplungspunkt zwischen Targets.
- Bundle-/Signing-/App-Group-Drift kann dort schnell hässlich werden.

---

## Observability / Debuggability

## Vorhanden

- `SyncDiagnostics` + `SyncDiagnosticsView`
- `saveWithDiagnostics()` Breadcrumbs
- `GoogleBooksDebugInfo` in `Shelf Notes/GoogleBooksClient.swift`
- nicht-crashender ModelContainer-Failure-Screen in `Shelf Notes/AppContainerHostView.swift`

## Fehlt oder wäre hilfreich

### A. Strukturierte Logs / Signposts

Empfohlene Kandidaten:
- ModelContainer bootstrap duration
- Collection repair duration
- Challenge ensure duration
- Statistics cache rebuild duration
- CSV import duration + rows/sec
- Cover backfill duration + batch metrics
- Library derived-state rebuild duration

### B. Eingrenzbare Fehlerberichte

Sinnvoll wären klar benannte Fehlerdomänen für:
- CSV Import
- Cover Apply / Backfill
- Cloud bootstrap fallback
- Import query/matching

### C. Reproduzierbare Performance-Checks

Hilfreiche manuelle Szenarien:
- Bibliothek mit 1k+ Büchern und aktiver Suche
- Statistik-Screen bei vielen Sessions
- Timeline mit langer Historie
- CSV Import mit 100+ Zeilen
- Cold start nach Legacy-Datenbestand + Cover-Backfill

### D. Debug Screens

Bestehende Diagnose fokussiert auf Sync.  
Weitere Debug-Ansichten wären sinnvoll für:
- Cover cache state
- startup jobs
- stats rebuild inputs/signatures
- import task state

---

## Open Questions

- **UNKNOWN:** Gibt es außerhalb des ZIPs zusätzliche Build-Skripte oder CI-Schritte, die Schema-/Config-Validierung übernehmen?
- **UNKNOWN:** Gibt es eine explizite UX für den Wechsel von `localOnly` zurück nach CloudKit, inklusive Datenerklärung?
- **UNKNOWN:** Wird `UIBackgroundModes = remote-notification` aktuell produktiv verwendet oder ist das ein Vorgriff?
- **UNKNOWN:** Wie wird Konfliktverhalten bei gleichzeitigen Änderungen am selben `Book` auf mehreren Geräten fachlich bewertet?
- **UNKNOWN:** Gibt es bereits bekannte Bibliotheksgrößen/Datensätze, an denen Performance aktiv gemessen wurde?
- **UNKNOWN:** Ist `ContentView.swift` bewusst als Legacy-Kompatibilität behalten oder nur vergessen worden?
- **UNKNOWN:** Gibt es produktive Anforderungen an Mac Catalyst / visionOS / weitere Plattformen?
- **UNKNOWN:** Ist der committed Google-Books-Key absichtlich nur ein Dev-Key, oder ist das schlicht Konfigurationsdrift?

---

## First 3 Refactors I would do (P0)

### 1) Stats-Compute konsequent vom UI-Thread lösen

**Ziel**  
Die Statistikberechnung so umbauen, dass nur Input-Snapshots auf dem MainActor gesammelt werden und die teure Aggregation detached/value-only läuft.

**Betroffene Dateien**
- `Shelf Notes/Stats/StatisticsView.swift`
- `Shelf Notes/Stats/StatisticsView+Caching.swift`
- `Shelf Notes/Stats/StatisticsSnapshotBuilder.swift`
- optional neue Snapshot-Datei für `StatisticsBookSnapshot`

**Risiko**
- mittel
- Stats-Ausgabe kann sich subtil ändern, wenn Snapshot-/Zeitpunktlogik angepasst wird
- gute Tests nötig

**Erwarteter Nutzen**
- weniger MainActor contention
- flüssigerer Stats-Screen
- wiederverwendbares Compute-Muster für andere Features

### 2) CSV Import in UI + Service + DuplicateIndex zerlegen

**Ziel**  
Den CSV-Import von einer UI-lastigen Datei in einen testbaren Import-Runner mit klaren Phasen trennen: parse → dedupe → fetch/match → persist → cover.

**Betroffene Dateien**
- `Shelf Notes/CSVImportExportView.swift`
- neu:
  - `Shelf Notes/CSVImportRunner.swift`
  - `Shelf Notes/CSVImportDuplicateIndex.swift`
  - `Shelf Notes/CSVImportReport.swift`
  - optional `Shelf Notes/CSVImportError.swift`

**Risiko**
- mittel
- Import ist nutzerwirksam; Matching-/Duplicate-Verhalten darf nicht unbemerkt kippen

**Erwarteter Nutzen**
- bessere Testbarkeit
- weniger UI-Blockade
- klarere Fehlerbehandlung
- sauberere Erweiterbarkeit für weitere CSV-Spalten

### 3) Globalen Tag-Index einführen und Detail-Full-Fetch entfernen

**Ziel**  
Den Tag-Index als wiederverwendbaren Snapshot/Index etablieren und die Vollbibliotheks-Fetches aus `BookDetailView` entfernen.

**Betroffene Dateien**
- `Shelf Notes/BookDetail/BookDetailView.swift`
- `Shelf Notes/TagsView/TagsIndexModel.swift`
- `Shelf Notes/TagsView/TagsIndexBuilder.swift`
- optional neu:
  - `Shelf Notes/TagsView/TagsIndexStore.swift`

**Risiko**
- niedrig bis mittel
- Vorschlags-/Tag-Zähler-Logik muss funktional identisch bleiben

**Erwarteter Nutzen**
- weniger unnötige globale Fetches
- geringere Kopplung zwischen Detail und Bibliotheksindex
- klarerer Besitz des Tag-Snapshots
