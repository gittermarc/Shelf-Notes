# ARCHITECTURE_NOTES.md

Stand des Scans: 2026-04-01
Projekt: `Shelf Notes`

## Scope / Vorgehen

Diese Notizen basieren auf dem gescannten Projektstand aus dem hochgeladenen ZIP. Bewertet wurden vor allem:

1. Sync / Storage / Model
2. Entry Points + Navigation
3. große Views / Services
4. Hot Paths für Rendern, Scrollen, Sync und Concurrency
5. konkrete Refactor- und Stabilitätshebel

Nicht behauptet wurde, was im Scan nicht belastbar sichtbar war. Solche Punkte sind als **UNKNOWN** markiert und unten gesammelt.

---

## Big Files List

Top-15 Swift-Dateien nach Zeilen im gescannten Haupttarget.

1. `Shelf Notes/Stats/StatisticsSnapshotBuilder.swift` — ca. **662 Zeilen**
   - Zweck: baut den gesamten Statistik-Cache aus Value-Snapshots.
   - Riskant, weil: Summary, Year-Optionen, Monatsserien, Genre-Parsing, Top-Listen, Nerd-Picks und Formatting in einer Datei zusammenlaufen.

2. `Shelf Notes/Challenges/ChallengeEngine+Compute.swift` — ca. **435 Zeilen**
   - Zweck: pure Business Rules für Challenge-Ziele und Completion-Pläne.
   - Riskant, weil: viele eng gekoppelte Regeln ohne weitere interne Modulgrenzen; Änderungen können leicht Zielwerte oder Reroll-Logik kippen.

3. `Shelf Notes/Book.swift` — ca. **428 Zeilen**
   - Zweck: zentrales Persistenzmodell plus viel Domainlogik.
   - Riskant, weil: Schema, Migrationslogik, Rating-Logik, Cover-URL-Strategie und Relationship-Helper in einer Datei vermischt sind.

4. `Shelf Notes/Stats/StatisticsView+Sections.swift` — ca. **426 Zeilen**
   - Zweck: UI-Komposition für Statistikscreen.
   - Riskant, weil: große SwiftUI-Kompositionsdatei mit vielen Untersektionen; Compile-Time- und Wartungsrisiko.

5. `Shelf Notes/Stats/StatisticsView+Data.swift` — ca. **409 Zeilen**
   - Zweck: Daten- und Ableitungslogik für Statistikscreen.
   - Riskant, weil: zusätzliche Ableitungslogik neben dem eigentlichen Builder; Gefahr von Regelduplikation.

6. `Shelf Notes/Stats/StatisticsHeatmapBuilder.swift` — ca. **406 Zeilen**
   - Zweck: Heatmap-Ranges, Tageszählungen, Streaks, Wochenaggregation.
   - Riskant, weil: fehleranfällige Datumsarithmetik, Session-Splitting und Off-by-one-Risiko.

7. `Shelf Notes/LibraryView/LibraryView+Header.swift` — ca. **396 Zeilen**
   - Zweck: großer Filter-/Header-/Quick-Sort-Block der Bibliothek.
   - Riskant, weil: viele UI-Zustände und Darstellungspfade in einer Datei; hoher Invalidierungsradius.

8. `Shelf Notes/CSVImportExportView.swift` — ca. **364 Zeilen**
   - Zweck: CSV-Dateiimport, Export, Duplikaterkennung, Google-Books-Lookups, Persistenz.
   - Riskant, weil: View, I/O, Netzwerk, Import-Orchestrierung und Persistenz sind in derselben Datei.

9. `Shelf Notes/BookDetail/BookDetailView+Bindings.swift` — ca. **357 Zeilen**
   - Zweck: Bindings, Derived Properties, Mutationslogik für Buchdetail.
   - Riskant, weil: viele setter-getriebene Seiteneffekte inklusive Saves; Änderungen schlagen direkt auf Persistenz und UI durch.

10. `Shelf Notes/LibraryView/LibraryRowCoverView.swift` — ca. **356 Zeilen**
    - Zweck: performantes Cover-Rendering für Listen/Grid.
    - Riskant, weil: asynchrone Bilddekodierung, High-Res-Fallback und Caching in einem Scroll-Hotspot.

11. `Shelf Notes/ForYouSeedBuilder.swift` — ca. **355 Zeilen**
    - Zweck: Heuristiken für Inspirations-/Seed-Queries.
    - Riskant, weil: dichte Normalisierungs- und Query-Heuristik; schwer zu testen, leicht regressionsanfällig.

12. `Shelf Notes/Settings/AppearanceSettings/AppearancePreferences.swift` — ca. **354 Zeilen**
    - Zweck: zentrale Storage-Keys und Appearance-Optionen.
    - Riskant, weil: sehr zentrale Konfigurationsdatei; hoher Merge-Konflikt-Faktor und große Reichweite.

13. `Shelf Notes/CachedAsyncImage.swift` — ca. **342 Zeilen**
    - Zweck: Memory/Disk Cache, User-Cover-Store, Async-Image-Loader.
    - Riskant, weil: Infrastruktur-Querschnitt mit Datei-I/O, Cache-Semantik und UI.

14. `Shelf Notes/LibraryView/LibraryView+Grid.swift` — ca. **340 Zeilen**
    - Zweck: Grid-Layout, Selektionsmodus, Navigation.
    - Riskant, weil: Scroll- und Layout-Hotspot mit vielen UI-Zweigen.

15. `Shelf Notes/AddBook/AddBookView+Cards.swift` — ca. **340 Zeilen**
    - Zweck: große Card-basierte Add-Book-UI.
    - Riskant, weil: große SwiftUI-Datei mit hoher Layout-/Compile-Time-Last, aber wenig funktionaler Trennung.

---

## Hot Path Analyse

### Rendering / Scrolling

#### 1) Bibliothek: synchroner Fallback-Derived-State im Renderpfad

- Dateien:
  - `Shelf Notes/LibraryView/LibraryView.swift`
  - `Shelf Notes/LibraryView/LibraryDerivedStateBuilder.swift`
- Beobachtung:
  - `currentDerivedStateForUI` berechnet synchron einen Fallback über `LibraryDerivedStateBuilder.makeDerivedState(...)`, wenn der gecachte Token nicht passt.
- Konkreter Grund:
  - **heavy sort / filter im Renderpfad**
- Bewertung:
  - Das ist besser als ungezügelte Logik in `body`, aber noch nicht vollständig aus dem UI-Pfad entfernt.
  - Bei großen Bibliotheken oder vielen schnellen Filteränderungen bleibt O(n log n)-Arbeit im UI-Kontext möglich.

#### 2) Bibliothek: breiter Invalidierungsradius

- Dateien:
  - `Shelf Notes/LibraryView/LibraryView.swift`
  - `Shelf Notes/LibraryView/LibraryView+Header.swift`
  - `Shelf Notes/LibraryView/LibraryView+Grid.swift`
  - `Shelf Notes/LibraryView/LibraryView+Lists.swift`
- Beobachtung:
  - Viele Zustände (`searchText`, `selectedStatus`, `selectedTag`, `onlyWithNotes`, `sortField`, `sortAscending`, Layout, Selection-Mode, Appearance-Einstellungen) hängen am selben View-Root.
- Konkreter Grund:
  - **exzessive View invalidation**
- Bewertung:
  - Das Split-by-Extension-Muster hilft Lesbarkeit, reduziert aber nicht automatisch den SwiftUI-Invalidierungsradius.

#### 3) Library Cover Rendering ist technisch gut gelöst, bleibt aber Hotspot

- Dateien:
  - `Shelf Notes/LibraryView/LibraryRowCoverView.swift`
  - `Shelf Notes/CachedAsyncImage.swift`
  - `Shelf Notes/CoverImageLoader.swift`
- Beobachtung:
  - Thumbnail-Dekodierung läuft off-main, Memory-Caches existieren, Grid kann High-Res-Cover bevorzugen.
- Konkreter Grund:
  - **image decode / network image churn im Scrollpfad**
- Bewertung:
  - Das ist bereits deutlich besser als naive `AsyncImage`-Nutzung.
  - Risiko bleibt in Grid-/High-Res-Pfaden und bei großen Bibliotheken.

#### 4) Statistikscreen scannt das gesamte Buchset pro Render-Signatur

- Dateien:
  - `Shelf Notes/Stats/StatisticsView.swift`
  - `Shelf Notes/Stats/StatisticsView+Caching.swift`
- Beobachtung:
  - `booksSignature(_:)` läuft im View-Kontext und iteriert über alle Bücher.
  - Kategorien und Tags werden für die Signatur sortiert.
- Konkreter Grund:
  - **O(n) signature build im Renderpfad**
- Bewertung:
  - Absichtlich flacher als Deep-Session-Scans, aber bei wachsender Bibliothek messbar.
  - Die eigentliche Statistikberechnung ist sauberer ausgelagert als die Signaturbildung.

#### 5) GoalsView rechnet mehrfach über dasselbe `@Query books`

- Datei:
  - `Shelf Notes/GoalsView.swift`
- Beobachtung:
  - `finishedBooksInSelectedYear`, `pagesReadInSelectedYear`, `countedBooksWithPagesInSelectedYear`, `avgPagesPerBookText`, `pagesPerMonthText` hängen alle direkt an `@Query private var books`.
- Konkreter Grund:
  - **repeated whole-array filtering in view properties**
- Bewertung:
  - Solange Bibliothek klein ist, okay.
  - Für größere Datenstände unnötige Wiederholung; prädestiniert für ViewModel oder Shared Index.

#### 6) ProgressHub-Metriken sind gecacht, aber weiter MainActor-gebunden

- Datei:
  - `Shelf Notes/ProgressHub/ProgressHubMetricsModel.swift`
- Beobachtung:
  - Tokenisierung vermeidet unnötige Recomputes.
  - Der Recompute selbst läuft aber auf `@MainActor`.
- Konkreter Grund:
  - **MainActor contention bei O(n)/O(m)-Aggregationen**
- Bewertung:
  - Solide Zwischenlösung.
  - Nicht ideal, wenn Sessions und Bücher stark wachsen.

#### 7) BookDetail-Bindings schreiben direkt ins Modell und speichern unmittelbar

- Dateien:
  - `Shelf Notes/BookDetail/BookDetailView.swift`
  - `Shelf Notes/BookDetail/BookDetailView+Bindings.swift`
  - `Shelf Notes/BookDetail/BookDetailView+Persistence.swift`
- Beobachtung:
  - Mehrere Bindings mutieren direkt `book` und triggern Save-Logik.
- Konkreter Grund:
  - **save side effects in binding setters**
- Bewertung:
  - Einfach für schnelle UI-Umsetzung.
  - Schlechter für Batch-Änderungen, Undo-Semantik und Performance-Transparenz.

#### 8) Timeline ist relativ sauber, aber datenintensiv

- Dateien:
  - `Shelf Notes/Timeline/ReadingTimelineView.swift`
  - `Shelf Notes/Timeline/ReadingTimelineViewModel.swift`
- Beobachtung:
  - Fertige Bücher werden per `@Query` geladen und über ein ViewModel in Timeline-Items transformiert.
- Konkreter Grund:
  - **large horizontal lazy content + derived timeline build**
- Bewertung:
  - Besser gekapselt als GoalsView.
  - Bei sehr großen Libraries bleibt die Timeline ein natürlicher Render-Hotspot.

### Sync / Storage

#### 1) Bootstrap führt Reparatur- und Challenge-Work am Haupt-`ModelContext` aus

- Datei:
  - `Shelf Notes/AppContainerHostView.swift`
- Beobachtung:
  - Nach Container-Ready laufen:
    - `CollectionMembershipRepair.repairIfNeeded(...)`
    - `ChallengeEngine.ensureCurrentChallengesAndRefreshCompletion(...)`
- Konkreter Grund:
  - **launch-time main-context work**
- Bewertung:
  - Architektonisch sinnvoll, aber Launch-Pfad wird schwerer.

#### 2) Speichern ist stark verteilt und oft UI-getrieben

- Dateien:
  - quer durchs Projekt, z. B. `GoalsView.swift`, `CollectionDetailView.swift`, `BookDetailView+Bindings.swift`, `CSVImportExportView.swift`
  - Save-Wrapper in `Shelf Notes/ModelContext+Diagnostics.swift`
- Beobachtung:
  - Viele kleine UI-Aktionen rufen direkt `saveWithDiagnostics()`.
- Konkreter Grund:
  - **high save frequency / save orchestration spread across views**
- Bewertung:
  - Hilft gegen Datenverlust.
  - Erschwert Kontrolle über Save-Batching und macht Performance lokal schwerer einschätzbar.

#### 3) CSV-Import blockiert als MainActor-Orchestrator einen langen Pfad

- Datei:
  - `Shelf Notes/CSVImportExportView.swift`
- Beobachtung:
  - `runImport(from:)` ist `@MainActor`.
  - Es führt in einer Schleife aus:
    - CSV decode
    - Duplikatprüfung
    - Google-Books-Request
    - `modelContext.insert`
    - `saveWithDiagnostics()`
    - `CoverThumbnailer.backfillThumbnailIfNeeded(...)`
- Konkreter Grund:
  - **long-running import loop on MainActor**
- Bewertung:
  - Das ist einer der klarsten technischen Hotspots des Projekts.

#### 4) Cover-Backfill ist defensiv, aber weiterhin daten- und I/O-lastig

- Dateien:
  - `Shelf Notes/RootView.swift`
  - `Shelf Notes/CoverThumbnailer/CoverThumbnailer+Backfill.swift`
- Beobachtung:
  - Backfill ist verzögert, batchweise und mit `Task.yield()` / Sleep entschärft.
- Konkreter Grund:
  - **background-ish batch work against main-bound SwiftData context**
- Bewertung:
  - Gut entschärft.
  - Trotzdem potenziell spürbar bei großen Bibliotheken und vielen Cover-Lücken.

#### 5) Local-only-Fallback erzeugt bewusst Daten-Divergenz

- Datei:
  - `Shelf Notes/AppContainerHostView.swift`
- Beobachtung:
  - CloudKit- und Local-only-Store sind strikt getrennt.
- Konkreter Grund:
  - **intentional multi-store divergence**
- Bewertung:
  - Das ist architektonisch sauberer als stilles Mischen.
  - Braucht aber sehr klare UX und Dokumentation, weil Nutzer sonst zwei getrennte Welten erzeugen können.

#### 6) Keine explizite SwiftData-Migrationsarchitektur gefunden

- Dateien:
  - keine `SchemaMigrationPlan`-/`VersionedSchema`-Treffer im Scan
- Beobachtung:
  - Migrationen laufen aktuell punktuell als Datenrepair/Backfill.
- Konkreter Grund:
  - **migration strategy implicit / ad hoc**
- Bewertung:
  - Für frühe Projektstände okay.
  - Bei künftigen Schemaänderungen riskant.

### Concurrency

#### 1) Statistik-Pipeline: gutes Muster mit Value-Snapshot + Detached Tasks

- Dateien:
  - `Shelf Notes/Stats/StatisticsComputePipeline.swift`
  - `Shelf Notes/Stats/StatisticsSnapshotBuilder.swift`
  - `Shelf Notes/Stats/StatisticsHeatmapBuilder.swift`
- Beobachtung:
  - Bücher werden in value-only `StatisticsSourceSnapshot` überführt.
  - Rechenlast läuft in `Task.detached(priority: .utility)`.
- Konkreter Grund:
  - **positive pattern: heavy compute off-main**
- Bewertung:
  - Einer der besseren Architekturpfade im Projekt.
  - Ausbaufähig durch Wiederverwendung desselben Snapshot-Indexes für andere Features.

#### 2) ChallengeEngine nutzt denselben guten Grundgedanken

- Dateien:
  - `Shelf Notes/Challenges/ChallengeEngine.swift`
  - `Shelf Notes/Challenges/ChallengeEngine+Snapshot.swift`
  - `Shelf Notes/Challenges/ChallengeEngine+Compute.swift`
- Beobachtung:
  - Fetch am `ModelContext`, Compute off-main auf Snapshots.
- Konkreter Grund:
  - **value snapshot + detached compute**
- Bewertung:
  - Gute Richtung.
  - Snapshot-Build selbst bleibt an SwiftData gebunden.

#### 3) BookImportViewModel hat saubere Task-Handles, aber manuelle Komplexität

- Dateien:
  - `Shelf Notes/BookImport/BookImportView/BookImportViewModel.swift`
  - `Shelf Notes/BookImport/BookImportView/BookImportViewModel+Tasks.swift`
- Beobachtung:
  - Separate Handles für Search, Load More, Debounced Refresh und Undo-Hide.
  - Generationszähler gegen stale results.
- Konkreter Grund:
  - **manual task lifetime management**
- Bewertung:
  - Technisch ordentlich.
  - Komplexität sitzt aber stark im ViewModel und ist nicht zentral abstrahiert.

#### 4) ReadingTimerManager ist funktionsreich, aber schwerer zu beweisen

- Dateien:
  - `Shelf Notes/BookDetail/Sessions/ReadingTimerManager/*`
  - `Shelf Notes/BookDetail/Sessions/LiveActivity/*`
- Beobachtung:
  - Manuelles `objectWillChange.send()` wird zusätzlich zu `@Published` verwendet.
  - Persistence, Background-Auto-Stop, Live Activity und Shared Store laufen zusammen.
- Konkreter Grund:
  - **manual publisher signaling + cross-process state sync**
- Bewertung:
  - Verständlich aus Stabilitätsgründen.
  - Erhöht aber die kognitive Last und die Gefahr subtiler State-Synchronisationsfehler.

#### 5) SyncDiagnostics ist globaler MainActor-Singleton

- Datei:
  - `Shelf Notes/SyncDiagnostics.swift`
- Beobachtung:
  - Singleton mit `NWPathMonitor`, CloudKit-Calls und persistierter Diagnostik.
- Konkreter Grund:
  - **global singleton + async side effects**
- Bewertung:
  - Für Debuggability praktisch.
  - Für Tests und Lifecycle-Kontrolle weniger ideal.

---

## Refactor Map

### Konkrete Splits

#### A) `Book.swift` auseinanderziehen

Aktuell mischt `Shelf Notes/Book.swift` zu viele Verantwortungen.

Empfohlene Zielstruktur:

- `Shelf Notes/Book.swift`
  - nur `@Model`-Schema + `init`
- `Shelf Notes/Book+Status.swift`
  - `ReadingStatus`, Status-Helper
- `Shelf Notes/ReadingStatusMigrator.swift`
  - One-Time-Migration
- `Shelf Notes/Book+Ratings.swift`
  - User-Rating-Helper
- `Shelf Notes/Book+Collections.swift`
  - Collection-Helper
- `Shelf Notes/Book+CoverURLs.swift`
  - Cover-Kandidaten / PersistResolvedURL / OpenLibrary-Fallback
- optional: `Shelf Notes/Book+ReadingProgress.swift`

Nutzen:

- geringere Merge-Konflikte
- weniger Risiko bei Model-Schema-Änderungen
- bessere Testbarkeit einzelner Domain-Regeln

#### B) `StatisticsSnapshotBuilder.swift` nach Verantwortungen splitten

Empfohlene Zielstruktur:

- `StatisticsSnapshotBuilder.swift`
  - nur Orchestrierung / `makeStatsCache`
- `StatisticsSummaryBuilder.swift`
- `StatisticsMonthlySeriesBuilder.swift`
- `StatisticsGenreParser.swift`
- `StatisticsTopListsBuilder.swift`
- `StatisticsNerdPicksBuilder.swift`
- `StatisticsFormatters.swift`

Nutzen:

- weniger rule coupling
- Genre-/Subgenre-Parsing separat testbar
- schnellere Änderungen an Teilbereichen

#### C) `CSVImportExportView.swift` von UI trennen

Empfohlene Zielstruktur:

- `CSVImportExportView.swift`
  - nur Form/UI/Progress-Anzeige
- `CSVImportExportViewModel.swift`
  - UI-State, Progress, Resultat
- `CSVImportExecutor.swift`
  - Row Loop, Google-Books-Lookups, Duplicate-Strategie
- `CSVImportDuplicateIndex.swift`
  - Vorindizierung bestehender Titel/ISBN/VolumeIDs
- `CSVExportBuilder.swift`
  - Exportaufbau

Nutzen:

- wichtigster Responsiveness-Hebel
- deutlich besser testbar
- einfachere Batch-/Parallelisierungsoptionen

#### D) `BookDetailView+Bindings.swift` fachlich trennen

Mögliche Splits:

- `BookDetailView+StatusBindings.swift`
- `BookDetailView+CollectionBindings.swift`
- `BookDetailView+RatingBindings.swift`
- `BookDetailView+MetadataDerived.swift`

Nutzen:

- weniger versteckte Save-Seiteneffekte pro Datei
- klarere Verantwortlichkeiten

#### E) `AppearancePreferences.swift` entschlacken

Mögliche Splits:

- `AppearanceStorageKeys.swift`
- `AppAppearanceOptions.swift`
- `LibraryAppearanceOptions.swift`

Nutzen:

- zentraler Konfigurations-Hotspot wird kleiner
- weniger Kollisionen bei paralleler Arbeit

### Cache- / Index-Ideen

#### 1) Gemeinsamer Analytics-Snapshot für mehrere Features

Betroffene Features:

- `Shelf Notes/ProgressHub/ProgressHubMetricsModel.swift`
- `Shelf Notes/GoalsView.swift`
- `Shelf Notes/Stats/StatisticsView+Caching.swift`
- `Shelf Notes/Stats/StatisticsSnapshotBuilder.swift`
- `Shelf Notes/Stats/StatisticsHeatmapBuilder.swift`
- `Shelf Notes/Challenges/ChallengeEngine+Snapshot.swift`

Idee:

- Einen gemeinsamen `BookAnalyticsSnapshot` oder `ReadingAnalyticsIndex` einführen.
- Inhalt könnte sein:
  - finished books by year
  - pages by year/month
  - normalized session day index
  - streak-ready day sets
  - top tag/category counters

Nutzen:

- vermeidet doppelte Vollscans über Bücher/Sessions
- vereinheitlicht abgeleitete Semantik
- reduziert Logikduplikate zwischen Goals, ProgressHub, Stats und Challenges

#### 2) Session-Day-Index für Heatmap / Streak / Challenges

Dateien:

- `Shelf Notes/Stats/StatisticsHeatmapBuilder.swift`
- `Shelf Notes/ProgressHub/ProgressHubMetricsModel.swift`
- `Shelf Notes/Challenges/ChallengeEngine+Snapshot.swift`

Idee:

- Einmal aus `ReadingSession` einen Tag-Index bauen:
  - `day -> minutes/pages/sessions`
- Dann dieselben Daten für:
  - letzte 7 Tage
  - current streak
  - Heatmap
  - Challenge-Fortschritt

Nutzen:

- deutlich weniger doppelte Datumslogik
- weniger Off-by-one-Risiko

#### 3) Duplicate Index für Import/CSV wiederverwenden

Dateien:

- `Shelf Notes/CSVImportExportView.swift`
- `Shelf Notes/BookImport/BookImportView/BookImportViewModel+LibraryIndex.swift`

Idee:

- dieselbe Library-Index-Strategie für CSV und Google-Import verwenden.

Nutzen:

- eine Duplikatdefinition statt zwei ähnlicher Pfade
- weniger Divergenz bei ISBN-/VolumeID-/Titelabgleich

### Vereinheitlichungen

#### 1) Service-Protokolle für externe Systeme

Kandidaten:

- `GoogleBooksClient`
- StoreKit-/Pro-Pfade in `ProManager`
- evtl. Sync-Diagnostik-Zugriffe

Nutzen:

- Tests ohne echte Netz-/StoreKit-Abhängigkeit
- einfachere Simulation von Fehlerfällen

#### 2) Gemeinsames Signature-/Token-Muster dokumentieren

Es gibt bereits gute, aber verstreute Muster:

- `TagsIndexStore.taskSignature(...)`
- `LibraryDerivedInputToken`
- `StatisticsStatsCacheKey`
- `StatisticsHeatmapCacheKey`
- `ProgressHubMetricsModel.InputToken`
- `ReadingTimelineViewModel.taskSignature(...)`

Idee:

- Muster dokumentieren oder technisch vereinheitlichen.

Nutzen:

- weniger ad-hoc Invalidierungslogik
- bessere Konsistenz in neuen Features

#### 3) Save-Boundaries schärfen

Aktueller Zustand:

- viele Views speichern direkt und sofort.

Idee:

- Save-Bündelung an klaren Boundaries:
  - Form verlassen
  - Sheet bestätigen
  - Batch-Import-Runde abgeschlossen

Nutzen:

- weniger Save-Churn
- klarere Performance- und Fehleranalyse

---

## Risiken & Edge Cases

### Datenverlust / Datenabweichung

- `Local-only` und `CloudKit` sind absichtlich getrennte Stores.
  - Risiko: Nutzer erzeugen zwei voneinander getrennte Datenstände.
- Vollauflösende Nutzercover werden lokal gespeichert (`Shelf Notes/CachedAsyncImage.swift`), aber nur Thumbnails synchronisiert.
  - Risiko: auf anderem Gerät fehlt Full-Res-Version.

### Migrationsrisiken

- Keine expliziten SwiftData-Migrationsstufen gefunden.
- Aktuell wird mit punktuellen Repair-/Backfill-Schritten gearbeitet.
- Risiko steigt mit jedem zusätzlichen Persistenzfeld im `Book`-Modell.

### Offline / Multi-Device

- Offline-Saves werden gezählt, aber nicht fachlich auf Konflikte analysiert.
- CloudKit-Konfliktverhalten ist im Projekt nicht explizit modelliert.
- **UNKNOWN**, ob in der Praxis schon Mehrgeräte-Konfliktfälle abgefedert wurden.

### Import / Deduplikation

- CSV-Import nutzt Titel-/ISBN-/VolumeID-Checks.
- Risiko:
  - gleiche Bücher mit leicht abweichendem Titel
  - fehlende ISBN
  - Google liefert andere Titelschreibweise zurück

### Timer / Live Activity

- Timerzustand lebt über App Group `UserDefaults` und Live Activity parallel.
- Risiko:
  - stale shared blobs
  - UI-Zustand und Shared-State driften kurzzeitig auseinander
  - Cross-process-Rennen sind prinzipiell möglich

### Secrets / Build

- `Shelf Notes/config/secrets.xcconfig` enthält den Google-Books-Key im Projektstand.
- Risiko: Key-Leak / unklare Umgebungsgrenzen.

### Background / Remote Notification Capability

- `Shelf Notes/Info.plist` aktiviert `remote-notification`.
- Im gescannten Code wurde kein klarer Empfängerpfad für Remote Notifications gefunden.
- Risiko: unnötige Capability / schwer erklärbares Verhalten / falsch positives Architekturverständnis.

---

## Observability / Debuggability

### Vorhanden

- `Shelf Notes/SyncDiagnostics.swift`
  - Netzwerkstatus
  - iCloud-Accountstatus
  - letzter lokaler Save
  - Offline-Save-Counter
- `Shelf Notes/SyncDiagnosticsView.swift`
  - UI für Diagnoseinformationen
- `Shelf Notes/ModelContext+Diagnostics.swift`
  - Save-Breadcrumbs mit Source-File/Line
- `Shelf Notes/GoogleBooksClient.swift`
  - `GoogleBooksDebugInfo` mit Request-URL, HTTP-Status, Bytes, Snippet
- Viele Dateien enthalten relativ gute technische Kommentare zu Motivation und Constraints.

### Fehlend / ausbaufähig

- Keine zentrale Performance-Metrik für:
  - Bibliotheks-Derived-State-Zeit
  - Statistik-Compute-Zeit
  - Cover-Backfill-Laufzeit
  - CSV-Import-Durchsatz
- Keine explizite Anzeige des aktiven Store-Modus außer dem Local-only-Banner.
- Keine dedizierte technische Debug-Ansicht für:
  - Modellanzahl pro Entity
  - Store-Modus
  - Cover-Cache-Größe pro Cache-Typ
  - letzte Migration/Reparaturläufe

### Praktische Repro-Pfade

- Launch-/Store-Probleme:
  - über fehlerhafte iCloud-/Signing-Konfiguration oder absichtlichen Local-only-Start
- Statistik-/Perf-Probleme:
  - mit großer Bibliothek und vielen Sessions
- CSV-Import-Hänger:
  - größere CSV mit vielen Netzwerk-Treffern importieren
- Timer-/Live-Activity-Probleme:
  - Session starten, pausieren, App beenden, neu starten, Gerät sperren, Live Activity prüfen

---

## Open Questions

1. `Shelf Notes/Info.plist` aktiviert `remote-notification`, aber im Scan ist kein klarer Remote-Notification-Handling-Code sichtbar. **UNKNOWN**, ob bewusst vorbereitet oder veraltet.
2. `Shelf Notes/BookDetailComponents1.swift` wirkt wie ein historisch gewachsener Restname. **UNKNOWN**, ob das bewusst so bleiben soll.
3. `Shelf Notes/config/secrets.xcconfig` enthält einen Google-Books-Key im Projektstand. **UNKNOWN**, ob das nur für lokale Entwicklung gedacht ist oder tatsächlich so in der Teamarbeit genutzt wird.
4. Für SwiftData wurden keine `VersionedSchema`-/`SchemaMigrationPlan`-Artefakte gefunden. **UNKNOWN**, ob bei der nächsten Modelländerung eine formale Migrationsstrategie geplant ist.
5. `Shelf Notes/ContentView.swift` ist nur Wrapper auf `RootView`, der App-Einstieg läuft aber über `AppContainerHostView`. **UNKNOWN**, ob `ContentView` nur für Kompatibilität/Previews behalten wird.
6. Der Haupttarget steht auf iOS 26.0, die Live-Activity-Extension auf 26.2. **UNKNOWN**, ob diese Diskrepanz bewusst ist oder nur historisch entstanden.
7. Mehrgeräte-/Konfliktstrategie für CloudKit ist nicht als eigene Policy sichtbar. **UNKNOWN**, wie Konflikte fachlich behandelt werden sollen.

---

## First 3 Refactors I would do (P0)

### P0-1: CSV-Import aus der View ziehen und vom MainActor entlasten

- **Ziel**
  - `CSVImportExportView.swift` von UI auf Orchestrierungs-/Executor-Layer entkoppeln.
  - Langen Importpfad nicht mehr vollständig im `@MainActor` halten.

- **Betroffene Dateien**
  - `Shelf Notes/CSVImportExportView.swift`
  - neue Dateien wie:
    - `Shelf Notes/CSVImportExecutor.swift`
    - `Shelf Notes/CSVImportDuplicateIndex.swift`
    - `Shelf Notes/CSVExportBuilder.swift`
  - optional Berührung:
    - `Shelf Notes/GoogleBooksClient.swift`
    - `Shelf Notes/CoverThumbnailer/*`

- **Risiko**
  - Mittel.
  - Import-Feedback, Progress-Updates und Save-Reihenfolge müssen sauber stabil bleiben.

- **Erwarteter Nutzen**
  - Spürbar bessere UI-Reaktionsfähigkeit.
  - Bessere Testbarkeit der Importregeln.
  - Sauberere Basis für Batching, Retry-Strategien und ggf. Parallelisierung.

### P0-2: `Book.swift` in Schema und Fachlogik aufspalten

- **Ziel**
  - Das zentrale Modell von Hilfslogik, Migration und Cover-Strategie entkoppeln.

- **Betroffene Dateien**
  - `Shelf Notes/Book.swift`
  - neue Dateien wie:
    - `Shelf Notes/Book+Ratings.swift`
    - `Shelf Notes/Book+Collections.swift`
    - `Shelf Notes/Book+CoverURLs.swift`
    - `Shelf Notes/ReadingStatusMigrator.swift`

- **Risiko**
  - Mittel bis mittel-hoch.
  - Kernmodell; Änderungen müssen SwiftData-/CloudKit-neutral bleiben.

- **Erwarteter Nutzen**
  - Weniger Coupling an der wichtigsten Entität.
  - Kleinere Merge-Konflikte.
  - Geringeres Risiko, bei Model-Änderungen fachliche Nebenwirkungen auszulösen.

### P0-3: Gemeinsamen Analytics-/Session-Index für Stats, Goals, ProgressHub und Challenges einführen

- **Ziel**
  - Mehrfache Vollscans und doppelte Datumslogik über Bücher/Sessions reduzieren.
  - Einmalige, wiederverwendbare Value-Snapshots für mehrere Features bereitstellen.

- **Betroffene Dateien**
  - `Shelf Notes/ProgressHub/ProgressHubMetricsModel.swift`
  - `Shelf Notes/GoalsView.swift`
  - `Shelf Notes/Stats/StatisticsView+Caching.swift`
  - `Shelf Notes/Stats/StatisticsSnapshotBuilder.swift`
  - `Shelf Notes/Stats/StatisticsHeatmapBuilder.swift`
  - `Shelf Notes/Challenges/ChallengeEngine+Snapshot.swift`
  - ggf. neue Datei:
    - `Shelf Notes/Stats/ReadingAnalyticsIndex.swift`

- **Risiko**
  - Mittel bis hoch.
  - Querliegende Refaktorierung; Semantik von Streaks, Heatmap und Jahreswerten muss exakt gleich bleiben.

- **Erwarteter Nutzen**
  - Weniger doppelte O(n)-/O(m)-Arbeit.
  - Einheitliche fachliche Basis für mehrere Screens.
  - Bessere Grundlage für Performance-Tuning und Tests.
