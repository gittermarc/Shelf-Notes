# Shelf Notes — ARCHITECTURE_NOTES

## Scope
Diese Notizen sind eine technische Landkarte für Wartbarkeit/Performance (SwiftUI + SwiftData + CloudKit). Aussagen sind mit konkreten Dateipfaden belegt; alles Unklare landet in **Open Questions**.

## Big Files List (Top 15 nach Zeilen)

| # | Datei | LOC | Inhalt (Top-Level Decls) | Warum riskant |
|---:|---|---:|---|---|
| 1 | `Shelf Notes/BookImport/BookImportView/BookImportViewModel.swift` | 562 | ['class BookImportViewModel', 'struct UndoPayload'] | Viele State-Mutationen + async Search/Filter; schwer zu testen + Race/Cancellation-Risiko. |
| 2 | `Shelf Notes/Stats/StatisticsView+Data.swift` | 459 | ['extension StatisticsView', 'struct MonthKey', 'struct MonthSeriesPoint', 'struct ParsedGenre', 'struct NerdPick'] | Enthält Aggregationen/Charts-Glue; Gefahr von Render-Hitches bei Recompute. |
| 3 | `Shelf Notes/Stats/StatisticsView+Sections.swift` | 456 | ['extension StatisticsView'] | Enthält Aggregationen/Charts-Glue; Gefahr von Render-Hitches bei Recompute. |
| 4 | `Shelf Notes/LibraryView/LibraryRowAppearanceSettingsSection.swift` | 454 | ['struct LibraryRowAppearanceSettingsSection', 'struct LibraryRowSettingsPreview', 'enum MetaPart'] | Großes File → Merge-Konflikte/hohe kognitive Last. |
| 5 | `Shelf Notes/Challenges/ChallengeEngine+Compute.swift` | 435 | ['extension ChallengeEngine', 'struct PeriodBounds', 'struct EnsurePlan', 'struct CompletionPlan', 'struct BaselineStats', 'struct GeneratedChallenge'] | Compute-Logik zentral; Änderungen können viele UI-Flows beeinflussen. |
| 6 | `Shelf Notes/Book.swift` | 428 | ['enum ReadingStatus', 'enum ReadingStatusMigrator', 'class Book', 'extension Book'] | Zentrales Modell + Migration + viele Derived Props; Änderungen sind schema-/sync-sensitiv. |
| 7 | `Shelf Notes/LibraryView/LibraryView+Header.swift` | 418 | ['extension LibraryView', 'enum QuickSortMode', 'struct LibraryStatusCounts'] | Großes File → Merge-Konflikte/hohe kognitive Last. |
| 8 | `Shelf Notes/BookImport/BookImportView/BookImportViewModel+Tasks.swift` | 406 | ['extension BookImportViewModel'] | Viele State-Mutationen + async Search/Filter; schwer zu testen + Race/Cancellation-Risiko. |
| 9 | `Shelf Notes/Timeline/ReadingTimerManager.swift` | 402 | ['class ReadingTimerManager', 'struct ActiveState', 'enum CodingKeys', 'struct PendingCompletion', 'enum Keys'] | State-Machine/Timer/Tasks; Gefahr von Leaks/Cancellation-Bugs. |
| 10 | `Shelf Notes/BookDetail/BookDetailView+Bindings.swift` | 376 | ['extension BookDetailView'] | Großes File → Merge-Konflikte/hohe kognitive Last. |
| 11 | `Shelf Notes/Stats/StatisticsView+Heatmap.swift` | 373 | ['extension StatisticsView', 'struct HeatmapRange', 'struct HeatmapDay', 'struct HeatmapWeek', 'struct WeekKey', 'struct HeatmapStats'] | Enthält Aggregationen/Charts-Glue; Gefahr von Render-Hitches bei Recompute. |
| 12 | `Shelf Notes/CSVImportExportView.swift` | 364 | ['enum CSVSearchMode', 'struct CSVImportReport', 'struct CSVExportDocument', 'struct CSVImportExportView'] | I/O + Parsing + UI in einem File; Fehler/Edge-Cases bei großen CSVs. |
| 13 | `Shelf Notes/LibraryView/LibraryRowCoverView.swift` | 356 | ['class SyncedThumbnailMemoryCache', 'struct LibraryRowCoverView', 'struct SyncedThumbnailImage', 'extension LibraryRowCoverView'] | Hot path in Lists/Grids; Bild-Decoding/Cache-Interaktion beeinflusst Scroll-Performance. |
| 14 | `Shelf Notes/ForYouSeedBuilder.swift` | 355 | ['enum ForYouSeedBuilder', 'struct CategoryProfile'] | Großes File → Merge-Konflikte/hohe kognitive Last. |
| 15 | `Shelf Notes/AppearanceSettings/AppearancePreferences.swift` | 354 | ['enum AppearanceStorageKey', 'enum AppColorSchemeOption', 'enum LibraryLayoutModeOption', 'enum LibraryHeaderStyleOption', 'enum LibraryTagStyleOption', 'enum AppFontDesignOption', 'enum AppTextSizeOption', 'enum AppDensityOption'] | Viele Settings/Defaults; hoher Merge-Konflikt + schwer testbar. |

## Hot Path Analyse

### Rendering / Scrolling

**1) Library-Liste/Grid (primärer Scroll-Hotpath)**
- Einstieg: `Shelf Notes/LibraryView/LibraryView.swift` (Split via Extensions).
- Konkrete Risiken/Gründe:
  - **Große @Query-Arrays**: `@Query(sort: \Book.createdAt, …) var books: [Book]` lädt die komplette Bibliothek in den View-State. (`Shelf Notes/LibraryView/LibraryView.swift`)
  - **Derived State Caching** ist vorhanden (gut): `cachedDisplayedBooks`, `cachedAlphaSections`, `pendingRecomputeTask` um Filter/Sort/Bucketing nicht pro Frame zu rechnen. (`Shelf Notes/LibraryView/LibraryView.swift`) → trotzdem: jeder Recompute ist O(n) über Bücher.
  - **Cover Rendering**: Row-Cover-View + Loader/Cache sind in der Scroll-Hot-Zone. `Shelf Notes/LibraryView/LibraryRowCoverView.swift`, `Shelf Notes/CoverImageLoader.swift`, `Shelf Notes/CoverThumbnailer/*`.

**2) Stats (Charts + Heatmap) — potenzieller UI-Hitch beim Öffnen/Wechseln**
- Einstieg über Fortschritt: `Shelf Notes/ProgressHub/ProgressHubView.swift` → `StatisticsView()`.
- Cache-Update Trigger: `.task(id: statsKey)` und `.task(id: heatmapKey)` in `Shelf Notes/StatisticsView.swift`.
- Konkrete Gründe:
  - `computeStatsCache(for:)` und `computeHeatmapCache(for:)` laufen aktuell **synchron im Task-Body** (typischerweise MainActor, weil State gesetzt wird). Das ist genau die Sorte Arbeit, die beim Öffnen/Interaktion spürbar werden kann. (`Shelf Notes/StatisticsView.swift`, Implementierungen in `Shelf Notes/Stats/StatisticsView+Data.swift` und `Shelf Notes/Stats/StatisticsView+Heatmap.swift`)
  - Es gibt ein `await Task.yield()` vor dem Compute (gut für „erst rendern, dann rechnen“), aber es verlagert die Arbeit nicht off-main.

**3) Inspiration seeds („Für dich“) im Renderpfad**
- `InspirationSeedPickerView` berechnet `forYouSeeds` als computed property über `@Query books`. (`Shelf Notes/InspirationSeedPickerView.swift`)
- Konkreter Grund: `ForYouSeedBuilder.build(from:)` iteriert über alle Bücher und macht Normalisierung/Counting (O(n)). (`Shelf Notes/ForYouSeedBuilder.swift`)
- Risiko: bei großen Libraries + häufigen View-Updates (z.B. Sheet-Animations/State) kann das unnötig oft laufen.

### Sync / Storage

**1) Container Bootstrap + Store-Fallback**
- `AppBootstrapper` versucht CloudKit, zeigt bei Fehlern eine „retry/local/in-memory“ UI. (`Shelf Notes/AppContainerHostView.swift`)
- Konkrete Gründe/Risiken:
  - **Store-Trennung** (Cloud vs LocalOnly) ist bewusst, aber erzeugt Daten-Divergenz als Produkt-Feature: LocalOnly hat einen separaten Datenstand. (`Shelf Notes/AppContainerHostView.swift`)
  - **Einmalige Repairs** laufen beim Ready-State: `CollectionMembershipRepair.repairIfNeeded(...)`. (`Shelf Notes/AppContainerHostView.swift`, `Shelf Notes/CollectionMembershipRepair.swift`)
  - **Challenge Engine Initialisierung** läuft ebenfalls beim Ready-State: `ChallengeEngine.ensureCurrentChallengesAndRefreshCompletion(...)`. (`Shelf Notes/AppContainerHostView.swift`, `Shelf Notes/Challenges/ChallengeEngine.swift`)

**2) Cover Thumbnail Backfill (I/O + Network, aber throttled)**
- Start: `RootView.scheduleCoverBackfillIfNeeded()` triggert einmalig (per `@AppStorage did_run_cover_backfill_v2`). (`Shelf Notes/RootView.swift`)
- Compute/Decode off-main ist bereits vorgesehen:
  - Thumbnail encode/decode via `Task.detached` in `CoverThumbnailer+ImageIO.swift`.
  - Remote load + Disk cache via `CoverImageLoader` (`background(...)` helper). `Shelf Notes/CoverImageLoader.swift`.
- Risiko: Backfill APIs sind `@MainActor` (wegen `ModelContext`), daher sollten nur **ModelContext-Mutationen** auf Main passieren, nicht Decode/Network. Das ist größtenteils so implementiert (siehe `Task.detached` / background helpers), aber es bleibt ein Bereich, der bei Regressionen sofort in UI-Lags kippt. (`Shelf Notes/CoverThumbnailer/*`)

### Concurrency

**1) Lese-Timer State-Machine**
- `ReadingTimerManager` hält Timer-State, Background/Foreground Handling, Pending Completion. (`Shelf Notes/Timeline/ReadingTimerManager.swift`)
- Konkrete Risiken:
  - **Task lifetimes**: Timer-Tasks müssen beim ScenePhase-Wechsel/Stop sauber gecancelt werden (sonst ghost updates). (`Shelf Notes/RootView.swift`, `Shelf Notes/Timeline/ReadingTimerManager.swift`)

**2) StoreKit Transaction Listener**
- `ProManager` startet `updatesTask = Task { await listenForTransactions() }` und cancelt in `deinit`. (`Shelf Notes/ProManager.swift`)
- Konkreter Grund: Long-lived async sequences sind klassische Leak-/Retention-Fallen, werden hier zumindest sauber gecancelt.

**3) SyncDiagnostics (NWPathMonitor + CloudKit account status)**
- `SyncDiagnostics` nutzt `NWPathMonitor` und CloudKit account status checks. (`Shelf Notes/SyncDiagnostics.swift`)
- Risiko: nicht „Hot path“, aber Debug-UI kann bei zu häufiger Aktualisierung noisy werden (UserDefaults writes, UI updates).

## Refactor Map

### Konkrete Splits (mechanisch, niedrige Logikänderung)
- `Shelf Notes/LibraryView/LibraryRowAppearanceSettingsSection.swift` → in 3–5 kleinere Subviews/Sections splitten (z.B. `+Layout`, `+Typography`, `+Covers`, `+Badges`). Ziel: Merge-Konflikte runter, Verantwortlichkeiten klarer.
- `Shelf Notes/BookImport/BookImportView/BookImportViewModel.swift` + `BookImportViewModel+Tasks.swift` → weiter aufteilen nach Verantwortung:
  - `+SearchAndPagination`, `+Filtering`, `+SelectionAndApply`, `+Undo` (oder ähnlich).
- `Shelf Notes/CSVImportExportView.swift` → UI vs Parsing vs File I/O trennen (z.B. `CSVImportPipeline`, `CSVExportPipeline`).

### Cache-/Index-Ideen (Key-Strukturen + Invalidation)
- **Stats off-main via Snapshot**: Value-only Snapshot aus `Book` + `ReadingSession` (nur benötigte Felder), Signatur-Key als invalidation. Dadurch kann `computeStatsCache` in `Task.detached` laufen, MainActor bekommt nur das Ergebnis. Betroffene Files: `Shelf Notes/StatisticsView.swift`, `Shelf Notes/Stats/*`.
- **ForYou Seeds Cache**: analog zu `TagsIndexModel`/`ProgressHubMetricsModel`: `ForYouSeedsModel` mit `taskSignature(books:)`, Update in `.task(id:)` statt computed property. Betroffene Files: `Shelf Notes/InspirationSeedPickerView.swift`, `Shelf Notes/ForYouSeedBuilder.swift`.
- **Cover cache hygiene**: `ImageDiskCache` wächst unbounded (kein TTL/size cap sichtbar). Optional: LRU/Cap + „Clear cache“ in Settings. Betroffene Files: `Shelf Notes/CachedAsyncImage.swift`, UI: `Shelf Notes/SettingsView.swift`.

### Vereinheitlichungen (Patterns / Services)
- **Save policy**: Durchgehend `saveWithDiagnostics()` verwenden (ist schon weit verbreitet) und „Batch saves“ (mehrere Mutationen → 1 Save) dort, wo UI viele kleine Änderungen macht. Einstieg: `Shelf Notes/ModelContext+Diagnostics.swift` + Call Sites.
- **Task IDs**: Wenn `.task(id:)` auf Arrays/Collections basiert, auf lightweight Tokens/Signatures umstellen (Pattern existiert z.B. in `TagsIndexModel.taskSignature` und `ProgressHubMetricsModel.makeInputToken`).

## Risiken & Edge Cases
- **CloudKit vs LocalOnly Divergenz**: Nutzer kann in LocalOnly Daten anlegen, die beim späteren Wechsel zu CloudKit nicht automatisch gemerged werden (ist bewusst so, aber Support-Falle). (`Shelf Notes/AppContainerHostView.swift`)
- **Many-to-many optional relationships**: `Book.collections` und `BookCollection.books` sind optional → Code muss nil-safe sein (Membership-Checks/Repairs). (`Shelf Notes/Book.swift`, `Shelf Notes/BookCollection.swift`, `Shelf Notes/CollectionMembershipRepair.swift`)
- **External storage cover thumbnails**: `Book.userCoverData` als `.externalStorage` ist synced Thumbnail Source-of-Truth; Full-Res bleibt lokal (`userCoverFileName`). Edge: Datei gelöscht/umbenannt → Thumbnail-Backfill muss robust sein. (`Shelf Notes/Book.swift`, `Shelf Notes/CoverThumbnailer/*`, `Shelf Notes/CachedAsyncImage.swift` (UserCoverStore)
- **CSV Import/Export**: Große Dateien → Memory-Spikes; Fehler bei Encodings/Delimiters. (`Shelf Notes/CSVCodec.swift`, `Shelf Notes/CSVImportExportView.swift`)

## Observability / Debuggability
- **SyncDiagnostics UI**: iCloud Account, Network Status, letzter Save inkl. Source (`#fileID:#line`). `Shelf Notes/SyncDiagnostics.swift`, `Shelf Notes/SyncDiagnosticsView.swift`, `Shelf Notes/ModelContext+Diagnostics.swift`.
- **Empfehlung**: OSLog Categories für Import/Cover/Challenges/Sync, plus „Repro Steps“ in Debug UI (nicht implementiert).

## Open Questions (**UNKNOWN**)
- **SwiftData Schema-Migration Strategy**: Es gibt One-off Migration für `ReadingStatus`, aber kein sichtbares Schema-Versioning/Migrationskonzept. (Suche in Repo: keine dedizierten Migration-Module außerhalb `ReadingStatusMigrator` in `Shelf Notes/Book.swift`).
- **CloudKit database scope** bei `cloudKitDatabase: .automatic`: Welche DB (private/shared/public) effektiv genutzt wird, ist hier nicht explizit dokumentiert. (`Shelf Notes/AppContainerHostView.swift`)
- **Production Push Entitlement**: Entitlements setzen `aps-environment = development`; ob Release sauber auf production steht, ist hier nicht ablesbar. (`Shelf Notes/Shelf_Notes.entitlements`)

## First 3 Refactors I would do (P0)

### P0.1 — Stats off-main via Snapshot
- **Ziel**: UI-Hitches beim Öffnen/Interagieren in `StatisticsView` eliminieren (Compute nicht auf MainActor).
- **Betroffene Dateien**: `Shelf Notes/StatisticsView.swift`, `Shelf Notes/Stats/StatisticsView+Data.swift`, `Shelf Notes/Stats/StatisticsView+Heatmap.swift`, neu: `Shelf Notes/Stats/StatisticsSnapshots.swift` (Value-only structs).
- **Risiko**: mittel (muss korrekt invalidieren + Ergebnis identisch).
- **Erwarteter Nutzen**: spürbar smoother Stats-Screen bei großen Libraries/Session-History.

### P0.2 — Split LibraryRowAppearanceSettingsSection
- **Ziel**: Wartbarkeit + Merge-Konflikte reduzieren (große Settings-Section in kleinere Subviews).
- **Betroffene Dateien**: `Shelf Notes/LibraryView/LibraryRowAppearanceSettingsSection.swift` (Split in 3–5 Files).
- **Risiko**: niedrig (mechanisch, kaum Logikänderung).
- **Erwarteter Nutzen**: schnelleres Arbeiten an Appearance-Features, weniger „Monster-File“-Effekt.

### P0.3 — Cache ForYou seeds (aus dem Renderpfad raus)
- **Ziel**: `ForYouSeedBuilder.build(from:)` nicht als computed property über `@Query` laufen lassen; stattdessen Task+Cache wie bei Tags/ProgressHub.
- **Betroffene Dateien**: `Shelf Notes/InspirationSeedPickerView.swift`, `Shelf Notes/ForYouSeedBuilder.swift`, neu: `Shelf Notes/ForYouSeedsModel.swift` (ähnlich `TagsIndexModel`).
- **Risiko**: niedrig–mittel (UI-State + Invalidation).
- **Erwarteter Nutzen**: weniger unnötige O(n)-Recomputes, bessere Responsiveness bei großen Libraries.
