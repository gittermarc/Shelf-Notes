# ARCHITECTURE_NOTES.md

> Stand: 2026-02-25 (aus dem gelieferten ZIP).  
> Fokus nach Priorität: Sync/Storage/Model → Entry Points/Navigation → große Views/Services → Konventionen/Workflows.

## 1) Big Files List (Top 15 nach Zeilen)

| Lines | File | Purpose / Why risky |
|---:|---|---|
| 562 | `Shelf Notes/BookImport/BookImportView/BookImportViewModel.swift` | Google Books Import ViewModel (Networking + State + Indexing); risk: monolith, async/task orchestration, UI jank if work on main |
| 459 | `Shelf Notes/Stats/StatisticsView+Data.swift` | Stats data/aggregation helpers; risk: O(n) scans over books/sessions, can leak into render path if misused |
| 456 | `Shelf Notes/Stats/StatisticsView+Sections.swift` | Stats UI sections/composition; risk: complex view state/DisclosureGroups, re-render storms |
| 454 | `Shelf Notes/LibraryView/LibraryRowAppearanceSettingsSection.swift` | Settings sub-UI for library row appearance; risk: merge conflicts + hard to review |
| 435 | `Shelf Notes/Challenges/ChallengeEngine+Compute.swift` | Off-main challenge progress computation; risk: correctness bugs + expensive aggregation |
| 428 | `Shelf Notes/Book.swift` | Primary SwiftData model with many persisted fields + helpers; risk: model bloat + migrations/CloudKit payload |
| 418 | `Shelf Notes/LibraryView/LibraryView+Header.swift` | Library header UI + controls; risk: state coupling + frequent invalidations |
| 406 | `Shelf Notes/BookImport/BookImportView/BookImportViewModel+Tasks.swift` | Import async tasks orchestration; risk: cancellation, duplicated requests, race conditions |
| 376 | `Shelf Notes/BookDetail/BookDetailView+Bindings.swift` | Derived state / computed bindings in BookDetail; risk: expensive computed props per keystroke |
| 373 | `Shelf Notes/Stats/StatisticsView+Heatmap.swift` | Heatmap computation + rendering; risk: data-heavy, can be O(days*sessions) |
| 364 | `Shelf Notes/CSVImportExportView.swift` | CSV import/export UI + logic; risk: large I/O in UI thread, data loss edge cases |
| 356 | `Shelf Notes/LibraryView/LibraryRowCoverView.swift` | Row cover decode/downscale/memory cache; risk: many concurrent tasks in large lists |
| 355 | `Shelf Notes/ForYouSeedBuilder.swift` | Recommendation/seed generation; risk: data-wide scans + heavy sorts |
| 354 | `Shelf Notes/AppearanceSettings/AppearancePreferences.swift` | Appearance preference model / enums / helpers; risk: lots of keys, fragmentation, regressions |
| 342 | `Shelf Notes/CachedAsyncImage.swift` | Image cache/store + UserCoverStore; risk: file I/O + memory pressure + decode |


## 2) Hot Path Analyse

### 2.1 Rendering / Scrolling (SwiftUI)

#### A) LibraryView Filter/Sort im Renderpfad (O(n log n) pro UI-Update)

- Datei: `Shelf Notes/LibraryView/LibraryView+FilteringSorting.swift`
- Problem: `filteredBooks` + `sortBooks()` sind als **computed properties**/Funktionen im View-Extension-Layer implementiert und werden bei vielen State-Changes neu ausgewertet (Search-Typing, Filter toggles, Header expand/collapse).
- Konkreter Grund:
  - `var filteredBooks: [Book]` filtert `books` pro Update.
  - `var displayedBooks: [Book]` ruft `sortBooks(filteredBooks)` auf → `.sorted` (O(n log n)).
- Risiko: UI-Hänger bei größerer Bibliothek (viele Bücher) + “janky” Search.

#### B) Cover-Rendering: viele parallele `.task`-Loads in Listen

- Datei: `Shelf Notes/LibraryView/LibraryRowCoverView.swift`
- Mechanik:
  - `.task(id: cacheKey)` lädt `book.userCoverData` → decode/downscale off-main → memory cache.
- Konkreter Grund:
  - In langen Listen können viele Row-Tasks gleichzeitig starten (Scroll), selbst wenn Decode off-main ist.
- Risiko:
  - Memory pressure (UIImage caching) + Task churn + “decode thrash” beim schnellen Scrollen.

#### C) BookDetail derived state bei Interaktion (Tippen, Tags, etc.)

- Datei: `Shelf Notes/BookDetail/BookDetailView+Bindings.swift`
- Risiko-Mechanik:
  - Viele derived/computed Werte in einem großen File; wenn dort Iterationen über Sessions/Tags stattfinden, invalidiert SwiftUI häufiger (z.B. beim Tippen in TextFields).
- Status im Code:
  - Es gibt bereits Task-ID Tokens (z.B. `.task(id: tagsIndexTaskKey)` in `Shelf Notes/BookDetailView.swift`) und ein Tag-Index-Model (`Shelf Notes/TagsView/TagsIndexModel.swift`), aber Bindings bleiben ein klassischer Hotspot-Kandidat.

#### D) Stats & Heatmap: data-heavy, aber bereits caching-bewusst

- Dateien:
  - `Shelf Notes/StatisticsView.swift`
  - `Shelf Notes/Stats/StatisticsView+Caching.swift`
  - `Shelf Notes/Stats/StatisticsView+Heatmap.swift`
- Gute Nachricht:
  - Stats-Caches werden via Signature invalidiert und in `.task(id: ...)` berechnet.
  - Signature ist order-independent (kein sort) → verhindert UI-Hitching durch deterministisches Sorting `Shelf Notes/Stats/StatisticsView+Caching.swift`.
- Rest-Risiko:
  - Wenn Heatmap/Stats-Compute intern doch “deep” über Sessions läuft, kann es bei großen Historien spürbar werden.
  - Besonders wenn der Cache invalidiert wird (z.B. viele Sync-Updates kurz nacheinander).

### 2.2 Sync / Storage (SwiftData + CloudKit)

#### A) Container Bootstrap + Store-Separation (stark, aber mit UX/Support-Risiken)

- Datei: `Shelf Notes/AppContainerHostView.swift`
- Was passiert:
  - CloudKit Store wird initial versucht, bei Fehler: **kein Crash**, sondern Recovery UI.
  - Fallback “Local-only” ist explizit und nutzt separaten Store (`ShelfNotesLocal.store`).
- Tradeoff:
  - Sehr robust gegen iCloud/CloudKit Setup-Probleme.
  - Gleichzeitig entsteht “Data Divergence” als reales Support-Thema: Local-only Daten gehen nicht automatisch in CloudKit über.

#### B) Launch-time Repairs & “Ensure” Jobs

- Dateien:
  - `Shelf Notes/AppContainerHostView.swift` (Trigger via `.task(id: mode)`)
  - `Shelf Notes/CollectionMembershipRepair.swift`
  - `Shelf Notes/Challenges/ChallengeEngine.swift` (+ Snapshot/Compute)
- Konkreter Grund:
  - Beim Eintritt in `.ready` läuft:
    - `CollectionMembershipRepair.repairIfNeeded(...)`
    - `ChallengeEngine.ensureCurrentChallengesAndRefreshCompletion(...)`
- Risiko:
  - Beide Pfade machen Fetches über den `ModelContext` (main-actor-bound).
  - Bei großen Datenmengen kann der erste “interactive frame” spürbar verzögert werden.

#### C) Cover Thumbnail Backfill ist @MainActor und kann groß werden

- Dateien:
  - Trigger: `Shelf Notes/RootView.swift` (`scheduleCoverBackfillIfNeeded`)
  - Implementierung: `Shelf Notes/CoverThumbnailer/CoverThumbnailer+Backfill.swift`
- Konkreter Grund:
  - `CoverThumbnailer.backfillAllBooksIfNeeded(...)` ist `@MainActor` und macht `FetchDescriptor<Book>()` (alle Bücher).
  - Danach Filter + Loop über pending Books; zwar mit `Task.yield()`/`Task.sleep`, aber es bleibt MainActor-lastig.
- Risiko:
  - MainActor contention (Scroll/Animations) bei sehr großen Libraries, v.a. beim ersten App-Start nach Update.

### 2.3 Concurrency (MainActor, Tasks, Cancellation)

#### A) “ModelContext is main-actor-bound” ist konsequent umgesetzt – aber teuer

- Beispiele:
  - `CoverThumbnailer+Backfill` ist bewusst `@MainActor` (Kommentar in Datei).
  - Repairs/Ensure Jobs laufen im Container `.task`.
- Risiko:
  - Alles, was zu viel iteriert/fetched, blockiert auch “kleine” UI-Aktionen.

#### B) Good Pattern: Snapshot + Off-main Compute (Challenges)

- Dateien: `Shelf Notes/Challenges/ChallengeEngine+Snapshot.swift`, `Shelf Notes/Challenges/ChallengeEngine+Compute.swift`
- Pattern:
  - Snapshot: value-only aus SwiftData holen.
  - Compute: Progress/Targets off-main.
  - Apply: zurück auf MainActor/ModelContext.
- Empfehlung:
  - Dieses Pattern ist der “Goldstandard” für weitere data-heavy Bereiche (Cover Backfill, große Stats-Recompute, Import-Matching).

#### C) Task-ID Tokens statt Arrays (bereits implementiert)

- Dateien:
  - `Shelf Notes/TagsView/TagsView.swift` + `TagsIndexModel.swift`
  - `Shelf Notes/Timeline/ReadingTimelineView.swift` + `ReadingTimelineViewModel.swift`
  - `Shelf Notes/ProgressHub/ProgressHubView.swift` + `ProgressHubMetricsModel.swift`
- Nutzen:
  - Reduziert exzessive Task Re-runs und “work storms” bei kleinen State-Änderungen.

## 3) Refactor Map (konkret)

### 3.1 Konkrete Splits (Maintainability)

- `Shelf Notes/BookImport/BookImportView/BookImportViewModel.swift` (562 LOC)
  - Split-Kandidaten:
    - `BookImportViewModel+Networking.swift` (Google Books calls + retry/backoff)
    - `BookImportViewModel+Mapping.swift` (DTO → ImportedBook/Book)
    - `BookImportViewModel+State.swift` (UI state + bindings)
    - (teilweise existiert schon) `BookImportViewModel+Filtering.swift`, `+LibraryIndex.swift`, `+Tasks.swift`
  - Ziel: weniger “God object”, klarere Cancellation & request dedupe.

- `Shelf Notes/LibraryView/LibraryRowAppearanceSettingsSection.swift` (454 LOC)
  - Split nach Subsections:
    - Cover / Typography / Badges / Spacing / Reset
  - Ziel: Merge-Konflikte reduzieren (mechanisch, niedriges Risiko).

### 3.2 Cache-/Index-Ideen (Performance)

- LibraryView:
  - Ziel: `displayedBooks` nicht als computed property im Renderpfad.
  - Idee:
    - `LibraryListModel` (ObservableObject) mit:
      - Input Token (booksSignature + filter/sort/search settings)
      - Background compute (filter + sort) → published result
    - Apply: UI rendert nur `model.displayedBooks`.
  - Betroffene Dateien:
    - `Shelf Notes/LibraryView/LibraryView.swift`
    - `Shelf Notes/LibraryView/LibraryView+FilteringSorting.swift`

- Cover Backfill:
  - Ziel: weniger “fetch all” + weniger main-actor work.
  - Idee:
    - FetchDescriptor mit Predicate “needs backfill” (falls SwiftData predicate für `userCoverData == nil` zuverlässig ist).
    - Snapshot IDs → background download/decode → main apply in batches.
  - Betroffene Dateien:
    - `Shelf Notes/CoverThumbnailer/CoverThumbnailer+Backfill.swift`
    - Trigger in `Shelf Notes/RootView.swift`

- Stats/Heatmap:
  - Aktueller Stand ist gut (Signature + Cache).  
  - Nächster Hebel (falls nötig): “deep” Session-Aggregation off-main via Snapshot (analog Challenges), dann UI-cache setzen.

### 3.3 Vereinheitlichungen (Patterns/Services/DI)

- Pattern “Signature Token + Background compute + Main apply” existiert mehrfach:
  - Stats, Timeline, Tags, ProgressHub, Challenges
- Vorschlag:
  - `Shared/Compute`-Helpers:
    - Token/Signature Utilities
    - “run compute off-main” wrapper (Task.detached + cancellation friendly)
- DI:
  - Momentan viele `@StateObject` (z.B. `ProManager`, `ReadingTimerManager`) direkt in RootView.
  - Option: kleines Environment “AppServices” (struct) für besseres Testen/Mocking.
  - **UNKNOWN** ob Tests/Mocks bereits geplant sind.

## 4) Risiken & Edge Cases

- **Local-only Store Divergence**: Support/UX Risiko bei Nutzerwechsel zwischen CloudKit und Local-only `Shelf Notes/AppContainerHostView.swift`.
- **CloudKit Constraints**:
  - Optional Relationships + keine Unique Attributes (bewusst) – gut, aber erhöht Risiko für “duplicate semantics” auf App-Ebene.
- **Cover Storage**:
  - Synced thumbnails (Data) können CloudKit Payload erhöhen; externe Speicherung hilft, aber Datenmenge bleibt relevant `Shelf Notes/Book.swift`.
  - Full-res Covers sind lokal (nicht synced). Multi-device kann daher unterschiedliche Full-res haben (Thumbnail bleibt synced).
- **Timer + Session Logging**:
  - Session-Logik ist zentralisiert `Shelf Notes/BookDetail/Sessions/ReadingSessionLogging.swift` – gut für Korrektheit, aber sollte testbar bleiben.
- **Repairs**:
  - `CollectionMembershipRepair` macht Full-scan Fetches; sollte wirklich “once per store scope” bleiben (Keyed in AppStorage / UserDefaults).

## 5) Observability / Debuggability

- `SyncDiagnostics` (CloudKit + Network + last-save counters) `Shelf Notes/SyncDiagnostics.swift`
- `ModelContext+Diagnostics.swift` (zusätzliche Diagnostics/Hilfen) `Shelf Notes/ModelContext+Diagnostics.swift`
- Repro-Tipps:
  - Sync-Probleme: Settings → `SyncDiagnosticsView` (Task-driven refresh) `Shelf Notes/SyncDiagnosticsView.swift`
  - Performance: Library mit vielen Büchern → Search tippen + schnell scrollen (Cover tasks)
  - Cold launch: beobachten ob UI “spürbar” später reagiert (Repairs/Ensure/Backfill)

## 6) Open Questions (alles UNKNOWN)

- **CloudKit DB Auswahl**: `cloudKitDatabase: .automatic` – konkrete DB (private/shared/public) → **UNKNOWN** `Shelf Notes/AppContainerHostView.swift`
- **Migration/Schema Evolution**: Kein expliziter Migrationslayer gefunden → **UNKNOWN** (wie werden breaking changes gehandhabt?)
- **Conflict resolution**: SwiftData/CloudKit conflict policy ist nicht explizit gesetzt → **UNKNOWN**
- **Secrets Policy**: `config/secrets.xcconfig` liegt im Projekt-ZIP inkl. Key → **UNKNOWN** ob das im Repo bewusst so ist oder nur lokal.
- **Performance budgets**: Kein definierter “large library” Target (z.B. 5k books / 50k sessions) → **UNKNOWN**

## 7) First 3 Refactors I would do (P0)

### P0.1 — LibraryView Filter/Sort aus dem Renderpfad ziehen

- **Ziel**: Search/Filter/Sort bleibt auch bei großen Libraries flüssig.
- **Betroffene Dateien**:
  - `Shelf Notes/LibraryView/LibraryView.swift`
  - `Shelf Notes/LibraryView/LibraryView+FilteringSorting.swift`
- **Risiko**: niedrig–mittel (Sortier-/Filter-Regression möglich; muss mit Golden Tests/Manueller QA abgesichert werden).
- **Erwarteter Nutzen**:
  - Weniger O(n log n) pro UI-Update.
  - Weniger “typing lag” in Search.
  - Klarere Trennung: UI vs. Compute.

### P0.2 — Launch-time MainActor Work drosseln (Repairs + Backfill + Challenge Ensure)

- **Ziel**: First frame / App-Ready nicht blockieren; Hintergrundarbeit kontrolliert und cancelbar.
- **Betroffene Dateien**:
  - `Shelf Notes/AppContainerHostView.swift`
  - `Shelf Notes/CollectionMembershipRepair.swift`
  - `Shelf Notes/CoverThumbnailer/CoverThumbnailer+Backfill.swift`
  - `Shelf Notes/Challenges/ChallengeEngine.swift` (+ Snapshot/Compute)
- **Risiko**: mittel (Timing-Bugs: z.B. UI zeigt kurz “alte” Daten, oder Repairs laufen nicht).
- **Erwarteter Nutzen**:
  - Besseres Startgefühl (kein “App hängt kurz”).
  - Weniger MainActor contention beim ersten Scroll.

### P0.3 — Secrets-Handling harden (GOOGLE_BOOKS_API_KEY)

- **Ziel**: Kein Klartext-Key in Source Control / geteilten ZIPs.
- **Betroffene Dateien**:
  - `Shelf Notes/config/secrets.xcconfig`
  - `.gitignore` (liegt im ZIP: `Shelf Notes/.gitignore`)
  - ggf. `Shelf Notes/Info.plist` (`GOOGLE_BOOKS_API_KEY`)
- **Risiko**: niedrig (Build/CI kann kurz brechen, wenn Key nicht gesetzt ist).
- **Erwarteter Nutzen**:
  - Security/Compliance + weniger “Oops, Key geleakt”.
  - Klare Setup-Schritte für neue Devs (Template + env var).

