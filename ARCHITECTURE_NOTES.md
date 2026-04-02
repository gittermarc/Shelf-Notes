# ARCHITECTURE_NOTES.md

## Big Files List (Top 15 by line count)

1. `Shelf Notes/Stats/StatisticsSnapshotBuilder.swift` — **639 lines**
   - Zweck: Value-only Statistik-Aggregation, Top-Listen, monthly series, summary, “nerd picks”.
   - Risiko: viel Datum-/Scope-/Aggregation-Logik an einer Stelle; hoher Regression-Radius bei Analytics-Änderungen.

2. `Shelf Notes/Challenges/ChallengeEngine+Compute.swift` — **435 lines**
   - Zweck: Pure compute für Challenge-Fortschritt und Challenge-Inhalte.
   - Risiko: Regelwerk-/Semantik-Datei; Off-by-one- und Fachlogikfehler wirken direkt auf weekly/monthly challenge UX.

3. `Shelf Notes/Stats/StatisticsHeatmapBuilder.swift` — **406 lines**
   - Zweck: Heatmap range calculation, daily counts, streak logic, best day/week stats.
   - Risiko: kompakte Datumsmathematik; off-by-one, range clipping, calendar/timezone bugs.

4. `Shelf Notes/LibraryView/LibraryView+Header.swift` — **396 lines**
   - Zweck: Filter-/Header-UI der Bibliothek.
   - Risiko: viele UI controls, hoher invalidation surface, schwer testbar, enger Coupling mit `LibraryView` state.

5. `Shelf Notes/BookDetail/BookDetailView+Bindings.swift` — **357 lines**
   - Zweck: Derived state, bindings, helper logic für den Detailscreen.
   - Risiko: fachliche Regeln und UI-Nebenlogik sind vermischt; hohe Coupling-Dichte zum `Book`-Modell.

6. `Shelf Notes/LibraryView/LibraryRowCoverView.swift` — **356 lines**
   - Zweck: schnelle side-effect-free Coverdarstellung für Listen/Grid-Rows.
   - Risiko: mehrere Cache-/Decode-/Fallback-Pfade; Bild- und Speicherprobleme werden hier schwer nachvollziehbar.

7. `Shelf Notes/ForYouSeedBuilder.swift` — **355 lines**
   - Zweck: heuristische Seed-Bildung für Inspirations-/Empfehlungsqueries.
   - Risiko: Heuristiken wachsen schnell chaotisch; schwierige Erwartbarkeit und Testabdeckung.

8. `Shelf Notes/Settings/AppearanceSettings/AppearancePreferences.swift` — **354 lines**
   - Zweck: zentrale AppStorage-Keys und Appearance-Optionen.
   - Risiko: jede Änderung hat app-weite Auswirkung; hohe Ripple-Effekte.

9. `Shelf Notes/CachedAsyncImage.swift` — **342 lines**
   - Zweck: memory cache, disk cache, local full-res cover storage, remote image fallback view.
   - Risiko: Cache invalidation und Speicherpfade sind verteilt; potenzielle Duplizierung mit CoverThumbnailer/RowCover.

10. `Shelf Notes/LibraryView/LibraryView+Grid.swift` — **340 lines**
    - Zweck: Grid layout, per-row appearance application, responsive visual composition.
    - Risiko: große SwiftUI tree surface; anfällig für type-checking slowdown und invalidation churn.

11. `Shelf Notes/AddBook/AddBookView+Cards.swift` — **340 lines**
    - Zweck: Card-basierte UI des Add-Book-Flows.
    - Risiko: viel Präsentationslogik in einer Datei; hoher Pflegeaufwand bei UX-Änderungen.

12. `Shelf Notes/ManualBookAddSheet.swift` — **337 lines**
    - Zweck: manueller Fallback-Import inklusive optionalem Coverfoto und Persistenz.
    - Risiko: mischt Form-UI, Bildverarbeitung, Validierung und Save Flow.

13. `Shelf Notes/AddBook/AddBookViewModel.swift` — **337 lines**
    - Zweck: Orchestrierung des Add-Book-Flows, inklusive sheet outcome handling.
    - Risiko: State-machine-artige Verantwortung ohne formale State machine; hohe Änderungsanfälligkeit.

14. `Shelf Notes/BookImport/BookImportView/BookImportViewModel+Tasks.swift` — **335 lines**
    - Zweck: search, debounce, cancellation, pagination, composite queries.
    - Risiko: klassischer Concurrency-/stale-result-Hotspot.

15. `Shelf Notes/BookDetail/BookDetailView+Cards.swift` — **333 lines**
    - Zweck: Hauptsektionen des Detailscreens.
    - Risiko: große SwiftUI-Datei mit viel Layoutzustand; schwer zu diffen und granular zu testen.

## Hot Path Analyse

### Rendering / Scrolling

#### 1) Bibliothek: vollständige `@Query` + derived mapping im Hauptscreen
- Dateien:
  - `Shelf Notes/LibraryView/LibraryView.swift`
  - `Shelf Notes/LibraryView/LibraryDerivedStateBuilder.swift`
  - `Shelf Notes/LibraryView/LibraryView+Header.swift`
- Grund:
  - `@Query(sort: \Book.createdAt, order: .reverse)` lädt den gesamten Book-Bestand in die View.
  - Pro Render werden mehrere derived helpers benutzt (`displayedBooksForCurrentDerivedState`, `alphaSectionsForUI`, `countsForUI`).
  - `displayedBooksForCurrentDerivedState` baut jeweils ein `Dictionary(uniqueKeysWithValues:)` aus allen Büchern.
- Hotspot-Typ:
  - **exzessive View invalidation**
  - **full collection remapping in render path**
- Status:
  - Bereits entschärft durch `LibraryDerivedStateCoordinator`, aber noch nicht vollständig “cheap”.

#### 2) RootView scannt die gesamte Bibliothek app-weit
- Datei: `Shelf Notes/RootView.swift`
- Grund:
  - `@Query private var books: [Book]` dient gleichzeitig für:
    - CSV first-run prompt
    - Tag index signature/update
    - pending timer book lookup fallback
    - cover backfill scheduling context
  - Jede Änderung an `Book` invalidiert damit die Tab-Shell.
- Hotspot-Typ:
  - **global invalidation source**

#### 3) StatisticsView berechnet noch immer O(n)-Signaturen im UI-Layer
- Dateien:
  - `Shelf Notes/Stats/StatisticsView.swift`
  - `Shelf Notes/Stats/StatisticsView+Caching.swift`
- Grund:
  - `booksSignature(_:)` iteriert bei jedem Render über alle Bücher, Tags, Kategorien und einige Ratings.
  - Schwere Crunches sind zwar in detached tasks ausgelagert, aber die Signature-Berechnung bleibt im View-Layer.
- Hotspot-Typ:
  - **heavy sort/hash/scan in render-adjacent path**

#### 4) GoalsView rechnet Metriken direkt in `body`
- Dateien:
  - `Shelf Notes/Goals/GoalsView.swift`
  - `Shelf Notes/Goals/GoalsYearMetricsBuilder.swift`
- Grund:
  - `let metrics = GoalsYearMetricsBuilder.make(...)` läuft direkt im `body`.
  - `slotsGrid` kann bis zu `targetCount` Kacheln erzeugen.
  - `onAppear` legt bei fehlendem Ziel sofort Daten an (`saveGoal(...)`).
- Hotspot-Typ:
  - **heavy compute in render path**
  - **mutation on appear**

#### 5) Timeline hält vollständige `Book`-Objekte im ViewModel
- Dateien:
  - `Shelf Notes/Timeline/ReadingTimelineView.swift`
  - `Shelf Notes/Timeline/ReadingTimelineViewModel.swift`
- Grund:
  - `ReadingTimelineViewModel.setBooks(_:)` hält `Book`-Referenzen in `cachedEntries`, `items`, `previewBooks`.
  - Jede relevante Book-Änderung baut die komplette Timeline neu.
- Hotspot-Typ:
  - **whole-list rebuild**
  - **large horizontal render surface**

#### 6) Cover-Rendering verteilt auf mehrere Pfade
- Dateien:
  - `Shelf Notes/CachedAsyncImage.swift`
  - `Shelf Notes/CoverThumbnailer/CoverThumbnailer.swift`
  - `Shelf Notes/LibraryView/LibraryRowCoverView.swift`
- Grund:
  - Lokale full-res Bilder, synced thumbnails, disk cache, NSCache, remote candidates, URL upgrades und background thumbnail refresh greifen ineinander.
- Hotspot-Typ:
  - **expensive image decode**
  - **cache invalidation complexity**
  - **multi-path render behavior**

### Sync / Storage

#### 1) Bootstrap-Sync ist robust, aber fachlich breit geladen
- Datei: `Shelf Notes/AppContainerHostView.swift`
- Grund:
  - Container bootstrap, fallback handling, repair, challenge ensure/refresh und error UI liegen zusammen.
- Risiko:
  - Fehler im Bootstrap betreffen App-Start direkt.

#### 2) Kein formaler Migrationsplan
- Dateien:
  - `Shelf Notes/AppContainerHostView.swift`
  - `Shelf Notes/ReadingStatusMigrator.swift`
  - `Shelf Notes/CollectionMembershipRepair.swift`
- Grund:
  - Kein `VersionedSchema` / `MigrationPlan` gefunden.
  - Stattdessen ad-hoc Reparaturen und Datenkorrekturen nach dem Start.
- Hotspot-Typ:
  - **migration risk**
  - **repair-after-load pattern**

#### 3) Local-only Store ist absichtlich ein separater Datenraum
- Datei: `Shelf Notes/AppContainerHostView.swift`
- Grund:
  - Gute Robustheit gegen Store-Mischung.
  - Gleichzeitig Risiko für Benutzerverwirrung, weil local-only nicht automatisch in Cloud-Daten zurückgeführt wird.
- Hotspot-Typ:
  - **data divergence by design**

#### 4) Sync-Diagnose zeigt nur Surrogat-Signale
- Dateien:
  - `Shelf Notes/SyncDiagnostics.swift`
  - `Shelf Notes/SyncDiagnosticsView.swift`
- Grund:
  - Zeigt Account status, network status, last local save, offline counters.
  - Zeigt **nicht**: echte CloudKit op queue / per-record sync state / conflict resolution.
- Hotspot-Typ:
  - **limited observability**

#### 5) `UIBackgroundModes = remote-notification`, aber kein Handler gefunden
- Dateien:
  - `Shelf Notes/Info.plist`
  - `Shelf Notes/Shelf_Notes.entitlements`
- Scan-Ergebnis:
  - Expliziter Remote-Notification-Empfangscode wurde in der gescannten Codebasis nicht gefunden.
- Bewertung:
  - Entweder ungenutzte Konfiguration oder Code liegt außerhalb des gelieferten Standes.

### Concurrency

#### 1) Book import tasks sind der kritischste Async-Workflow
- Datei: `Shelf Notes/BookImport/BookImportView/BookImportViewModel+Tasks.swift`
- Gute Seite:
  - generation token
  - explicit cancellation
  - stale-result guarding
- Risiko:
  - Viele konkurrierende Task-Typen (`searchTask`, `loadMoreTask`, `debouncedRefreshTask`, `undoHideTask`).
- Hotspot-Typ:
  - **Task lifetime complexity**
  - **stale async result risk**

#### 2) Statistics compute nutzt detached tasks korrekt, aber ohne shared service
- Datei: `Shelf Notes/Stats/StatisticsComputePipeline.swift`
- Gute Seite:
  - value snapshot + detached utility tasks + cancellation handler.
- Risiko:
  - jede View-Instanz baut ihren eigenen Pipeline-/Cache-Lebenszyklus.
- Hotspot-Typ:
  - **duplicate background compute**

#### 3) ReadingTimerManager arbeitet mit manuellem `objectWillChange.send()`
- Dateien:
  - `Shelf Notes/BookDetail/Sessions/ReadingTimerManager/ReadingTimerManager.swift`
  - `...+Persistence.swift`
  - `...+AutoStop.swift`
- Grund:
  - bewusstes Workaround-Muster für ObservableObject / Swift 6 edge cases.
- Risiko:
  - doppeltes/manuelles Publish-Verhalten ist wartungsintensiv und fehleranfällig.
- Hotspot-Typ:
  - **manual state publication**

#### 4) Cover pipeline mischt MainActor-gebundene SwiftData writes mit detached image work
- Dateien:
  - `Shelf Notes/CoverThumbnailer/CoverThumbnailer+Apply.swift`
  - `...+ImageIO.swift`
  - `...+Backfill.swift`
  - `...+RemoteFetch.swift`
- Risiko:
  - Grenzbereich zwischen Bildverarbeitung off-main und SwiftData main-actor-only access.
- Hotspot-Typ:
  - **MainActor contention**
  - **cross-actor coordination overhead**

## Refactor Map

### Konkrete Splits

#### A) Goals feature auf echtes metrics model umstellen
- Heute:
  - `Shelf Notes/Goals/GoalsView.swift` berechnet direkt.
- Zielsplit:
  - `GoalsMetricsModel.swift`
  - `GoalsGoalEditorSection.swift`
  - `GoalsProgressSection.swift`
  - `GoalsSlotsGrid.swift`
- Nutzen:
  - weniger Compute im `body`
  - bessere Tests
  - klarere Mutation-/Presentation-Trennung

#### B) RootView entkoppeln
- Heute:
  - `Shelf Notes/RootView.swift` ist Tab shell + appearance + migrations + tags + backfill + timer completion sheet.
- Zielsplit:
  - `RootAppearanceHost.swift`
  - `RootStartupTasks.swift`
  - `RootTimerPresentation.swift`
  - `RootTabShell.swift`
- Nutzen:
  - weniger globaler Invalidation-Bereich
  - bessere Lesbarkeit

#### C) Book detail derived state aus Bindings-Datei herausziehen
- Heute:
  - `Shelf Notes/BookDetail/BookDetailView+Bindings.swift`
- Zielsplit:
  - `BookDetailDerivedState.swift`
  - `BookDetailTagSuggestionsBuilder.swift`
  - `BookDetailCollectionsState.swift`
- Nutzen:
  - weniger Mischmasch aus Bindings und Fachregeln

#### D) Cover architecture vereinheitlichen
- Heute verteilt auf:
  - `Shelf Notes/CachedAsyncImage.swift`
  - `Shelf Notes/CoverThumbnailer/*`
  - `Shelf Notes/LibraryView/LibraryRowCoverView.swift`
  - `Shelf Notes/BookModel/Book+CoverURLs.swift`
- Zielsplit:
  - `CoverRepository.swift` (resolve/load/store)
  - `CoverCachePolicy.swift`
  - `CoverRenderSource.swift`
- Nutzen:
  - weniger doppelte Fallbacklogik
  - klarere invalidation rules

### Cache- / Index-Ideen

#### 1) Shared analytics snapshot/index
- Kandidaten:
  - `GoalsView`
  - `ProgressHubView`
  - `StatisticsView`
  - `ReadingTimelineView`
- Idee:
  - Ein app-weiter, signature-getriebener `ReadingAnalyticsStore` mit value snapshot.
- Key-Struktur:
  - books signature + sessions signature + calendar/timezone
- Invalidierung:
  - bei relevanten Book/Session-Änderungen
- Nutzen:
  - beseitigt Mehrfachscans derselben Datenbasis.

#### 2) Book lightweight row projection
- Kandidaten:
  - `LibraryView`
  - `TagsIndexStore`
  - `Timeline`
- Idee:
  - `BookRowSnapshot` / `BookAnalyticsSnapshot` statt wiederholter Dictionary-/projection-Bildung.
- Nutzen:
  - weniger direkte `Book`-Traversal im Renderpfad.

#### 3) Cover result cache mit source fingerprint
- Idee:
  - Cache key = `book.id + thumbnailURL + userCoverFileName + userCoverData hash`
- Nutzen:
  - explizitere invalidation statt impliziter Zustandskombinationen.

### Vereinheitlichungen

#### 1) Mehr konsistente derived-state pattern
Bereits vorhanden:
- `Shelf Notes/LibraryView/LibraryDerivedStateCoordinator.swift`
- `Shelf Notes/TagsView/TagsIndexStore.swift`
- `Shelf Notes/ProgressHub/ProgressHubMetricsModel.swift`

Noch inkonsistent:
- `Shelf Notes/Goals/GoalsView.swift`
- `Shelf Notes/Timeline/ReadingTimelineViewModel.swift`
- Teile von `Shelf Notes/BookDetail/BookDetailView+Bindings.swift`

#### 2) Write path policy zentralisieren
- Positiv: `modelContext.saveWithDiagnostics()` existiert.
- Fehlt:
  - klarer write boundary layer für komplexere Mutationen.
- Kandidaten:
  - collections membership
  - session writes
  - goal writes
  - imported book writes

#### 3) Singleton policy dokumentieren
Singletons / quasi-globale Instanzen aktuell:
- `GoogleBooksClient.shared`
- `SyncDiagnostics.shared`
- `ImageMemoryCache.shared`
- `ImageDiskCache.shared`
- `ReadingTimerManager` als app-globales `StateObject`
- `ProManager` als app-globales `StateObject`

Das funktioniert, sollte aber bewusst dokumentiert werden.

## Risiken & Edge Cases

### Datenverlust / Persistenz
- `localOnly` ist separater Store; kein automatischer Merge zurück zu CloudKit.
- `ReadingGoal` hat keinen technisch erzwungenen Unique Key pro Jahr.
- Collection-Beziehung wurde historisch als drift-anfällig beschrieben; Reparatur läuft nur best effort.
- Kein formaler Schema-Migrationspfad gefunden.

### Offline / Multi-Device
- Sync-Diagnostik sieht nur lokale Save- und Netzwerk-Signale, keine echte Record-Ebene.
- Konfliktauflösung / merge policy ist **UNKNOWN**; in `Shelf Notes/AppContainerHostView.swift` wurde keine explizite Merge-Policy gefunden.
- Verhalten bei parallelen Edits auf mehreren Geräten ist fachlich nicht dokumentiert.

### Import / Networking
- Google Books ist externer Single Point of Failure für den Import.
- `GOOGLE_BOOKS_API_KEY` liegt aktuell im Repo.
- Composite OR queries werden clientseitig zusammengeführt; Ranking-/Paging-Verhalten ist dadurch anders als bei serverseitiger Suche.

### Monetization
- `Shelf Notes/ProManager.swift` nutzt `productID = "001"`.
- Ob das bewusst produktiv ist oder nur lokales Test-Setup, ist **UNKNOWN**.

### Live Activity / Extension
- App Group IDs stimmen zwischen App und Extension.
- Main app deployment target und extension deployment target unterscheiden sich (`26.0` vs `26.2`).
- Ob diese Asymmetrie absichtlich ist, ist **UNKNOWN**.

## Observability / Debuggability

### Bereits vorhanden
- `Shelf Notes/SyncDiagnostics.swift`
  - iCloud account status
  - network path status
  - last local save source/error
  - offline save counters
- `Shelf Notes/SyncDiagnosticsView.swift`
  - UI + copy-to-clipboard diagnostics report
- `Shelf Notes/ModelContext+Diagnostics.swift`
  - Save breadcrumbing
- Google Books debug info in `Shelf Notes/GoogleBooksClient.swift`
  - request URL
  - HTTP status
  - response size
  - response snippet
  - parsed totalItems/error presence
- Gute testbare builder coverage in `Shelf NotesTests/` für:
  - tags index
  - goals metrics
  - statistics pipeline
  - analytics index
  - csv import/export

### Was fehlt
- Kein strukturierter Logger mit Kategorien / os.Logger gefunden.
- Keine Performance-Metriken für:
  - statistics recompute duration
  - library derived-state rebuild duration
  - cover backfill throughput
- Kein sichtbarer “sync state per record/feature”.
- Kein dediziertes debug dashboard für caches.

### Reproduktionstipps
- Sync-Probleme:
  - über `SettingsView -> Sync-Diagnose`
  - Netzwerk wechseln
  - local save source beobachten
- Cover-Probleme:
  - Cover-Cache in Settings leeren
  - danach Bibliothek / Detail / Timeline gegenprüfen
- Import-Probleme:
  - `GoogleBooksClient` debug fields prüfen
  - OR query / pagination / language filter separat testen

## Open Questions
- **UNKNOWN**: Welche konkrete CloudKit conflict/merge policy ist gewünscht? Es wurde keine explizite Policy im Code gefunden.
- **UNKNOWN**: Soll `localOnly` jemals wieder in den CloudKit-Store überführt werden, oder ist das dauerhaft ein separater Datenraum?
- **UNKNOWN**: Ist `ProManager.productID = "001"` nur Test-/StoreKit-Config oder die echte Produkt-ID?
- **UNKNOWN**: Warum ist die Live Activity extension auf iOS 26.2 gesetzt, die App aber auf 26.0?
- **UNKNOWN**: Ist `UIBackgroundModes = remote-notification` noch aktiv gewollt? Expliziter Empfängercode wurde im gelieferten Stand nicht gefunden.
- **UNKNOWN**: Gibt es außerhalb dieses ZIPs weitere Signing-/CI-/Secret-Konventionen, die `config/secrets.xcconfig` überschreiben?
- **UNKNOWN**: Welche Felder gelten fachlich als konfliktkritisch bei Multi-Device-Edits: `collections`, `notes`, `tags`, `ratings`, `read dates`, Sessions?
- **UNKNOWN**: Soll `ReadingGoal` fachlich wirklich nur einmal pro Jahr existieren? Das Modell legt das nahe, technisch ist es nicht hart abgesichert.

## First 3 Refactors I would do (P0)

### 1) GoalsView auf abgeleiteten/cached Zustand umstellen
- Ziel
  - Rechenarbeit und Mutation aus `GoalsView.body` herausziehen.
- Betroffene Dateien
  - `Shelf Notes/Goals/GoalsView.swift`
  - `Shelf Notes/Goals/GoalsYearMetricsBuilder.swift`
  - neu: `Shelf Notes/Goals/GoalsMetricsModel.swift`
- Risiko
  - Niedrig bis mittel; UI bleibt gleich, Logik wird nur verschoben.
- Erwarteter Nutzen
  - Weniger Renderkosten.
  - Klare Trennung von read model vs write model.
  - Bessere Testbarkeit für Ziel-/Jahreswechsel.

### 2) Shared ReadingAnalyticsStore einführen
- Ziel
  - Mehrfachscans von Books/Sessions in ProgressHub, Goals, Stats und Timeline reduzieren.
- Betroffene Dateien
  - `Shelf Notes/Analytics/ReadingAnalyticsIndexBuilder.swift`
  - `Shelf Notes/Goals/GoalsYearMetricsBuilder.swift`
  - `Shelf Notes/ProgressHub/ProgressHubMetricsModel.swift`
  - `Shelf Notes/Stats/StatisticsView+Caching.swift`
  - `Shelf Notes/Timeline/ReadingTimelineViewModel.swift`
- Risiko
  - Mittel; mehrere Features hängen an denselben Kennzahlen.
- Erwarteter Nutzen
  - Konsistentere Zahlenbasis.
  - Weniger O(n)-Scans.
  - Einfachere Invalidierungsregeln.

### 3) Cover-Pipeline konsolidieren
- Ziel
  - Alle Cover source/resolve/cache/store Regeln an einer fachlichen Stelle bündeln.
- Betroffene Dateien
  - `Shelf Notes/CachedAsyncImage.swift`
  - `Shelf Notes/CoverThumbnailer/CoverThumbnailer.swift`
  - `Shelf Notes/CoverThumbnailer/CoverThumbnailer+Apply.swift`
  - `Shelf Notes/CoverThumbnailer/CoverThumbnailer+RemoteFetch.swift`
  - `Shelf Notes/LibraryView/LibraryRowCoverView.swift`
  - `Shelf Notes/BookModel/Book+CoverURLs.swift`
- Risiko
  - Mittel; Cover betreffen viele Screens und subjektiv “sichtbare” Qualität.
- Erwarteter Nutzen
  - Weniger Cache-/Fallback-Dopplung.
  - Bessere Debugbarkeit bei unscharfen oder fehlenden Covers.
  - Weniger MainActor-/Background-Koordination an zufälligen Stellen.
