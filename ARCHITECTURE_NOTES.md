# Shelf Notes — ARCHITECTURE_NOTES

_Last updated: 2026-02-24_

> Scope: Diese Notizen sind bewusst technisch. Alles, was ich nicht aus dem Code/Projekt ableiten konnte, ist als **UNKNOWN** markiert und unten in **Open Questions** gesammelt.

---

## Big Files List (Top 15 nach Zeilen)

Quelle: Zählung aller `.swift` Dateien im App-Target `Shelf Notes/` (Stand: 2026-02-24).

| # | Datei | ~Zeilen | Grober Zweck | Warum riskant (Wartbarkeit/Perf) |
|---:|---|---:|---|---|
| 1 | `Shelf Notes/BookDetail/BookDetailView+Logic.swift` | 613 | Bindings, computed props, Mutations/Actions für BookDetailView | Viele Side-Effects + Saves; Änderungen hier können UI/Sync-Verhalten leicht beeinflussen ("save storms", state coupling). |
| 2 | `Shelf Notes/BookImport/BookImportView/BookImportViewModel.swift` | 562 | State + Orchestrierung der Google-Books-Suche (Query/Filter/Pagination/Undo/History) | Komplexer asynchroner Zustand → Risiko für Race Conditions, Stale Results, Cancellation-Bugs. |
| 3 | `Shelf Notes/CoverThumbnailer.swift` | 558 | Thumbnail-Pipeline (ImageIO), Remote-Fallbacks, Backfill/Refresh für synced Thumbnails | I/O + Memory + MainActor-Saves; Fehler wirken sofort auf UI (Covers) und CloudKit-Payload. |
| 4 | `Shelf Notes/BookDetail/BookDetailComponents.swift` | 551 | Große SwiftUI-Subview-Sammlung (Parallax Header, Cards, Sections) | Compile-Time Hotspot + hoher Re-render Druck; kleine Änderungen können viel invalidieren. |
| 5 | `Shelf Notes/AppearanceSettingsView.swift` | 537 | Settings UI für Appearance (AppStorage, Presets, Farben, Dichte, Fonts) | Sehr viele Bindings/AppStorage → hier passieren schnell Navigation-Resets oder ungewollte Rebuilds. |
| 6 | `Shelf Notes/Challenges/ChallengeEngine.swift` | 525 | Generieren + Fortschritt berechnen (Fetches über Sessions/Books) + Reroll/Claim | MainActor-Fetches; kann in UI/Startpfad spürbar werden, wenn häufig/unkontrolliert aufgerufen. |
| 7 | `Shelf Notes/Stats/StatisticsView+Data.swift` | 459 | Aggregationen/Parsing (Genres, Top-Listen, Year slices) | O(n) über Bücher; wenn direkt im Renderpfad genutzt, kann das Scroll/Interaktion beeinflussen. |
| 8 | `Shelf Notes/Stats/StatisticsView+Sections.swift` | 456 | SwiftUI Section Builder für StatisticsView | Viele Views + generics → Compile-Time; bei Rebuilds können große Teile invalidieren. |
| 9 | `Shelf Notes/LibraryView/LibraryRowAppearanceSettingsSection.swift` | 454 | UI für Library-spezifische Appearance-Optionen | Viele `@AppStorage` + UI; Risiko für inkonsistente Defaults/Abhängigkeiten. |
| 10 | `Shelf Notes/Book.swift` | 428 | Zentrales Model + Cover/Ratings Helpers + Migrator | Große, zentrale Datei: Änderungen haben sehr breite Auswirkungen (Persistenz, UI, Sync). |
| 11 | `Shelf Notes/LibraryView/LibraryView+Header.swift` | 418 | Header/Filterbar/Sort UI für LibraryView | Teil des Hot-UI-Pfads (Header expand/collapse); kann viele Recomputes triggern. |
| 12 | `Shelf Notes/BookImport/BookImportView/BookImportViewModel+Tasks.swift` | 406 | Task/Cancellation/Debounce/Load-more Implementierung | Concurrency-Hotspot: Fehler → doppelte Requests, stale UI, Memory leaks. |
| 13 | `Shelf Notes/ReadingTimerManager.swift` | 402 | Timer State Machine + Persistenz (UserDefaults) + Auto-Stop | Edge-Case-lastig (Background, Pause/Resume, Persistenz). Bugs wirken direkt auf Nutzerdaten. |
| 14 | `Shelf Notes/Stats/StatisticsView+Heatmap.swift` | 373 | Heatmap Range + Daily count computation | Kann große Datenmengen (Sessions/Books) aggregieren; bei MainActor-Ausführung potentiell Hitching. |
| 15 | `Shelf Notes/CSVImportExportView.swift` | 364 | CSV Import/Export UI + Parsing/Export | File I/O + Parsing; wenn nicht gut isoliert, kann UI blockieren. |

---

## Hot Path Analyse

### Rendering / Scrolling

#### 1) Stats: teure Aggregationen laufen aktuell auf dem MainActor
- Pfade:
  - `Shelf Notes/Stats/StatisticsView.swift` (Tasks starten Cache-Recompute)
  - `Shelf Notes/Stats/StatisticsView+Caching.swift` (`computeStatsCache`, `computeHeatmapCache`, `booksSignature`)
  - `Shelf Notes/Stats/StatisticsView+Data.swift` (Genre/Tag Parsing, Top-Listen)
  - `Shelf Notes/Stats/StatisticsView+Heatmap.swift` (Daily counts / Heatmap weeks)
- Konkreter Grund (Hotspot):
  - `.task(id: statsKey)` und `.task(id: heatmapKey)` laufen im View-Kontext → effektiv auf MainActor.
  - `computeStatsCache`/`computeHeatmapCache` iterieren über `books` (O(n)) und bauen mehrere Aggregationen.
  - `booksSignature` macht pro Book u.a. `.sorted()` auf `tags`/`categories` (O(k log k)) — zwar klein, aber häufig.
- Symptome (typisch):
  - UI-Hitching beim Öffnen/Wechseln von "Statistiken", Scope/Year wechseln, oder wenn SwiftData `books` häufig invalidiert.

#### 2) Challenges: Fetch/Compute im View-Body
- Pfade:
  - `Shelf Notes/Challenges/ChallengesView.swift`
  - `Shelf Notes/Challenges/ChallengeEngine.swift`
- Konkreter Grund (Hotspot):
  - In `ChallengeCard.body` wird Progress fallback-mäßig so berechnet:
    - `let p = progress ?? ChallengeEngine.computeProgress(...)`
  - `computeProgress(...)` ist `@MainActor` und nutzt `ModelContext`-Fetches → das ist **Fetch im body**.
- Risiko:
  - Bei vielen ChallengeRecords (History) oder langsamen Geräten kann eine List-Scroll/Render den MainActor blockieren.

#### 3) ProgressHub hero metrics: O(n) über Sessions/Books im Renderpfad
- Pfad: `Shelf Notes/ProgressHubView.swift`
- Konkreter Grund (Hotspot):
  - `heroCard` berechnet `finishedBooks(in:)` per `books.filter` und `last7DaysSessionStats()` per Iteration über `sessions`.
  - Diese Funktionen werden im View-Body kontextuell genutzt (kein Cache/Signature) → bei jedem Re-render wieder O(n).
- Hinweis:
  - Bei kleinen Libraries ok; bei großen Session-Historien kann das spürbar werden.

#### 4) BookDetail Header: per-book `.task` kann Netzwerk + Save triggern
- Pfade:
  - `Shelf Notes/BookDetail/BookDetailComponents.swift` (`.task(id: book.id)` im Header)
  - `Shelf Notes/CoverThumbnailer.swift` (Refresh/Backfill + Thumbnail IO)
- Konkreter Grund (Hotspot):
  - Beim Öffnen eines Details kann `refreshSyncedThumbnailIfNeeded`/`backfillThumbnailIfNeeded` remote cover laden, Thumbnail generieren, und `modelContext.saveWithDiagnostics()` auslösen.
- Risiko:
  - "Save storms" wenn mehrere Details schnell geöffnet werden oder wenn Cover-Kandidaten häufig wechseln.

#### 5) LibraryView: Hot path ist bereits aktiv entschärft (positiv)
- Pfade:
  - `Shelf Notes/LibraryView/LibraryView.swift` (derived cache + debounce)
  - `Shelf Notes/LibraryView/LibraryView+Header.swift` (Header expand/collapse)
- Beobachtung:
  - Der Code dokumentiert explizit, dass Header-Animation viele `body`-Recomputes triggert und cached deshalb Filter/Sort/Alpha Sections.
- Risiko (Rest):
  - Änderungen am Header können trotzdem leicht "View invalidation storms" auslösen → hier sehr vorsichtig bleiben.

---

### Sync / Storage (SwiftData + CloudKit)

#### Container Bootstrap + Fallback (sehr gut gelöst)
- Pfad: `Shelf Notes/AppContainerHostView.swift`
- Beobachtungen:
  - Kein `fatalError` beim Container-Fail; stattdessen Failure UI mit Retry/Local-only/In-memory.
  - **Store separation**: CloudKit vs Local-only haben getrennte Store-Namen und URLs (verhindert "store mixing").
- Tradeoff:
  - Local-only ist bewusst ein separater Datenstand. UI zeigt Banner + Alert, aber UX-Risiko bleibt: Nutzer könnte denken, es sei "derselbe" Datenbestand.

#### SwiftData + CloudKit Constraints sind bewusst im Code verankert
- Pfade:
  - `Shelf Notes/Book.swift`, `Shelf Notes/ReadingSession.swift`, `Shelf Notes/BookCollection.swift`, `Shelf Notes/Challenges/ChallengeModels.swift`
- Beobachtungen:
  - wiederholt kommentiert: keine `@Attribute(.unique)`, Relationships optional, inverse bei 1:n.
- Risiko:
  - Schema-Änderungen sind bei SwiftData/CloudKit grundsätzlich heikel. Im Repo sehe ich keine explizite "Schema version/migration strategy" jenseits von One-time Repairs (**UNKNOWN**).

#### One-time Repairs / Backfills im Startpfad
- Pfade:
  - `Shelf Notes/RootView.swift` (ReadingStatusMigrator + deferred cover backfill)
  - `Shelf Notes/CollectionMembershipRepair.swift` (läuft einmal pro Store-Scope)
  - `Shelf Notes/Challenges/ChallengeEngine.swift` (`ensureCurrentChallenges` + `refreshCompletionForActiveChallenges` wird beim Container-ready direkt getriggert)
- Konkreter Grund (Hotspot):
  - Diese Aufgaben laufen beim Appstart / beim Aktivwerden und führen Fetches + Saves aus.
- Mitigation vorhanden:
  - Cover backfill ist chunked + delayed + cancellable (gut).
  - Repairs sind "once per scope" (UserDefaults) (gut).

#### Sync-Diagnostik als eigenes, kleines System (positiv)
- Pfade:
  - `Shelf Notes/SyncDiagnostics.swift`
  - `Shelf Notes/SyncDiagnosticsView.swift`
  - `Shelf Notes/ModelContext+Diagnostics.swift`
- Beobachtung:
  - SwiftData bietet keine echte Sync-Progress API; das Projekt surfacet dafür die wichtigsten Signale (AccountStatus, Network, letzte Saves).

---

### Concurrency / Task-Lifetimes

#### BookImport: robustes Cancellation + Debounce Pattern
- Pfade:
  - `Shelf Notes/BookImport/BookImportView/BookImportViewModel.swift`
  - `Shelf Notes/BookImport/BookImportView/BookImportViewModel+Tasks.swift`
- Beobachtung:
  - `searchTask`/`loadMoreTask` + `searchGeneration` zur Stale-Response-Absicherung
  - Debounced refresh bei Filteränderung (`filterRefreshDebounceNanos`)
- Risiko:
  - Viele moving parts → Tests/Telemetry lohnen sich, aber Pattern ist grundsätzlich solide.

#### CoverThumbnailer: Off-main ImageIO, aber MainActor Saves
- Pfad: `Shelf Notes/CoverThumbnailer.swift`
- Beobachtung:
  - Thumbnail-Erzeugung via `Task.detached` mit `autoreleasepool` (gut)
  - Persistenz/Saves passieren über `modelContext.saveWithDiagnostics()` (MainActor)
- Risiko:
  - Bei großen Backfills kann es trotzdem MainActor contention geben (trotz batching).

#### ReadingTimerManager: explizites `objectWillChange` (Swift 6 Workaround)
- Pfad: `Shelf Notes/ReadingTimerManager.swift`
- Beobachtung:
  - Manager setzt eigenes `objectWillChange` und sendet es in mutierenden Calls.
- Risiko:
  - UI-Updates hängen stark an korrekter "manual send" Disziplin; Regressionen sind möglich, wenn neue Mutationspfade hinzugefügt werden.

---

## Refactor Map (konkret)

### A) Fetches aus SwiftUI `body` entfernen (Challenges)
**Ziel:** Keine `ModelContext`-Fetches in `View.body` → smoother List/Scroll.

- Betroffene Dateien:
  - `Shelf Notes/Challenges/ChallengesView.swift`
  - `Shelf Notes/Challenges/ChallengeEngine.swift`
- Konkreter Schnitt:
  - `ChallengeCard` darf **nie** `ChallengeEngine.computeProgress(...)` im `body` aufrufen.
  - Stattdessen:
    - `ChallengesView.refresh()` berechnet Progress für *alle sichtbaren* Einträge (active + past) und schreibt in `progressByID`.
    - `ChallengeCard` rendert ausschließlich `progress` (und zeigt "…" wenn nil).
- Risiko: niedrig
- Nutzen:
  - Entfernt "Fetch im body" Hotspot, reduziert MainActor contention beim Scrollen.

### B) Stats Compute off-main (Snapshot + detached crunch)
**Ziel:** Statistiken (StatsCache/HeatmapCache) **nicht** auf MainActor berechnen.

- Betroffene Dateien:
  - `Shelf Notes/Stats/StatisticsView.swift`
  - `Shelf Notes/Stats/StatisticsView+Caching.swift`
  - (optional) neue Datei `Shelf Notes/Stats/StatisticsSnapshots.swift`
- Konkreter Ansatz:
  1. Erzeuge einen value-only Snapshot aus `books` (und optional Session-Daten) auf MainActor, z.B.:  
     `struct BookStatsSnapshot { ... }` (ohne SwiftData-Objekte in Background-Threads).
  2. Rechne die Caches in `Task.detached` aus diesem Snapshot (kein SwiftData/ModelContext Zugriff).
  3. Setze `statsCache`/`heatmapCache` zurück auf MainActor.
- Risiko: mittel (mehr Code, Snapshot muss vollständig genug sein)
- Nutzen:
  - Spürbar weniger UI hitching bei großen Libraries, saubere Trennung von UI vs Compute.

### C) Cover-Pipeline modularisieren (Wartbarkeit + klare Verantwortlichkeiten)
**Ziel:** `CoverThumbnailer.swift` (558 Zeilen) in klare Teilbereiche splitten.

- Betroffene Dateien:
  - `Shelf Notes/CoverThumbnailer.swift`
- Konkreter Schnitt (Beispiel):
  - `CoverThumbnailer+ImageIO.swift` (pixelSize, thumbnailJPEGData, makeThumbnailData)
  - `CoverThumbnailer+RemoteFetch.swift` (thumbnailData(forRemoteURLString:), URL upgrades)
  - `CoverThumbnailer+Backfill.swift` (backfillAllBooksIfNeeded, per-book refresh/backfill)
  - `CoverThumbnailer+UserCover.swift` (apply user cover, file store interactions)
- Risiko: niedrig (mechanischer Split)
- Nutzen:
  - Weniger Merge-Konflikte, bessere Orientierung, leichter isoliert testbar.

### D) Book.swift entkoppeln (Migration/Ratings/Cover separieren)
**Ziel:** Zentral-Model-Datei entschlacken; Regeln klarer lokalisieren.

- Betroffene Dateien:
  - `Shelf Notes/Book.swift`
- Konkreter Schnitt:
  - `Book+Status.swift` (ReadingStatus + Migrator + status property)
  - `Book+Ratings.swift` (user ratings helpers)
  - `Book+Cover.swift` (cover candidates helpers, URL normalization)
- Risiko: niedrig (mechanisch, aber viele Call-sites)
- Nutzen:
  - Reduziert "God file" Risiko; bessere Testbarkeit.

### E) ProgressHub metrics cachen (wie TagsIndexModel)
**Ziel:** O(n) Iterationen über `books`/`sessions` nicht im Renderpfad.

- Betroffene Dateien:
  - `Shelf Notes/ProgressHubView.swift`
  - (neu) `Shelf Notes/ProgressHubMetricsModel.swift`
- Ansatz:
  - `ProgressHubMetricsModel.update(snapshot:)` analog zu `TagsIndexModel`
  - Signature über `books`/`sessions` (coarse) → Recompute nur bei echten Änderungen.
- Risiko: niedrig–mittel
- Nutzen:
  - "Fortschritt" bleibt auch bei großen Histories flüssig.

---

## Cache- / Index-Ideen

1. **Disk cache eviction**: `ImageDiskCache` (`Shelf Notes/CachedAsyncImage.swift`) ist unbounded.  
   - Idee: max size (z.B. 150–300 MB) + LRU (file access date) + periodic prune in Settings/Background.
2. **Stats snapshots**: Siehe Refactor B — Snapshot erlaubt off-main crunching und kann wiederverwendet werden (Stats + ProgressHub + Challenges).
3. **Challenge progress pre-aggregation**:
   - Idee: Tagesbasierter Session-Summary Cache (z.B. Dictionary day → seconds/pages/sessions) für die aktuelle Woche/Monat.
   - Invalidations: wenn `ReadingSession` gespeichert wird.
4. **Collection membership as single source of truth**:
   - Aktuell existiert Repair, weil beide Seiten manuell mutiert wurden.  
   - Langfristig: nur eine Seite mutieren (z.B. immer `Book.collectionsSafe`), die andere Seite als derived (oder nur per SwiftData inverse) behandeln.

---

## Vereinheitlichungen (Patterns, DI, Konsistenz)

- **UserDefaults/AppStorage Keys bündeln**: viele Keys sind String-Literale in Views (`RootView.swift`, `SettingsView.swift`, `ReadingTimerManager.swift`).  
  → zentrale `enum AppStorageKeys` (Datei: `Shelf Notes/AppStorageKeys.swift`).
- **Save policy**: "wann speichern wir?" ist aktuell gemischt (z.B. `BookDetailView.onDisappear` vs explizite Saves in Bindings).  
  → einheitliche Policy definieren (z.B. save on explicit actions; throttled autosave; niemals in tight loops).
- **Snapshot-first compute**: wiederkehrendes Pattern (TagsIndexModel, StatsCache) kann vereinheitlicht werden.

---

## Risiken & Edge Cases

### Datenverlust / Divergenz
- Local-only Mode ist ein separater Store (`ShelfNotesLocal`). Nutzer könnte versehentlich im Offline-Modus "weiterarbeiten" und später erwarten, dass es synced.  
  Mitigation vorhanden (Banner + Alert), aber Risiko bleibt.

### SwiftData/CloudKit Schema Migration
- Es existieren One-time Repairs (UserDefaults gating), aber keine explizite, versionierte Migration-Strategie (**UNKNOWN**).  
  Bei Model-Änderungen kann CloudKit Schema drift / Sync-Fail auftreten.

### Many-to-many optional relationships
- Optionalität ist CloudKit-bedingt. Risiko: nil vs [] Semantik, dedupe, Drift.  
  `CollectionMembershipRepair` hilft, aber Änderungen an Membership müssen sehr sorgfältig bleiben.

### CSV Import/Export
- Pfad: `Shelf Notes/CSVImportExportView.swift`, Parser: `Shelf Notes/CSVCodec.swift`  
  Edge Cases: Duplicate detection, Encoding, Field escaping, sehr große CSVs → UI block.

---

## Observability / Debuggability

- **Sync breadcrumbs**: `ModelContext.saveWithDiagnostics()` + `SyncDiagnostics.shared`  
  - Settings → Sync-Diagnose (UI + "Report copy") hilft bei Nutzer-Bugs.
- **Google Books debug**: `GoogleBooksDebugInfo` (`Shelf Notes/GoogleBooksClient.swift`) → ideal um Filter/Key Probleme zu sehen.
- **Performance** (**UNKNOWN**, ob gewünscht):
  - Vorschlag: `os_signpost` / `Logger` um Stats compute, Challenge progress, cover backfill batches zu messen.

---

## Open Questions (UNKNOWN)

1. **Release Push / aps-environment**: `Shelf Notes/Shelf_Notes.entitlements` setzt `aps-environment=development`.  
   - Wird das für Release/Prod dynamisch angepasst? (**UNKNOWN**)
2. **Schema evolution strategy**: Gibt es eine geplante Versionierung/Strategie für SwiftData Model-Änderungen + CloudKit Schema? (**UNKNOWN**)
3. **Local-only UX**: Soll Local-only Mode ausschließlich ein "Failure fallback" bleiben oder auch ein expliziter User-Toggle? (**UNKNOWN**)
4. **Disk cache policy**: Soll `cover-cache` einen Size-Limit haben? Wie aggressiv darf evicted werden? (**UNKNOWN**)
5. **CSV duplicates**: Wie wird beim CSV-Import Dedupe entschieden (ISBN? title+author? googleVolumeID?) (**UNKNOWN**)
6. **Test scope**: Erwartest du Unit/UI Tests als Smoke (minimal) oder echte Logic-Coverage? (**UNKNOWN**)

---

## First 3 Refactors I would do (P0)

### P0.1 — Secrets/Config Hygiene (Sicherheits- und Release-Risiko raus)
- Ziel:
  - API-Key nicht im Repo; saubere lokale/CI Injektion.
- Betroffene Dateien:
  - `Shelf Notes/config/secrets.xcconfig`
  - `Shelf Notes/config/base.xcconfig`
  - `.gitignore` (**UNKNOWN**, ob vorhanden/gewünscht)
- Risiko: niedrig (Build-Setup Änderungen)
- Erwarteter Nutzen:
  - Kein Leak-Risiko; einfacher CI/Release Prozess; Key rotation möglich ohne Code-Änderung.

### P0.2 — Challenges: kein Fetch im body (Performance + deterministisches Rendering)
- Ziel:
  - `ChallengesView` rendert ohne `ModelContext` Fetches in Subviews.
- Betroffene Dateien:
  - `Shelf Notes/Challenges/ChallengesView.swift`
  - (optional) `Shelf Notes/Challenges/ChallengeEngine.swift` (falls API ergänzt wird)
- Risiko: niedrig
- Erwarteter Nutzen:
  - Smoother Scroll/Render; weniger MainActor contention; reproduzierbareres UI (kein "work during draw").

### P0.3 — StatisticsView: Cache-Compute off-main (UI Hitching eliminieren)
- Ziel:
  - Stats/Heatmap Caches in `Task.detached` aus Snapshots berechnen.
- Betroffene Dateien:
  - `Shelf Notes/Stats/StatisticsView.swift`
  - `Shelf Notes/Stats/StatisticsView+Caching.swift`
  - (neu) `Shelf Notes/Stats/StatisticsSnapshots.swift`
- Risiko: mittel (Snapshot completeness + threading discipline)
- Erwarteter Nutzen:
  - Große Libraries bleiben interaktiv; weniger Ruckler beim Wechseln von Year/Scope/Metric.

---
