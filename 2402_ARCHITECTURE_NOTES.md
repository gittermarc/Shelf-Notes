# ARCHITECTURE_NOTES

_Generated from repository snapshot in `Shelf-Notes.zip` (analyzed on 2026-02-24)._

## Scope & Intent
- Fokus gemäß Prioritäten: **(1) Sync/Storage/Model**, dann **Entry Points + Navigation**, dann **große Views/Services**, dann **Conventions/Workflows**.
- Alles, was nicht eindeutig aus dem Code hervorgeht, ist als **UNKNOWN** markiert und in „Open Questions“ gesammelt.

## Big Files List (Top 15 nach Zeilen)

| # | Lines | Path | Grober Zweck | Warum riskant |
|---:|---:|---|---|---|
| 1 | 562 | `Shelf Notes/BookImport/BookImportView/BookImportViewModel.swift` | Import-ViewModel (State + Import-Flow) | viel State + Async/Networking → Bugs/Regressionen, schwer zu testen |
| 2 | 558 | `Shelf Notes/CoverThumbnailer.swift` | Thumbnail-Generierung + Backfill + User-Cover Handling | Bildverarbeitung + Disk I/O + SwiftData Save → Perf/Battery/Crash-Risiko |
| 3 | 551 | `Shelf Notes/BookDetail/BookDetailComponents.swift` | Detail-Subcomponents (Header/Sheets/Helpers) | UI-Komplexität + Scroll/Preference Keys → invalidations/State-Bugs |
| 4 | 525 | `Shelf Notes/Challenges/ChallengeEngine.swift` | Challenge Berechnung/Erzeugung/Completion | O(n) Aggregationen über Books/Sessions möglich; Logik zentral & schwer testbar |
| 5 | 459 | `Shelf Notes/Stats/StatisticsView+Data.swift` | Stats Aggregationen + Datenaufbereitung | Aggregation über gesamte Library; Perf-/Cache-Invalidation kritisch |
| 6 | 456 | `Shelf Notes/Stats/StatisticsView+Sections.swift` | Stats UI Sections | viele Derived Values → invalidations/Complexity |
| 7 | 454 | `Shelf Notes/LibraryView/LibraryRowAppearanceSettingsSection.swift` | Library Row Appearance Settings (UI + Persist) | viele @AppStorage Bindings/Optionen → Wartbarkeit/State-Explosion |
| 8 | 428 | `Shelf Notes/Book.swift` | Zentrales Domain-Model `Book` + Migrator/Helpers | Model wächst (viele Felder + Helpers) → Migrations-/Refactor-Risiko |
| 9 | 418 | `Shelf Notes/LibraryView/LibraryView+Header.swift` | Library Header (Search/Filter/Counts UI) | Header animiert/invalidiert viel → Render-Perf, viele Bindings |
| 10 | 406 | `Shelf Notes/BookImport/BookImportView/BookImportViewModel+Tasks.swift` | Import Concurrency: Debounce/Pagination/Cancellation | Task-Lifetimes & cancellation → Race Conditions wenn falsch |
| 11 | 402 | `Shelf Notes/ReadingTimerManager.swift` | Globaler Timer-Session Manager | MainActor State + Persist-Trigger → UI/Correctness |
| 12 | 396 | `Shelf Notes/BookDetail/BookDetailView+Bindings.swift` | BookDetail derived state + bindings | viel Glue-Code → fragile Interaktionen, schwer zu refactoren |
| 13 | 373 | `Shelf Notes/Stats/StatisticsView+Heatmap.swift` | Heatmap Aggregation + Rendering helpers | potenziell große Datenmengen (365/366 Tage × Jahre) → Perf/Memory |
| 14 | 364 | `Shelf Notes/CSVImportExportView.swift` | CSV Import/Export UI + Workflow | I/O + Mapping + Thumbnail Backfill → lange Tasks/UX |
| 15 | 356 | `Shelf Notes/LibraryView/LibraryRowCoverView.swift` | Cover Rendering pro Row (async load/cache) | wird pro Zeile gerendert → Image decoding/caching kritisch |

## Sync / Storage / Model

### SwiftData Container Bootstrap + CloudKit
- Entry: `Shelf Notes/Shelf_NotesApp.swift` → `AppContainerHostView()`.
- Bootstrapping + Fallbacks: `AppBootstrapper` verwaltet Phasen (`loading`/`ready`/`failed`) und Modi (`cloudKit`, `localOnly`, `inMemory`). (`Shelf Notes/AppContainerHostView.swift`)
- CloudKit ist über SwiftData-Konfiguration aktiviert: `ModelConfiguration(... cloudKitDatabase: .automatic)`. (`Shelf Notes/AppContainerHostView.swift`)
- Local-only ist explizit ein eigener Store (`cloudKitDatabase: .none`) mit separatem Store-Namen/URL → verhindert unbewusste Vermischung. (`Shelf Notes/AppContainerHostView.swift` `StoreName.cloud/local`, `storeURL(...)`)
- Store-Pfade: `Application Support/ShelfNotes/SwiftData/<StoreName>.store`. (`Shelf Notes/AppContainerHostView.swift` `storeURL(for:)`)
- Background sync trigger: `UIBackgroundModes = remote-notification` (`Shelf Notes/Info.plist`) + `aps-environment` entitlement (`Shelf Notes/Shelf_Notes.entitlements`).

### Schema + CloudKit/SwiftData Constraints
- Schema ist zentral definiert: `ModelContainerFactory.schema`. (`Shelf Notes/AppContainerHostView.swift`)
- Entities: `Book`, `ReadingSession`, `ReadingGoal`, `BookCollection`, `ChallengeRecord`.
- Observed constraints/patterns:
  - Keine `@Attribute(.unique)` (kommentiert in mehreren Model-Files).
  - Relationships optional halten + inverses definieren (z.B. `ReadingSession.book` ↔ `Book.readingSessions`). (`Shelf Notes/ReadingSession.swift`, `Shelf Notes/Book.swift`)
  - `#Predicate` kann Enum-Cases nicht sauber referenzieren → Raw Strings nutzen (Beispiel: finished). (`Shelf Notes/ReadingTimelineView.swift`)

### Data Hygiene: Repairs/Migrations/Backfills
- `ReadingStatusMigrator.migrateIfNeeded(...)`: Legacy Strings → stabile Codes (`toRead`/`reading`/`finished`). (`Shelf Notes/Book.swift`, Trigger: `Shelf Notes/RootView.swift`)
- `CollectionMembershipRepair.repairIfNeeded(...)`: one-time repair für many-to-many Membership (scoped per store). (`Shelf Notes/CollectionMembershipRepair.swift`, Trigger: `Shelf Notes/AppContainerHostView.swift`)
- Cover thumbnail backfill (deferred + chunked): `CoverThumbnailer.backfillAllBooksIfNeeded(...)`. (`Shelf Notes/RootView.swift`, `Shelf Notes/CoverThumbnailer.swift`)

### Cover Storage Strategy (Cloud-friendly)
- Synced Thumbnail: `Book.userCoverData` (`@Attribute(.externalStorage)`), single source of truth fürs UI. (`Shelf Notes/Book.swift`)
- Full-res User Cover: lokal in `Application Support/user-covers/…` via `UserCoverStore`; Referenz nur als Filename. (`Shelf Notes/CachedAsyncImage.swift`, `Shelf Notes/CoverThumbnailer.swift`)
- Remote cover caching: Disk cache `Caches/cover-cache`. (`Shelf Notes/CachedAsyncImage.swift` `ImageDiskCache`, `Shelf Notes/CoverImageLoader.swift`)
- CPU-heavy image work wird in `Task.detached` ausgelagert; Persistenz bleibt MainActor-bound. (`Shelf Notes/CoverThumbnailer.swift`)

### Diagnostics / Observability
- `SyncDiagnostics` (iCloud AccountStatus, userRecord short, network status, local save breadcrumbs). (`Shelf Notes/SyncDiagnostics.swift`)
- `ModelContext.saveWithDiagnostics()` schreibt Breadcrumbs in `SyncDiagnostics`. (`Shelf Notes/ModelContext+Diagnostics.swift`)
- UI: `SyncDiagnosticsView`. (`Shelf Notes/SyncDiagnosticsView.swift`)
- Limitation: Kein detailliertes SwiftData CloudKit Sync Progress API verfügbar → Diagnostics sind bewusst minimal. (`Shelf Notes/SyncDiagnostics.swift` Kommentar)

## Entry Points + Navigation

### Startpfad
- `Shelf Notes/Shelf_NotesApp.swift` → `AppContainerHostView` → bei Erfolg `RootView().modelContainer(container)`.
- Startup tasks (bei `.ready`): Collection repair + Challenge refresh. (`Shelf Notes/AppContainerHostView.swift` `.task(id: mode)`)

### Root Tabs (`RootView`)
- TabView mit stabiler selection (`@SceneStorage`) und stabiler `.tint(...)` Anwendung, um Tab/Navigation Resets bei Appearance-Updates zu verhindern. (`Shelf Notes/RootView.swift`)
- Tabs:
  - Bibliothek: `Shelf Notes/LibraryView/LibraryView.swift`
  - Fortschritt: `Shelf Notes/ProgressHub/ProgressHubView.swift`
  - Listen: `Shelf Notes/CollectionsView.swift`
  - Tags: `Shelf Notes/TagsView.swift`
  - Einstellungen: `Shelf Notes/SettingsView.swift`

### Navigation / Routing Patterns
- Pro Tab meist eigener `NavigationStack` (z.B. `LibraryView`, `TagsView`, `CollectionsView`, `ProgressHubView`, `SettingsView`).
- Sheets: bevorzugt `sheet(item:)` + enum routing (z.B. `AddBookSheet`). (`Shelf Notes/AddBook/AddBookSheet.swift`)

## Hot Path Analyse

### Rendering / Scrolling (SwiftUI invalidations)
- `Shelf Notes/LibraryView/LibraryView.swift`: Header expand/collapse invalidiert häufig → deshalb Cache für displayedBooks/alpha sections + deferred recompute via `pendingRecomputeTask`.
  - Hotspot-Grund: ohne Cache wären Filter+Sort (+ Alpha bucketing) pro Frame/Interaction.
- `Shelf Notes/LibraryView/LibraryRowCoverView.swift` + `Shelf Notes/CoverImageLoader.swift`: Image load/decode wird off-main gemacht + Memory/Disk Cache.
  - Hotspot-Grund: Image decoding/I/O pro List Row.
- `Shelf Notes/TagsView.swift`: `snapshot = books.map { ... }` im `body` + `.task(id: snapshot)`.
  - Hotspot-Grund: O(n) allocation + großer Task-ID Diff/Hash overhead.
- `Shelf Notes/ReadingTimelineView.swift`: `.task(id: finishedBooks.map { $0.id })`.
  - Hotspot-Grund: großer Task-ID array + potenziell teure Derived-Data Updates im Timeline-VM.
- `Shelf Notes/StatisticsView.swift` + `Shelf Notes/Stats/StatisticsView+Caching.swift`: `booksSignature(books)` läuft pro render (O(n)), ist aber optimiert (kein sort, order-independent hash).
  - Hotspot-Grund: Stats screen aggregiert über ganze Library; CacheKey hängt an Signature.
- `Shelf Notes/BookDetailView.swift`: `@Query var allBooks: [Book]` für Top-Tags im Detail-Screen.
  - Hotspot-Grund: O(n) Kontext im Detail; kann bei großen Libraries spürbar sein.

### Sync/Storage (CloudKit/SwiftData)
- `Shelf Notes/CoverThumbnailer.swift` backfill: `ModelContext.fetch` aller Books + filter + per-book loop (MainActor) mit yields.
  - Hotspot-Grund: großer fetch + per-book persist kann MainActor beanspruchen.
- `Shelf Notes/CSVImportExportView.swift`: viele Writes + Thumbnail backfill calls.
  - Hotspot-Grund: Bulk import ist I/O + persist heavy.
- `Shelf Notes/CollectionMembershipRepair.swift`: one-time repair kann viele Relationship-Edits machen.

### Concurrency (Task lifetimes + cancellation)
- Import: cancellation + generation gating (stale results werden verworfen). (`Shelf Notes/BookImport/BookImportView/BookImportViewModel+Tasks.swift`)
- Pro: Transaction listener Task startet in `init`, cancelt in `deinit`. (`Shelf Notes/ProManager.swift`)
- Timer: `ReadingTimerManager` nutzt explizites `objectWillChange` → mutating APIs müssen send() nicht vergessen. (`Shelf Notes/ReadingTimerManager.swift`)

## Refactor Map

### Mechanische Splits (Compile-Time + Orientierung)
- `Shelf Notes/CoverThumbnailer.swift` → Split in 3–4 Dateien (Backfill/UserCovers/ImageIO).
- `Shelf Notes/BookImport/BookImportView/BookImportViewModel.swift` → Split nach Responsibilities (State/Search/Import). `+Tasks` existiert bereits.
- `Shelf Notes/LibraryView/LibraryRowAppearanceSettingsSection.swift` → Split in kleinere Sections (Covers/Text/Tags/Badges/Spacing).
- `Shelf Notes/Book.swift` → Migrator + computed helpers in Extensions auslagern (Model bleibt unverändert).

### Cache-/Index-Ideen
- Vereinheitliche „Signature“-Pattern (order-independent) und nutze **kleine** IDs in `.task(id:)`.
  - Tags: Signature statt `snapshot` array als Task-ID. (`Shelf Notes/TagsView.swift`, `Shelf Notes/TagsIndexModel.swift`)
  - Timeline: Signature statt `finishedBooks.map { $0.id }`. (`Shelf Notes/ReadingTimelineView.swift`, `Shelf Notes/Timeline/ReadingTimelineViewModel.swift`)
- Optional: zentraler `BookDerivedIndex` (Tags, Status-Counts, Year buckets), um redundante O(n) loops zu vermeiden (Stats/Timeline/Tags/Detail).

### Vereinheitlichungen (Patterns/DI)
- Heute: Views mutieren Models direkt via `modelContext` und Helpers; `saveWithDiagnostics` ist vorhanden, aber Konsistenz über alle Save-Sites ist **UNKNOWN**.
- Option: kleine Stores für Mutations (BookMutationsStore, SessionStore, CollectionStore) → testbarer + weniger duplicate glue code.

## Risks & Edge Cases
- Local-only divergence ist by design; Banner existiert. (`Shelf Notes/AppContainerHostView.swift` `LocalOnlyBanner`)
- SwiftData+CloudKit schema evolution: Model-Änderungen können Cloud schema updates/migrations erfordern; außerhalb der vorhandenen one-time repairs gibt es kein sichtbares Framework. **UNKNOWN** wie Prod-Migration geplant ist.
- Secrets: `Shelf Notes/config/secrets.xcconfig` enthält echten Key → Leakage Risiko.
- Large libraries: mehrere Screens machen O(n) snapshots/signatures im `body` (Tags/Timeline/Stats/Detail).

## Appearance System
- Keys + Option-Enums: `Shelf Notes/AppearanceSettings/AppearancePreferences.swift` (viele `appearance_*_v1` Keys).
- Global applied in `RootView` (ColorScheme, foregroundStyle, fontDesign, dynamicTypeSize, controlSize, tint). (`Shelf Notes/RootView.swift`)
- Library-specific UI: `Shelf Notes/LibraryView/LibraryAppearanceSettingsView.swift`, `Shelf Notes/LibraryView/LibraryRowAppearanceSettingsSection.swift`.
- Wartbarkeitsrisiko: viele einzelne `@AppStorage` Bindings → Refactor-Idee: Settings structs + mapping layer (keine bestehende Implementierung).

## Build/Config Hotspots
- Deployment target ist iOS 26.0 (`Shelf Notes.xcodeproj/project.pbxproj`). Wenn das nicht Absicht ist, blockiert es reale Releases.
- `GOOGLE_BOOKS_API_KEY` wird per xcconfig injected: `Info.plist` erwartet `$(GOOGLE_BOOKS_API_KEY)`. (`Shelf Notes/Info.plist`, `Shelf Notes/config/base.xcconfig`)
- StoreKit local config: `Shelf Notes/unlimited_collections.storekit` (Product ID in Code ist Platzhalter). (`Shelf Notes/ProManager.swift`)

## Observability / Debuggability
- In-App: `SyncDiagnosticsView` + Save breadcrumbs (`saveWithDiagnostics`).
- Repro-Checkliste (Sync): iCloud status, network constrained/expensive, last local save timestamp, 2 devices gleiche Apple ID.

## Notable Design Decisions (observed)
- Resilient startup statt Crash (Error screen + retry + local-only/in-memory). (`Shelf Notes/AppContainerHostView.swift`)
- Derived-data caching ist explizit (Library/Stats/Tags/ProgressHub). (`Shelf Notes/LibraryView/LibraryView.swift`, `Shelf Notes/Stats/StatisticsView+Caching.swift`, `Shelf Notes/TagsIndexModel.swift`, `Shelf Notes/ProgressHub/ProgressHubView.swift`)
- MainActor ModelContext + CPU-heavy work offloaded (`Task.detached`) (Cover pipeline). (`Shelf Notes/CoverThumbnailer.swift`)

## Tests / Verifikation (minimal sinnvoll)
- Unit-Test Kandidaten (pure-ish code):
  - Tag normalization + signature: `Shelf Notes/TagsIndexModel.swift`
  - CSV Roundtrip: `Shelf Notes/CSVCodec.swift`
  - Google Books query building: `Shelf Notes/BookImport/BookImportQueryBuilder.swift`
- Manual smoke checklist:
  - Import: search, cancel typing, pagination, duplicate detection
  - Library: scroll, filter chips, selection mode, delete
  - Covers: remote + user photo cover; disk cache clear in Settings
  - Sync: 2 devices, cover thumbnails + collections membership

## Additional Refactor Candidates (P1+)
- `Shelf Notes/Stats/StatisticsView+Data.swift`/`+Heatmap.swift`: extract pure aggregation „StatsEngine“ (testbar) und UI/Formatting getrennt.
- `Shelf Notes/Challenges/ChallengeEngine.swift`: split „calculation“ (pure) vs „persistence“ (ensureCurrentChallenges/markCompleted).
- `Shelf Notes/ReadingTimerManager.swift`: separate persistence/serialization (ActiveState) von UI trigger logic (pendingCompletion).

## Concrete Performance Measurement Ideas
- Time Profiler: Library scroll (200+ books) → schauen auf `UIImage(data:)`, `Data(contentsOf:)`, Hashing/Sorting.
- Main thread: während Cover backfill läuft → prüfen ob jank (RootView schedules backfill). (`Shelf Notes/RootView.swift`, `Shelf Notes/CoverThumbnailer.swift`)
- Memory: sehr viele remote covers → Disk/memory cache pressure; Settings bietet Clear cache UI. (`Shelf Notes/SettingsView.swift`, `Shelf Notes/CachedAsyncImage.swift`)

## Open Questions (UNKNOWNs)
- CloudKit DB Mode unter `.automatic` (private/shared/public)? (`Shelf Notes/AppContainerHostView.swift`) **UNKNOWN**
- Conflict resolution Policy bei gleichzeitigen Edits? **UNKNOWN**
- Soll `config/secrets.xcconfig` im VCS sein oder lokal? **UNKNOWN**
- Pro Monetization final: Product ID/Preis/App Store Connect? (`Shelf Notes/ProManager.swift`) **UNKNOWN**
- Performance targets (max books/sessions) + beobachtete Hotspots aus realen Geräten? **UNKNOWN**

## First 3 Refactors I would do (P0)

### P0.1 — Stabilize derived-index updates (Tags + Timeline)
- **Ziel**: O(n) Snapshot-Allokationen im `body` reduzieren und `.task(id:)` IDs klein/stabil machen.
- **Betroffene Dateien**:
  - `Shelf Notes/TagsView.swift`, `Shelf Notes/TagsIndexModel.swift`
  - `Shelf Notes/ReadingTimelineView.swift`, `Shelf Notes/Timeline/ReadingTimelineViewModel.swift`
- **Risiko**: niedrig (rein derived state; keine Persistenzänderung).
- **Erwarteter Nutzen**: weniger View invalidation overhead + stabileres Scrolling bei großen Libraries.

### P0.2 — Secrets hygiene + onboarding-safe config
- **Ziel**: Keine echten API Keys im Repo; Build bleibt reproduzierbar.
- **Betroffene Dateien**:
  - `Shelf Notes/config/secrets.xcconfig` (raus aus VCS / gitignore)
  - neu: `Shelf Notes/config/secrets.template.xcconfig` (Platzhalter)
  - `Shelf Notes/config/base.xcconfig`, `Shelf Notes/Info.plist` (weiterhin `$(GOOGLE_BOOKS_API_KEY)` nutzen)
- **Risiko**: mittel (Build bricht, wenn Key nicht gesetzt).
- **Erwarteter Nutzen**: Security + schneller Contributor-Setup (kein Key-Leak).

### P0.3 — Cover backfill performance guardrails
- **Ziel**: Backfill soll bei großen Libraries garantiert nicht stottern/batteriesaugen.
- **Betroffene Dateien**:
  - `Shelf Notes/RootView.swift` (Scheduling/Heuristik, Cancellation Guardrails)
  - `Shelf Notes/CoverThumbnailer.swift` (Backfill fetch/loop strategy, yielding)
- **Risiko**: mittel (Cover-Flow ist user-visible; falsche Heuristik → fehlende Thumbnails).
- **Erwarteter Nutzen**: bessere First-Run UX + weniger MainActor contention + bessere Battery.