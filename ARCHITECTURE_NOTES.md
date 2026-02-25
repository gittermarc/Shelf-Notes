# ARCHITECTURE_NOTES.md

## Big Files List (Top 15 nach Zeilen)

- `Shelf Notes/BookImport/BookImportView/BookImportViewModel.swift` — **562 Zeilen**
  - Zweck: ViewModel für Google Books Import Flow (State, Mapping, Persist).
  - Warum riskant: Viel State + Async/Combine + SwiftData ⇒ hohes Regression-/Race-Risiko, schwer testbar; Compile-Zeit/Review-Noise.

- `Shelf Notes/BookDetail/BookDetailComponents.swift` — **551 Zeilen**
  - Zweck: Große Sammlung an Book-Detail Subviews/Helpern (Header/Parallax, Picker, Cards, etc.).
  - Warum riskant: Monolithische UI-Komponenten-Datei ⇒ Merge-Konflikte, schwer lokalisierbare UI-Perf-Probleme; viele @State Bindings über Grenzen.

- `Shelf Notes/Challenges/ChallengeEngine.swift` — **525 Zeilen**
  - Zweck: Erzeugt Challenges + berechnet Progress aus Sessions/Books; markiert Completion.
  - Warum riskant: Compute/Fetch auf MainActor möglich (wird beim App-Ready getriggert); wächst mit Datenmenge; Logik+UI-Kopplungsgefahr.

- `Shelf Notes/Stats/StatisticsView+Data.swift` — **459 Zeilen**
  - Zweck: Datenermittlung/Aggregationen für StatisticsView (Filter, Series, Top-Lists, Nerd Corner).
  - Warum riskant: Viele Aggregationen/Sorts ⇒ Gefahr, dass Teile im Renderpfad laufen; schwer zu isolieren/benchmarken.

- `Shelf Notes/Stats/StatisticsView+Sections.swift` — **456 Zeilen**
  - Zweck: UI-Section Builder für StatisticsView (Cards, Charts, Lists).
  - Warum riskant: Viele SwiftUI View-Builders ⇒ Compile-Time + SwiftUI invalidation hotspots; schwer zu navigieren.

- `Shelf Notes/LibraryView/LibraryRowAppearanceSettingsSection.swift` — **454 Zeilen**
  - Zweck: Library Row/Cover Appearance Settings UI (viele Optionen/Controls).
  - Warum riskant: Große Settings UI ⇒ schnelle Iterationen führen zu Merge-Konflikten; kann Tab/Navigation reset triggern.

- `Shelf Notes/Book.swift` — **428 Zeilen**
  - Zweck: Größtes @Model: Persisted Felder, Convenience, Migration (ReadingStatusMigrator), Cover helper.
  - Warum riskant: Riesiges Modell ⇒ Migration/Schema-Risiko; viele Felder erhöhen Sync-Payload; Änderungen sind hochsensitiv.

- `Shelf Notes/LibraryView/LibraryView+Header.swift` — **418 Zeilen**
  - Zweck: Header UI + Interaktionen für LibraryView (Filter/Segmente/Suche/Counts).
  - Warum riskant: Header animiert Layout ⇒ viele invalidations; Gefahr von O(n) recompute ohne caching.

- `Shelf Notes/BookImport/BookImportView/BookImportViewModel+Tasks.swift` — **406 Zeilen**
  - Zweck: Async Tasks: Search/Debounce/Pagination/Cancellation für Import.
  - Warum riskant: Task-Lifetime/Cancellation korrekt zu halten ist tricky; UI kann schnell “stale results” zeigen.

- `Shelf Notes/Timeline/ReadingTimerManager.swift` — **402 Zeilen**
  - Zweck: Timer/Session Management (Start/Stop, Auto-Stop, Pending Completion Sheet).
  - Warum riskant: Long-lived state + ScenePhase + Background ⇒ Edge Cases (sleep/resume) & Datenintegrität für Sessions.

- `Shelf Notes/BookDetail/BookDetailView+Bindings.swift` — **376 Zeilen**
  - Zweck: Derived Bindings/Computed State für BookDetail (Tags, Autocomplete, formatted strings, etc.).
  - Warum riskant: Derived State kann leicht O(n) werden; viele computed properties triggern Re-render; Access-Control über Splits ist fehleranfällig.

- `Shelf Notes/Stats/StatisticsView+Heatmap.swift` — **373 Zeilen**
  - Zweck: Heatmap Aggregation + Rendering Helper.
  - Warum riskant: Viele Buckets/Date computations ⇒ Performance-Risiko bei großer Session-History.

- `Shelf Notes/CSVImportExportView.swift` — **364 Zeilen**
  - Zweck: CSV Import/Export UI + Parsing/Write; evtl. Bulk Ops.
  - Warum riskant: Large file handling + IO + SwiftData writes ⇒ UI hitching & cancellation/transaction issues.

- `Shelf Notes/LibraryView/LibraryRowCoverView.swift` — **356 Zeilen**
  - Zweck: Cover Rendering in Library rows (perf/side-effect free) inkl. caching, placeholder, etc.
  - Warum riskant: Hot path beim Scrollen; Decoding/IO muss off-main bleiben; jedes kleine Extra multipliziert sich mit Zeilen.

- `Shelf Notes/ForYouSeedBuilder.swift` — **355 Zeilen**
  - Zweck: Generiert 'For You' Seeds/Empfehlungsgrundlage (aus vorhandenen Books/Tags/etc.).
  - Warum riskant: Potentiell O(n) heuristics; falls im UI synchron ausgeführt: spürbare Hitches.


## Hot Path Analyse

### Rendering/Scrolling

- **Library scroll path**
  - Row cover decoding/caching: `Shelf Notes/LibraryView/LibraryRowCoverView.swift`, `Shelf Notes/CoverImageLoader.swift`, `Shelf Notes/CachedAsyncImage.swift`.
  - Derivation caching (Filter/Sort/Alpha Sections): `Shelf Notes/LibraryView/LibraryView.swift` + Extensions.
  - Hotspot-Grund: **expensive computations + image decode** multiplizieren sich pro visible row; SwiftUI invalidations können bei Header-Animationen viele Recomputes triggern.

- **Book Detail**
  - Viele Subviews/Sheets + derived state: `Shelf Notes/BookDetailView.swift`, `Shelf Notes/BookDetail/BookDetailComponents.swift`, `Shelf Notes/BookDetail/BookDetailView+Bindings.swift`.
  - Hotspot-Grund: **exzessive View invalidation** (viel @State) + Gefahr von **Aggregationen im computed state** (z.B. Tag-Autocomplete über gesamte Library).

- **Stats / Charts / Heatmap**
  - `Shelf Notes/StatisticsView.swift` + `Shelf Notes/Stats/*`.
  - Hotspot-Grund: **heavy sort/aggregation** + (optional) Charts rendering. Caches (`statsCache`, `heatmapCache`) sind vorhanden, aber die Update-Trigger müssen sauber “signature-driven” sein.

- **Timeline**
  - `Shelf Notes/Timeline/ReadingTimelineView.swift` + `ReadingTimelineViewModel.swift`.
  - Hotspot-Grund: **horizontal scroll + year grouping**; VM baut Snapshot (`taskSignature`) um Renderpfad zu entlasten.

### Sync/Storage

- **SwiftData + CloudKit bootstrap**: `Shelf Notes/AppContainerHostView.swift`
  - Hotspot-Grund: Container-Init + one-time Repairs/Ensures laufen beim App-Start.
  - Konkreter Codepfad: `.task(id: mode)` ruft `CollectionMembershipRepair.repairIfNeeded(...)` und anschließend `ChallengeEngine.ensureCurrentChallenges(...)` auf.

- **Saves + Diagnostics**: `Shelf Notes/ModelContext+Diagnostics.swift` + `Shelf Notes/SyncDiagnostics.swift`
  - Hotspot-Grund: Viele Saves (Import, Bulk Edit) können UserDefaults/Diagnostics-Spuren produzieren.

- **Cover Backfill**: `Shelf Notes/CoverThumbnailer/CoverThumbnailer+Backfill.swift` (und Trigger in `Shelf Notes/RootView.swift`)
  - Hotspot-Grund: potenziell viele Bücher ⇒ Backfill muss **chunked + cancellable** sein (ist als „idle/deferred“ kommentiert).

### Concurrency

- **Task lifetimes**
  - `ProManager` startet long-lived `updatesTask` (`Shelf Notes/ProManager.swift`).
  - Import/Search nutzt Tasks + Cancellation (`Shelf Notes/BookImport/...BookImportViewModel+Tasks.swift`).
  - Stats/Timeline/Tags nutzen `.task(id: signature)` Pattern.
  - Risiko: un-cancelled Tasks können stale UI state oder unnötige CPU verursachen.

- **MainActor contention**
  - `ChallengeEngine.ensureCurrentChallenges` ist `@MainActor` und wird beim Ready-State explizit auf dem MainActor ausgeführt.
  - Viele SwiftData Zugriffe passieren auf `container.mainContext` (MainActor-gebunden).

## Refactor Map

### Konkrete Splits (mechanisch)

- `Shelf Notes/BookDetail/BookDetailComponents.swift`
  - Vorschlag: Split nach Verantwortung (keine Logikänderung):
    - `BookDetailComponents+Header.swift` (Parallax/PreferenceKeys)
    - `BookDetailComponents+Cover.swift` (Cover Picker, OnlineCoverPickerSheet)
    - `BookDetailComponents+Cards.swift` (BookDetailCard + sections)
    - `BookDetailComponents+Helpers.swift` (kleine View-Helper)
  - Nutzen: weniger Merge-Konflikte, schnellere Navigation im Code, geringere Compile-Zeit.

- `Shelf Notes/Challenges/ChallengeEngine.swift`
  - Vorschlag:
    - `ChallengeEngine+Periods.swift` (week/month boundaries)
    - `ChallengeEngine+Generation.swift` (target selection, reroll rules)
    - `ChallengeEngine+Progress.swift` (Aggregationen aus Sessions/Books)
  - Nutzen: Testbarkeit + klarere Nebenwirkungen.

- `Shelf Notes/BookImport/BookImportView/BookImportViewModel.swift`
  - Bestehende Splits sind bereits kommentiert; falls weiter nötig:
    - `BookImportViewModel+Persistence.swift` (SwiftData writes/undo)
    - `BookImportViewModel+State.swift` (State structs)
  - Nutzen: Race-/Regression-Risiko runter.

### Cache-/Index-Ideen

- **Tags Index**
  - `TagsIndexModel` (in `Shelf Notes/TagsView/TagsIndexModel.swift`) ist bereits ein Muster für „Snapshot + Signature + cached counts“.
  - Hebel: Wiederverwenden überall, wo Tag-Aggregationen quer über die Library passieren (BookDetail Autocomplete, Bulk Tagging UI).

- **Stats Snapshots**
  - Wenn Stats weiterhin spürbar sind: Value-only Snapshot structs (Books/Sessions minimal) + compute in `Task.detached` (ähnlich CoverThumbnailer).

- **Cover Pipeline**
  - Trennung „raw bytes fetch“ vs „decode/resize“ ist vorhanden (`CoverImageLoader` vs `CoverThumbnailer+ImageIO`).
  - Hebel: zentrale Rate-Limits/Backpressure für Backfill + Import, um IO-Spikes zu vermeiden.

### Vereinheitlichungen

- **Signature-driven Tasks**: Pattern ist mehrfach vorhanden (`TagsView`, `ReadingTimelineView`, `StatisticsView`, `ProgressHubView`).
  - Hebel: ein gemeinsamer Helper (z.B. `TaskSignature.make(...)`) reduziert inkonsistente Token-Bildung.

- **Diagnostics**: `saveWithDiagnostics()` ist ein gutes Default. Hebel: konsequent überall nutzen, wo SwiftData saves passieren (Import, Bulk, Edit).

## Risiken & Edge Cases

- **CloudKit/SwiftData Schema**
  - Beziehungen sind optional, `.unique` wird vermieden — das ist korrekt, aber erhöht Risiko von Duplikaten/Inkonsistenzen. Repairs (`CollectionMembershipRepair`) sind daher wichtig.

- **Local-only Store ist separater Datenstand**
  - UX-Risiko: Nutzer kann versehentlich im Local-only Daten pflegen und später CloudKit nutzen → bewusstes Banner/Alert ist vorhanden (`AppContainerHostView`).

- **Cover-Dateien (Full-res)**
  - Full-res User covers liegen in `Application Support/user-covers` (siehe `UserCoverStore`).
  - Edge Case: Löschpfade müssen immer cleanup machen (Bulk delete + Detail delete).

- **One-time Migration**
  - `ReadingStatusMigrator` nutzt UserDefaults Key `did_migrate_reading_status_codes_v1`.
  - Edge Case: Mixed data (legacy + new) → einige Predicates berücksichtigen legacy Strings (z.B. Timeline filtert zusätzlich auf "Gelesen").

## Observability / Debuggability

- **SyncDiagnostics**
  - `Shelf Notes/SyncDiagnostics.swift` sammelt:
    - Network status via `NWPathMonitor`
    - CloudKit account status + user record ID (best-effort)
    - Last local save + error + source (via `ModelContext.saveWithDiagnostics`)
  - UI: `Shelf Notes/SyncDiagnosticsView.swift` (wird in Settings referenziert).

- **Repro-Strategie**
  - Für Sync-Probleme: in Settings SyncDiagnostics checken + bewusst offline schalten + save triggern.
  - Für Perf: Instrument „Time Profiler“ auf Scroll (Library) + Stats open/expand.

## Open Questions (UNKNOWNs)

- **StoreKit Product IDs**: `Shelf Notes/ProManager.swift` hat TODO/Platzhalter (`productID = "001"`). Welche Product IDs/Offerings sind final?
- **CloudKit Environment**: Entitlements enthalten iCloud container; APS steht auf `development`. Gibt es getrennte Dev/Prod Container/Build Configs?
- **Google Books API Key Handling**: Key kommt aus `config/secrets.xcconfig`. Gibt es eine CI/Build-Pipeline, die Secrets injiziert, ohne Repo-Leaks?
- **Data volume targets**: Erwartete Größenordnung (Bücher/Sessions/Tags) bestimmt, wie aggressiv Stats/Challenges off-main müssen.
- **Deletion semantics**: Soll das Löschen eines Books immer auch Sessions/cover files vollständig entfernen? (Cascade für Sessions ist gesetzt; Cover file cleanup hängt von UI-Pfaden ab.)

## First 3 Refactors I would do (P0)

### P0.1 — ChallengeEngine in Compute/IO trennen
- **Ziel**: Challenge-Erzeugung/Progress so schneiden, dass UI-Ready nicht am MainActor “hängt”.
- **Betroffene Dateien**: `Shelf Notes/Challenges/ChallengeEngine.swift`, ggf. `Shelf Notes/Challenges/ChallengeModels.swift`, `Shelf Notes/AppContainerHostView.swift`.
- **Risiko**: Mittel (Logik ist zentral, kann Completion beeinflussen).
- **Erwarteter Nutzen**: Weniger Launch-Hitches; bessere Testbarkeit und klarere Verantwortlichkeiten.

### P0.2 — BookDetailComponents.swift split (rein mechanisch)
- **Ziel**: 550+ Zeilen UI-Komponenten in sauber getrennte Files, ohne UI/Logik zu ändern.
- **Betroffene Dateien**: `Shelf Notes/BookDetail/BookDetailComponents.swift` (+ neue `BookDetailComponents+*.swift`).
- **Risiko**: Niedrig (wenn strikt mechanisch; nur Access-Control beachten).
- **Erwarteter Nutzen**: Wartbarkeit + deutlich weniger Merge-Konflikte; schnellere Compile/Review.

### P0.3 — BookImportViewModel: Persistenz & Undo isolieren
- **Ziel**: Import-VM entflechten: Search/Tasks vs. Persist/Writes vs. UI-State.
- **Betroffene Dateien**: `Shelf Notes/BookImport/BookImportView/BookImportViewModel.swift`, `...BookImportViewModel+Tasks.swift`.
- **Risiko**: Mittel (Import ist user-facing, Race Conditions möglich).
- **Erwarteter Nutzen**: Stabilere Cancellation, bessere Testbarkeit, leichteres Debugging von Import-Bugs.
