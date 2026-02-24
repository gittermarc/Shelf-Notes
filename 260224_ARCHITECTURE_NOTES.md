    # ARCHITECTURE_NOTES.md — Shelf Notes

    ## Big Files List (Top 15 nach Zeilen)
    - `Shelf Notes/BookImport/BookImportViewModel.swift` — **1007 Zeilen**
  - Zweck: Google-Books Import ViewModel (Suche, Filter, Pagination, Cancellation, Undo, Library-Dedupe).
  - Warum riskant: Risk: groß + viel State + MainActor; Regression-Gefahr bei Cancellation/Pagination.
- `Shelf Notes/BookDetail/BookDetailView+Logic.swift` — **613 Zeilen**
  - Zweck: BookDetailView: Bindings + Derived Props + Mutations (Status, Collections, Ratings, Links, etc.).
  - Warum riskant: Risk: viele Derived Props; falsche Saves/Bindings → Inkonsistenzen + exzessive invalidations.
- `Shelf Notes/CoverThumbnailer.swift` — **558 Zeilen**
  - Zweck: Thumbnail-Pipeline (ImageIO), remote cover handling, Backfill-Job, Save/Sync Touchpoints.
  - Warum riskant: Risk: CPU/Memory + I/O; häufige Saves → CloudKit churn; Datenkorruption bei File/Thumbnail mismatch.
- `Shelf Notes/BookDetail/BookDetailComponents.swift` — **551 Zeilen**
  - Zweck: Book Detail UI Components (Parallax Header, Cover Picker, PreferenceKeys, Sheets).
  - Warum riskant: Risk: Layout/GeometryReader/PreferenceKeys → re-render cost; schwer debuggbar bei Nav/Scroll.
- `Shelf Notes/AppearanceSettingsView.swift` — **537 Zeilen**
  - Zweck: Settings: umfangreiche Appearance-Presets + Controls + Persistenz via @AppStorage.
  - Warum riskant: Risk: Compiler/Generics + viele @AppStorage; State-Rebuild kann Nav resetten (teilweise mitigiert).
- `Shelf Notes/Challenges/ChallengeEngine.swift` — **525 Zeilen**
  - Zweck: Challenge Engine: Generierung + Progress-Berechnung (fetch/aggregate) + Saves.
  - Warum riskant: Risk: @MainActor Aggregationen (Sessions/Books fetch) → UI hitches bei großen Daten.
- `Shelf Notes/Stats/StatisticsView+Data.swift` — **459 Zeilen**
  - Zweck: Statistik-Aggregationen/Helpers (Filter/Group/Top lists).
  - Warum riskant: Risk: O(n) Filter/Aggregationen in computed props; wiederholte Ausführung im Renderpfad.
- `Shelf Notes/Stats/StatisticsView+Sections.swift` — **456 Zeilen**
  - Zweck: Statistik-UI Sections (Charts/Lists/Heatmap Einbindung) – viel SwiftUI generic work.
  - Warum riskant: Risk: großer SwiftUI body → Compile-Time + View invalidation schwer zu verstehen.
- `Shelf Notes/LibraryRowAppearanceSettingsSection.swift` — **454 Zeilen**
  - Zweck: UI for library row/cover customization (viele Settings, Controls).
  - Warum riskant: Risk: viele Controls → Compile-Time + Zustandssynchronisation via AppStorage.
- `Shelf Notes/Book.swift` — **428 Zeilen**
  - Zweck: Zentrales Model + Migration + Cover/Rating Helpers.
  - Warum riskant: Risk: sehr viele Felder + Business Rules; Model-Änderungen wirken überall.
- `Shelf Notes/LibraryView+Header.swift` — **418 Zeilen**
  - Zweck: Library header/filter bar + UI state + quick sort etc.
  - Warum riskant: Risk: Filter UI + Derived Cache Trigger; falsches Debounce → UI lag.
- `Shelf Notes/ReadingTimerManager.swift` — **402 Zeilen**
  - Zweck: Timer/Session runtime (start/stop, scene handling, pending completion sheet).
  - Warum riskant: Risk: Timer/ScenePhase edge cases; duplicate session completion sheets.
- `Shelf Notes/Stats/StatisticsView+Heatmap.swift` — **373 Zeilen**
  - Zweck: Heatmap Data/Layouts (calendar mapping, counts, weeks).
  - Warum riskant: Risk: Calendar math; off-by-one in week ranges; Performance bei vielen days.
- `Shelf Notes/CSVImportExportView.swift` — **364 Zeilen**
  - Zweck: CSV Import/Export UI + parsing + preview + bulk insert.
  - Warum riskant: Risk: Bulk inserts + parsing; MainActor contention, huge saves.
- `Shelf Notes/LibraryRowCoverView.swift` — **356 Zeilen**
  - Zweck: Cover rendering in rows (memory cache, async fetch, thumbnail decode).
  - Warum riskant: Risk: Image decoding on main, cache invalidation; memory growth.

    ## Hot Path Analyse

    ### Rendering / Scrolling (SwiftUI)
    **Beobachtete/ableitbare Hotspots (mit konkretem Grund):**
    - `Shelf Notes/TagsView.swift`
      - Grund: `tagCounts` wird als computed property jedes Render neu aus `books` berechnet (**O(n)** über alle Bücher + sort), ohne Cache → **exzessive View invalidation** bei jeder SwiftUI-Update-Welle.
    - `Shelf Notes/ProgressHubView.swift`
      - Grund: mehrere `@Query` ohne Predicate (books/sessions/goals/challenges) + viele `filter`/Aggregation in Helpers → **heavy filter/sort im Renderpfad** (auch wenn in Funktionen, werden sie im body-Kontext genutzt).
    - `Shelf Notes/Stats/StatisticsView+Data.swift` + `StatisticsView+Sections.swift`
      - Grund: viele Aggregationen über `books` (`filter`, `reduce`, `Set`-Builds, Top-Lists) → potenziell **CPU-heavy computations im UI layer**.
      - Positiv: es existiert bereits ein Cache-Ansatz (`Shelf Notes/Stats/StatisticsView+Caching.swift`).
    - `Shelf Notes/BookDetail/BookDetailComponents.swift`
      - Grund: `GeometryReader` + PreferenceKeys + Parallax → **layout-driven invalidations** können teuer werden, v.a. bei Scroll.
    - `Shelf Notes/LibraryView.swift` + `LibraryView+FilteringSorting.swift`
      - Positiv/Pattern: Die View cached derived state und debounced Search (`pendingRecomputeTask`) → **gute Entschärfung** eines klassischen Hotspots (“Filter/Sort im body”).

    **Cover Rendering**
    - `Shelf Notes/LibraryRowCoverView.swift`
      - Positiv: explizites Ziel “side-effect free cover rendering” + Memory Cache (`SyncedThumbnailMemoryCache`).
      - Hotspot-Risiko: Image decoding / Data→UIImage/CGImage auf MainActor (**UNKNOWN**, abhängig von Implementierungsdetails in `LibraryRowCoverView.swift` und `CoverImageLoader.swift`).

    ### Sync / Storage (SwiftData + CloudKit)
    **Fundament:**
    - `Shelf Notes/AppContainerHostView.swift`
      - `ModelContainerFactory` nutzt `cloudKitDatabase: .automatic` und eine feste `Schema([...])`.
      - Store separation: `ShelfNotesCloud.store` vs `ShelfNotesLocal.store` (bewusster Schutz vor “Store mixing”).
    - `Shelf Notes/ModelContext+Diagnostics.swift` + `Shelf Notes/SyncDiagnostics.swift`
      - SwiftData bietet keine CloudKit-Progress; es werden “Signals” (last save, offline count, iCloud status) gemessen.

    **Hotspot-Risiken (konkrete Gründe):**
    - Häufige `save()`-Calls → CloudKit churn
      - Beispiele:
        - `Shelf Notes/CoverThumbnailer.swift`: Backfill/Refresh schreibt `book.userCoverData` und speichert oft pro Book.
        - `Shelf Notes/Challenges/ChallengeEngine.swift`: `ensureCurrentChallenges`, `refreshCompletionForActiveChallenges` speichern ggf. mehrfach (je nach Call-Sites).
      - Effekt: mehr Hintergrund-Sync-Work + potenzielle UI-Stalls (SwiftData Save kann main-affin sein) + Batterie.
    - Bulk-Import/Export
      - `Shelf Notes/CSVImportExportView.swift` + `Shelf Notes/CSVCodec.swift`: Bulk Inserts/Updates → potenziell große Transaktionen/Saves.

    **Offline / Fallback**
    - Local-only Mode hat eigenen Datensatz (explizit, nicht “silent”) → UX klar, aber “Daten erscheinen weg” möglich, wenn User nicht versteht (wird per Banner/Alert adressiert).
    - In-memory Mode: Notfall (Debug/Support).

    ### Concurrency (MainActor, Task lifetimes, cancellation)
    - Projekt-Setting: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (in `Shelf Notes.xcodeproj/project.pbxproj`)
      - Konsequenz: **jede** nicht annotierte Funktion/Type ist standardmäßig MainActor-isoliert → **MainActor contention** wird wahrscheinlicher.
      - Positiv: reduziert Data-Races; Negativ: kann Hintergrundarbeit unabsichtlich auf Main ziehen.
    - Gute Patterns:
      - `Shelf Notes/BookImport/BookImportViewModel.swift`: explizite Task-Handles (`searchTask`, `loadMoreTask`, `debouncedRefreshTask`) + Generation Counter → **saubere cancellation + stale response handling**.
      - `Shelf Notes/CoverThumbnailer.swift`: ImageIO/Thumbnail work via `Task.detached` + `autoreleasepool` → CPU/Memory weg vom Main.
      - `Shelf Notes/LibraryView.swift`: Debounce bei Typing → weniger “work per keystroke”.
    - Risk Patterns / Stellen zum Prüfen:
      - Aggregations als `var ...: [Book]` / `var ...: Int` computed properties (Stats/Tags/ProgressHub)
        - Grund: werden potentiell mehrfach pro Render aufgerufen → **unbounded recomputation**.
      - Timer / ScenePhase Edge Cases (`Shelf Notes/ReadingTimerManager.swift`)
        - Grund: long-running tasks + lifecycle events → **Task lifetimes** / duplicate completion sheets (konkret prüfen).

    ## Refactor Map

    ### Konkrete Splits (mechanisch, “weniger Verantwortung pro Datei”)
    - `Shelf Notes/BookImport/BookImportViewModel.swift` (1007 Zeilen)
      - Cut-Vorschlag:
        - `BookImportViewModel.swift` (Facade + Published State)
        - `BookImportViewModel+Tasks.swift` (debounce/search/pagination/cancellation)
        - `BookImportViewModel+Filtering.swift` (applyLocalFilters + dedupe)
        - `BookImportViewModel+LibraryIndex.swift` (libraryVolumeIDs/ISBN index building)
      - Risiko: niedrig–mittel (viel State, aber rein mechanisch wenn keine Logikänderung).
    - `Shelf Notes/AppearanceSettingsView.swift` (537 Zeilen)
      - Cut-Vorschlag:
        - `AppearanceSettingsView.swift` (Host + Navigation + Toolbar)
        - `AppearanceSettingsView+Presets.swift`
        - `AppearanceSettingsView+Typography.swift`
        - `AppearanceSettingsView+Colors.swift`
        - `AppearanceSettingsView+Density.swift`
      - Risiko: niedrig (mechanisch, UI-only).
    - `Shelf Notes/BookDetail/BookDetailView+Logic.swift` (613 Zeilen)
      - Cut-Vorschlag:
        - `BookDetailView+Bindings.swift`
        - `BookDetailView+DerivedState.swift`
        - `BookDetailView+Mutations.swift` (Status/Collections/Ratings/Cover)
      - Risiko: niedrig (mechanisch), hoher “Orientierungsgewinn”.

    ### Cache-/Index-Ideen (was cachen, Keys, Invalidations)
    - Tags Index (Tab “Tags”)
      - Key: `booksSignature` ähnlich `StatisticsView+Caching.swift` (oder nur `books.count` + hash(tags)).
      - Value: `[(tag, count)]` sortiert, als `@StateObject`/ViewModel, recompute on change.
      - Files: `Shelf Notes/TagsView.swift` (+ new `TagsIndexModel.swift`).
    - ProgressHub KPIs (“Dein Stand”)
      - Cache: finished-this-year count, last7Days stats, goal target, streak.
      - Invalidation: bei `booksSignature` oder “sessionsSignature” (Count + day stamps).
      - Files: `Shelf Notes/ProgressHubView.swift` (+ new `ProgressHubSnapshotModel.swift`).
    - Cover thumbnail backfill
      - Batch-save: pro N Books ein `saveWithDiagnostics()` statt pro Book.
      - Invalidation: `did_run_cover_backfill_v2` ist bereits vorhanden; zusätzlich “last processed book id” optional (für resilienz).
      - Files: `Shelf Notes/CoverThumbnailer.swift`, `Shelf Notes/RootView.swift`.

    ### Vereinheitlichungen (Patterns, Services, DI)
    - Einheitliches “Derived Data” Pattern:
      - `LibraryView` + `StatisticsView` haben bereits caching/debounce signatures.
      - Kandidaten, die nachziehen sollten: `TagsView`, `ProgressHubView`, ggf. `ChallengesSummaryCard` (falls aggregiert).
    - “Save Discipline”:
      - Mutations überall über `saveWithDiagnostics()` (bereits häufig), aber Bulk-Flows sollten Save-Batching nutzen.

    ## Risiken & Edge Cases
    - **CloudKit/SwiftData Constraints**
      - Optional Relationships sind bewusst → Edge Cases bei nil vs empty arrays (z.B. Collections/Books).
      - Keine Unique Constraints → Deduping muss “appseitig” passieren (Import macht das teilweise).
    - **Local-only Store Separation**
      - Vorteil: kein “accidental mixing”.
      - Risiko: User kann in local-only Daten erzeugen, später CloudKit wieder ok → “wo sind meine Daten?” (UI-Banner/Alert existiert).
    - **Covers (Disk vs Sync)**
      - Full-res Cover ist lokal, Thumbnail synced → Gerätewechsel kann “nur Thumbnail” zeigen (beabsichtigt).
      - File cleanup/retention: Implementierung in `UserCoverStore`/`CoverImageLoader` prüfen (UNKNOWN ob es Garbage Collection gibt).
    - **Global MainActor Isolation**
      - Kann unabsichtlich I/O/CPU auf Main ziehen → bei “größerer Library” potentiell spürbar.

    ## Observability / Debuggability
    - `Shelf Notes/SyncDiagnosticsView.swift`
      - iCloud Account Status, Network Status (NWPathMonitor), last local save source, offline-save counter.
      - `SyncDiagnostics.diagnosticsReport()` erzeugt einen Text-Report (geeignet für Support/Logs).
    - `ModelContext.saveWithDiagnostics(file:line:)`
      - Speichert “Breadcrumb” (File:Line) → sehr hilfreich zum Finden von “wer hat zuletzt gespeichert”.

    ## Open Questions (alles, was als UNKNOWN markiert wurde)
    - `aps-environment` ist in `Shelf Notes/Shelf_Notes.entitlements` aktuell `development` — ist für Release/Distribution `production` sichergestellt?
    - `LibraryRowCoverView` decoding pipeline: passiert Data→Image Decoding garantiert off-main (oder teilweise auf Main)?
    - Cover File Retention: gibt es Cleanup/GC für alte `userCoverFileName` Dateien?
    - Conflict UX: Gibt es eine definierte Strategie, wenn SwiftData/CloudKit Konflikte auflöst (z.B. “last writer wins”)? (Kein expliziter Code gefunden.)

    ## First 3 Refactors I would do (P0)
    1. **Stats/Progress Aggregationen konsequent off-main + Snapshot-Model**
       - Ziel: Rendering stabilisieren, keine O(n)-Aggregationen in SwiftUI body/update-Wellen.
       - Betroffene Dateien:
         - `Shelf Notes/Stats/StatisticsView+Caching.swift`
         - `Shelf Notes/Stats/StatisticsView+Data.swift`
         - `Shelf Notes/ProgressHubView.swift`
         - optional neu: `Shelf Notes/Stats/StatisticsSnapshotModel.swift`, `Shelf Notes/ProgressHubSnapshotModel.swift`
       - Risiko: mittel (Concurrency/State), aber lokal begrenzbar.
       - Erwarteter Nutzen: spürbar weniger UI-Hitches bei großen Libraries + klarere Verantwortlichkeiten.

    2. **Secrets-Hygiene: API-Key aus Git raus**
       - Ziel: Kein Google API Key im Repo, klare lokale Developer-Setup Steps.
       - Betroffene Dateien:
         - `Shelf Notes/config/secrets.xcconfig` (aktuell Key im Klartext)
         - optional neu: `Shelf Notes/config/secrets.local.xcconfig` (untracked) + `.gitignore`
         - `Shelf Notes/Info.plist` bleibt gleich (nutzt `$(GOOGLE_BOOKS_API_KEY)`).
       - Risiko: niedrig (Build/Config), aber “wer hat welchen Key” muss geklärt werden.
       - Erwarteter Nutzen: Security + saubere Repo-Hygiene + weniger “oops”.

    3. **Mechanischer Split: BookImportViewModel + BookDetail Logic**
       - Ziel: Compile-Time runter, weniger Merge-Konflikte, bessere Orientierung.
       - Betroffene Dateien:
         - `Shelf Notes/BookImport/BookImportViewModel.swift`
         - `Shelf Notes/BookDetail/BookDetailView+Logic.swift`
       - Risiko: niedrig–mittel (viel State), aber mechanisch testbar.
       - Erwarteter Nutzen: schnelleres Navigieren, geringere kognitive Last, bessere Testbarkeit.
