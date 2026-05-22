# ARCHITECTURE_NOTES.md

## Scope
Diese Notizen basieren ausschließlich auf dem gelieferten Projektstand im ZIP. Wo Absicht oder Betriebsannahmen nicht aus Code/Projektdateien ableitbar sind, ist das als **UNKNOWN** markiert.

---

## Big Files List — Top 15 nach Zeilen

| Rang | Datei | Zeilen | Grober Zweck | Warum riskant |
|---|---|---:|---|---|
| 1 | `Shelf Notes/Stats/StatisticsSnapshotBuilder.swift` | 639 | baut Statistik-Snapshots und Aggregationen | sehr große fachliche Oberfläche; Änderungen gefährden mehrere Statistiksektionen gleichzeitig |
| 2 | `Shelf Notes/Challenges/ChallengeEngine+Compute.swift` | 435 | Challenge-Berechnung/Progress | hoher fachlicher Impact; Fehler wirken direkt auf Motivation/Statuslogik |
| 3 | `Shelf Notes/Settings/AppearanceSettings/AppearancePreferences.swift` | 407 | zentrale Appearance-Optionen und Keys | weniger Performance-Risiko, aber hoher Änderungsradius bei UI-Settings |
| 4 | `Shelf Notes/Stats/StatisticsHeatmapBuilder.swift` | 406 | Heatmap-Datenaufbereitung | zweite große Statistik-Engine; kompliziertes Datums-/Kalenderverhalten |
| 5 | `Shelf Notes/LibraryView/LibraryView+Header.swift` | 396 | Bibliotheks-Header/Filter-UI | UI- und State-Komplexität in Hot Screen |
| 6 | `Shelf Notes/LibraryView/LibraryView+Grid.swift` | 386 | Grid-Darstellung der Bibliothek | Renderpfad für zentrale Kernansicht |
| 7 | `Shelf Notes/BookDetail/BookDetailView+Bindings.swift` | 361 | Detailscreen-Mutationen/Bindings | „God file“-Risiko für Status, Tags, Notes, Collections, Ratings |
| 8 | `Shelf Notes/LibraryView/LibraryRowCoverView.swift` | 356 | Cover-Rendering in Listen/Grid | High-traffic Renderpfad; Caching/Decode/State ineinander |
| 9 | `Shelf Notes/ForYouSeedBuilder.swift` | 355 | Inspiration-Seeds auf Basis Bibliothek | viel Text-/Kategorienormalisierung in einer Datei |
| 10 | `Shelf Notes/BookDetail/BookDetailView+Cards.swift` | 351 | Detail-Cards | große SwiftUI-Oberfläche, schwierig gezielt zu ändern |
| 11 | `Shelf Notes/CachedAsyncImage.swift` | 342 | Memory Cache, Disk Cache, User Cover Store, View | zu viele Verantwortlichkeiten in einer Datei |
| 12 | `Shelf Notes/AddBook/AddBookView+Cards.swift` | 340 | UI-Karten für Add Book | breite UI-Verantwortung, hoher Änderungsradius |
| 13 | `Shelf Notes/ManualBookAddSheet.swift` | 337 | manueller Importfluss | formularlastig, potenziell viele direkte Save-/Mapping-Pfade |
| 14 | `Shelf Notes/AddBook/AddBookViewModel.swift` | 337 | Orchestrierung Add Book | mischt Import-Mapping, UI-Fluss und Speichern |
| 15 | `Shelf Notes/BookImport/BookImportView/BookImportViewModel+Tasks.swift` | 335 | Suche, Debounce, Paging, Cancellation | hoher kognitiver Load; Race-/Cancellation-Risiko |

### Einordnung
- Die größten Dateien liegen überwiegend in den Pfaden `Stats`, `LibraryView`, `BookDetail`, `BookImport`.
- Die größten Risiken sind nicht nur „viele Zeilen“, sondern vor allem gemischte Verantwortlichkeiten in Hot Screens und Compute-Pipelines.

---

## Hot Path Analyse

### 1) Rendering / Scrolling

#### A. Bibliothek (`Shelf Notes/LibraryView/*`)
**Warum Hot Path:** zentraler Haupttab, potenziell größte Datenmenge, List/Grid, Suche, Filter, Bulk Actions.

Konkrete Beobachtungen:
- `Shelf Notes/LibraryView/LibraryView.swift`
  - lädt alle Bücher via `@Query(sort: \Book.createdAt, order: .reverse)`
  - triggert Derived-State-Neuberechnung über `.task(id: activeDerivedTaskToken)`
  - hält Debounce-Task für Suche (`pendingRecomputeTask`)
- Gut:
  - Derived State ist aus dem direkten Renderpfad herausgezogen (`LibraryDerivedStateBuilder`, `LibraryDerivedStateCoordinator`).
- Bleibendes Risiko:
  - die gesamte Bibliothek hängt trotzdem an einem Full-Collection-Query.
  - Grid/List/Cover-Pfade bleiben teuer, wenn Cover-Cache nicht greift.

**Konkreter Grund:** zentrale Bildschirm-Invalidation + High-frequency User Input + Cover-Rendering in Listen/Grid.

#### B. Cover-Rendering (`Shelf Notes/LibraryView/LibraryRowCoverView.swift`, `Shelf Notes/CachedAsyncImage.swift`)
**Warum Hot Path:** Jede Zeile/Kachel braucht potenziell ein Cover.

Konkrete Beobachtungen:
- `LibraryRowCoverView.swift` ist mit 356 Zeilen groß für ein reines Row-Cover-Thema.
- `CachedAsyncImage.swift` enthält gleichzeitig:
  - Memory Cache
  - Disk Cache
  - User Cover Store
  - SwiftUI Image View
- Cache-Miss bedeutet potenziell Disk-I/O, URL-Auflösung, Decode, Thumbnail-Handling.

**Konkreter Grund:** High-traffic render path + kombinierte I/O/Decode/Presentation-Verantwortung.

#### C. Statistikscreen (`Shelf Notes/Stats/StatisticsView.swift`, `Shelf Notes/Stats/StatisticsView+Caching.swift`)
**Warum Hot Path:** Der Screen zieht alle Bücher und berechnet mehrere abgeleitete Darstellungen.

Konkrete Beobachtungen:
- `@Query var books: [Book]`
- Im `body` werden direkt berechnet:
  - `let signature = booksSignature(books)`
  - `let statsKey = makeStatsCacheKey(signature: signature)`
  - `let heatmapKey = makeHeatmapCacheKey(signature: signature)`
- Kommentar in `StatisticsView+Caching.swift` sagt selbst, dass `booksSignature(_:)` auf **jedem View-Update** läuft und O(n) über Bücher ist.

**Konkreter Grund:** O(n)-Signatur im Renderpfad; danach task-basierte Cache-Rebuilds.

#### D. Progress Hub (`Shelf Notes/ProgressHub/ProgressHubView.swift`)
**Warum Hot Path:** Aggregations-Dashboard mit mehreren Queries.

Konkrete Beobachtungen:
- vier `@Query`s im gleichen View:
  - Bücher
  - Challenges
  - Goals
  - Sessions
- `ProgressHubMetricsModel.makeInputToken(...)` läuft pro Renderdurchlauf.
- Positiv: tatsächliche Metrikberechnung liegt in `ProgressHubMetricsModel`.

**Konkreter Grund:** mehrere SwiftData-Queries in einem Root-Screen + Tokenbildung im Renderpfad.

#### E. Goals (`Shelf Notes/Goals/GoalsView.swift`)
**Warum Hot Path:** sichtbar oft, kleiner Screen, aber unnötig save-heavy.

Konkrete Beobachtungen:
- zwei `@Query`s (`goals`, `books`)
- `GoalsYearMetricsBuilder.make(...)` wird direkt im `body` aufgerufen
- `Stepper` speichert bei jeder Änderung sofort via `saveGoal(...)`
- `loadGoalForSelectedYear()` erzeugt fehlendes Ziel sofort und speichert direkt

**Konkreter Grund:** direkte Aggregation im Renderpfad + Save-Sturm bei Stepper-Interaktionen.

#### F. Collection Detail (`Shelf Notes/CollectionDetailView.swift`)
**Warum Hot Path:** nicht global, aber unnötig write-heavy.

Konkrete Beobachtungen:
- `TextField("Listenname", text: $nameDraft)` speichert in `.onChange` auf **jeden Keystroke**.

**Konkreter Grund:** per-keystroke Save auf main-actor-gebundenem ModelContext.

#### G. Timeline (`Shelf Notes/Timeline/ReadingTimelineView.swift`)
**Warum Hot Path:** horizontales Scrolling mit potenziell vielen Elementen.

Konkrete Beobachtungen:
- `@Query(filter: #Predicate<Book> { $0.statusRawValue == "finished" || $0.statusRawValue == "Gelesen" })`
- abgeleitete Timeline wird in `ReadingTimelineViewModel` ausgelagert.
- grundsätzlich solide, aber bei sehr vielen `finishedBooks` kann horizontale Cover-Darstellung teuer werden.

**Konkreter Grund:** große horizontale Scroll-Fläche + viele Cover-Views.

---

### 2) Sync / Storage

#### A. Container Bootstrap (`Shelf Notes/AppContainerHostView.swift`)
**Positiv:**
- robustes Recovery-Design statt `fatalError`
- klare Trennung zwischen CloudKit- und local-only Store
- explizite Notfallpfade für iCloud-Probleme

**Risiken / Trade-offs:**
- local-only ist absichtlich ein eigener Datenstand. Das ist technisch sauber, aber UX-seitig heikel, weil Daten divergieren können.
- Es gibt keinen sichtbaren Merge-/Reconcile-Pfad zurück in den CloudKit-Store. **UNKNOWN**

#### B. Save-Strategie
**Beobachtung:**
- Direktes Speichern aus Views ist überall verbreitet.
- `ModelContext.saveWithDiagnostics()` ist nützlich, aber nur ein Wrapper um `save()` plus Diagnostik, keine Write-Policy.

**Risiko:**
- Viele kleine Saves auf dem MainActor.
- Keine zentrale Dedupe-/Batch-/Retry-Policy.

**Konkreter Grund:** MainActor contention + save storms + fehlende Vereinheitlichung der Write-Pfade.

#### C. One-time Repairs / Migrations
- `ReadingStatusMigrator` und `CollectionMembershipRepair` sind pragmatisch und hilfreich.
- Beide fetch-en Daten und speichern direkt im App-Start-/Task-Kontext.
- Das ist okay bei kleinem Datenbestand, aber im Wachstum spürbar.

**Konkreter Grund:** Full fetch and repair on startup tasks.

#### D. Cover Thumbnail Backfill (`Shelf Notes/CoverThumbnailer/CoverThumbnailer+Backfill.swift`)
**Beobachtung:**
- Backfill läuft absichtlich auf `@MainActor`, weil `ModelContext` in dieser App main-actor-gebunden ist.
- Es wird zwar yielded/gesleept, aber das bleibt UI-nahes I/O und Save-Work.
- `RootView` startet diesen Prozess verzögert im aktiven Zustand.

**Konkreter Grund:** main-actor-bound background maintenance + disk/network work + repeated saves.

#### E. CSV Import (`Shelf Notes/CSVImportExport/CSVImportExecutor.swift`)
**Beobachtung:**
- pro Zeile potenziell Remote Search
- pro importiertem Buch:
  - `modelContext.insert(book)`
  - `modelContext.saveWithDiagnostics()`
  - `await backfillThumbnail(book)`

**Konkreter Grund:** N x network + N x save + N x thumbnail work.

#### F. Remote Notification Capability
- `Shelf Notes/Info.plist` enthält `UIBackgroundModes = remote-notification`
- App-Entitlements haben `aps-environment = development`
- Im gescannten App-Code wurde kein klarer Push-Empfangspfad gefunden.

**Bewertung:** Konfiguration vorhanden, operative Nutzung **UNKNOWN**.

---

### 3) Concurrency

#### A. MainActor-gebundene App
- Viele zentrale Objekte sind `@MainActor`:
  - `AppBootstrapper`
  - `SyncDiagnostics`
  - `ProManager`
  - `ReadingTimerManager`
  - teils Challenge-/Stats-Snapshot-Fetches
- Das ist für SwiftUI/SwiftData nachvollziehbar, erhöht aber das Risiko von MainActor-Stau.

#### B. Gute Muster
- Stats und Challenges nutzen Value-Snapshots, damit schwere Rechenarbeit off-main laufen kann:
  - `Shelf Notes/Stats/StatisticsComputePipeline.swift`
  - `Shelf Notes/Challenges/ChallengeEngine+Snapshot.swift`
- `BookImportViewModel+Tasks.swift` trennt Search-/LoadMore-/Debounce-Tasks und arbeitet mit Generation-Tokens.

#### C. Schwache Stellen
- Viele Tasks hängen direkt an Views (`.task(id:)`, `Task {}` aus UI-Callbacks), ohne einheitliche zentrale Cancellation-/Tracing-Strategie.
- `ReadingTimerManager` sendet `objectWillChange` mehrfach manuell, weil `@Published`/Combine-Synthese abgesichert werden sollte. Das ist pragmatisch, aber ein Zeichen für empfindliche State-Komplexität.
- `ChallengesSummaryCard` refreshed per `.task(id: challenges.count)`; inhaltliche Änderungen bei gleicher Anzahl triggern nicht automatisch.

**Konkrete Gründe:** view-bound task lifetimes, uneinheitliche cancellation policy, main-actor-heavy writes, event trigger fragility.

---

## Refactor Map

### 1) Konkrete Splits

#### A. `Shelf Notes/CachedAsyncImage.swift`
Split in:
- `Shelf Notes/ImageCaching/ImageMemoryCache.swift`
- `Shelf Notes/ImageCaching/ImageDiskCache.swift`
- `Shelf Notes/ImageCaching/UserCoverStore.swift`
- `Shelf Notes/ImageViews/CachedAsyncImage.swift`
- optional `Shelf Notes/ImageViews/SyncedThumbnailView.swift`

**Nutzen:** klare Verantwortlichkeiten, bessere Testbarkeit, einfachere Performance-Profiling-Zuordnung.

#### B. `Shelf Notes/BookDetail/BookDetailView+Bindings.swift`
Split in:
- `BookDetailView+StatusBindings.swift`
- `BookDetailView+TagsBindings.swift`
- `BookDetailView+CollectionsBindings.swift`
- `BookDetailView+RatingBindings.swift`
- `BookDetailView+NotesBindings.swift`

**Nutzen:** weniger Koppelung, geringerer Merge-Konflikt-Radius, gezieltere Tests.

#### C. `Shelf Notes/Stats/StatisticsSnapshotBuilder.swift`
Split in:
- `StatisticsSnapshotBuilder+Overview.swift`
- `StatisticsSnapshotBuilder+ReadingVelocity.swift`
- `StatisticsSnapshotBuilder+TopLists.swift`
- `StatisticsSnapshotBuilder+Ratings.swift`
- `StatisticsSnapshotBuilder+YearOptions.swift`

**Nutzen:** fachliche Teilbereiche voneinander isolieren, geringeres Regressionsrisiko.

#### D. `Shelf Notes/BookImport/BookImportView/BookImportViewModel+Tasks.swift`
Split in:
- `BookImportViewModel+Search.swift`
- `BookImportViewModel+Pagination.swift`
- `BookImportViewModel+CompositeQueries.swift`
- `BookImportViewModel+Cancellation.swift`

**Nutzen:** Suchorchestrierung besser lesbar, Race-/Cancellation-Fehler leichter lokalisierbar.

#### E. `Shelf Notes/LibraryView/LibraryView+Header.swift`
Split in:
- `LibraryHeaderView.swift`
- `LibraryFilterBarView.swift`
- `LibraryAlphaHintView.swift`

**Nutzen:** UI wird modularer, Header-spezifische Änderungen schlagen weniger auf den Hauptscreen durch.

---

### 2) Cache- / Index-Ideen

#### A. Stats Signature entlasten
Aktuell:
- `booksSignature(_:)` läuft im `StatisticsView`-Renderpfad.

Idee:
- statsrelevanten `BookSnapshot` oder `StatisticsInvalidationSignature` einmal in einem `StatisticsSourceStore` erzeugen, aktualisiert über `@Query`-Änderung oder dedizierten Task.

Invalidation Keys:
- `book.id`
- `statusRawValue`
- `readFrom`, `readTo`
- `pageCount`
- `author`, `publisher`, `language`, `mainCategory`
- Tags/Categories counts + normalized hashes
- `readingSessionsSafe.count`

**Nutzen:** weniger O(n)-Arbeit im View-`body`.

#### B. Collection/Goal write buffer
- Debounced Save-Buffer für textuelle und stepper-basierte Änderungen.
- Kandidaten:
  - `Shelf Notes/CollectionDetailView.swift`
  - `Shelf Notes/Goals/GoalsView.swift`
  - potenziell Teile aus `BookDetailView+Bindings.swift`

**Nutzen:** weniger Saves, weniger CloudKit-/SwiftData-Druck, besseres UI-Gefühl.

#### C. CSV Import batching
- Statt jedem Row-Success sofort `save()`:
  - Save alle N Objekte oder am Ende eines Batches
  - Thumbnail-Backfill entkoppeln oder in zweiten Pass legen

**Nutzen:** deutlich weniger Save-Overhead.

#### D. Challenge Summary trigger stabilisieren
Aktuell:
- `ChallengesSummaryCard` keyed auf `challenges.count`

Besser:
- Signature über `id`, `completedAt`, `acknowledgedAt`, `periodStart`, `periodEnd`, `targetValue`

**Nutzen:** korrektere Aktualisierung ohne UI-Workaround.

#### E. Root-level Book Signatures wiederverwenden
- `RootView` baut bereits eine Tags-Signatur über `TagsIndexStore.taskSignature(books:)`.
- Ähnliches Muster könnte für weitere app-weite Derived Stores genutzt werden.

**Nutzen:** weniger duplizierte Aggregationslogik pro Screen.

---

### 3) Vereinheitlichungen

#### A. Write Service / Persistence Actions
Aktueller Zustand:
- Views speichern selbst.

Ziel:
- ein leichter Write-Service, kein Architekturumbau um des Umbaus willen.

Beispiel:
- `BookWriteService`
- `CollectionWriteService`
- `GoalWriteService`

Verantwortung:
- Mutationen
- Save-Throttling
- Diagnose-Hooks
- optionale side effects (z. B. `updatedAt` setzen)

**Nutzen:** weniger duplizierte Save-Logik, sauberere Hotfixes.

#### B. Shared signature helpers
- mehrere Stellen bauen eigene Invalidation-Tokens/Signaturen:
  - Stats
  - Progress Hub
  - Tags Index
  - Library

Ziel:
- kleine, testbare Signature-Utilities je Domäne statt View-lokaler Hash-Funktionen.

#### C. Logging / Observability konsolidieren
Aktuell:
- Sync-Diagnose ist vorhanden
- sonst wenig systematische Telemetrie

Ziel:
- `Logger`-Kategorien, z. B.:
  - `sync`
  - `import`
  - `cover`
  - `stats`
  - `timer`
  - `challenges`

**Nutzen:** Probleme reproduzierbarer, Profiling realistischer.

---

## Risiken & Edge Cases

### Datenverlust / Divergenz
- local-only Store ist bewusst getrennt vom CloudKit-Store.
- Wenn Nutzer zwischen Modi wechselt, entstehen zwei Datenwelten.
- Rückführung/Merge ist **UNKNOWN**.

### CloudKit-Schema-Risiken
- Die App meidet `@Attribute(.unique)` und setzt Defaults/optionale Beziehungen bewusst.
- Schemaänderungen ohne diese Regeln dürften schnell Probleme erzeugen.

### Multi-Device / Konflikte
- Konfliktverhalten bei konkurrierenden Änderungen auf mehreren Geräten ist nicht explizit modelliert.
- Wahrscheinlich wird auf Standardverhalten von SwiftData/CloudKit vertraut.
- Fachliche Konfliktstrategie ist **UNKNOWN**.

### Save-Frequenz
- Per-keystroke oder per-step Save kann bei mehreren Geräten/CloudKit unnötig Last erzeugen.

### Covers
- Vollauflösende User-Cover sind lokal, synced ist nur Thumbnail.
- Das ist ein sinnvoller Trade-off, muss aber fachlich klar bleiben.
- Edge Case: anderes Gerät hat nur Thumbnail und nie Full-Res-Datei.

### Import
- CSV-Import und Google-Books-Import verlassen sich auf externe API-Verfügbarkeit.
- Der gelieferte Projektstand enthält einen echten API-Key im Secret-File; Prozess- und Sicherheitsrisiko.

### Live Activity Extension
- `ShelfNotesLiveActivityBundle.swift` bindet nur `ShelfNotesLiveActivityLiveActivity()` ein.
- Weitere Template-/Control-Dateien sind vorhanden, aber aktuell nicht im WidgetBundle aktiv.
- Absicht dahinter ist **UNKNOWN**.

---

## Observability / Debuggability

### Schon vorhanden
- `Shelf Notes/SyncDiagnostics.swift`
  - iCloud-Status, Netzwerk, lokale Saves, Offline-Counter
- `Shelf Notes/SyncDiagnosticsView.swift`
  - Status-UI + Copy-to-Clipboard Diagnosebericht
- `Shelf Notes/ModelContext+Diagnostics.swift`
  - Save-Breadcrumbs mit Dateiquelle
- Value-snapshot-Pipelines in Stats/Challenges erleichtern isolierte Tests.
- Testabdeckung ist für reine Builder und Derived State ordentlich.

### Fehlend oder dünn
- keine einheitliche Performance-Metrik für Stats-Recompute, Cover-Backfill, CSV-Importdauer
- kein systematisches Logging für Task-Abbrüche / Search-Paging / Cover-Fallback-Kette
- UI-Tests sind sehr dünn (2 Dateien im `Shelf NotesUITests`-Target)

### Wie man Probleme reproduziert
- **Sync-Probleme**: `SettingsView` → `SyncDiagnosticsView`
- **Cover-Probleme**: Cache in Settings löschen, anschließend Bibliothek/Detail erneut öffnen
- **Import-Probleme**: `BookImportView` und `CSVImportExportView` liefern die wahrscheinlichsten Einstiegspunkte
- **Stats-Probleme**: `StatisticsView` plus zugehörige Tests (`StatisticsComputePipelineTests`, `StatisticsSnapshotBuilderTests`)
- **Collection-Beziehungsfehler**: App-Start-Pfade inkl. `CollectionMembershipRepair.swift`

---

## Open Questions
- Ist `ContentView.swift` nur ein Legacy-/Preview-Wrapper oder soll er produktiv noch eine Rolle spielen? **UNKNOWN**
- Ist `UIBackgroundModes = remote-notification` in `Shelf Notes/Info.plist` bewusst aktiv oder Altlast? **UNKNOWN**
- Soll es jemals eine Migration oder einen Merge vom local-only Store in den CloudKit-Store geben? **UNKNOWN**
- Gibt es eine formalisierte Schema-Migrationsstrategie jenseits von `ReadingStatusMigrator` und `CollectionMembershipRepair`? **UNKNOWN**
- Sind `ShelfNotesLiveActivity/ShelfNotesLiveActivity.swift`, `ShelfNotesLiveActivity/ShelfNotesLiveActivityControl.swift` und `ShelfNotesLiveActivity/AppIntent.swift` bewusst liegen gelassen oder bereinigungsreif? **UNKNOWN**
- Ist der reale Google Books API Key im gelieferten `Shelf Notes/config/secrets.xcconfig` ein versehentlich eingechecktes Artefakt oder ein geplanter lokaler Build-Zustand? **UNKNOWN**
- Gibt es fachliche Anforderungen an Konfliktauflösung bei parallelen Multi-Device-Änderungen? **UNKNOWN**
- Ist `Shelf Notes/unlimited_collections.storekit` lokal nur Hilfsdatei oder aktiv in einem Run-Scheme eingebunden? Im `project.pbxproj` war keine offensichtliche Referenz sichtbar. **UNKNOWN**

---

## First 3 Refactors I would do (P0)

### 1) Save-Throttling und Write-Service für UI-nahe Mutationen
**Ziel**
- Save-Stürme aus UI-Interaktionen reduzieren, ohne fachliches Verhalten zu ändern.

**Betroffene Dateien**
- `Shelf Notes/CollectionDetailView.swift`
- `Shelf Notes/Goals/GoalsView.swift`
- `Shelf Notes/BookDetail/BookDetailView+Persistence.swift`
- optional Teile aus `Shelf Notes/BookDetail/BookDetailView+Bindings.swift`

**Risiko**
- niedrig bis mittel
- Hauptgefahr: unbeabsichtigt spätere Persistierung als bisher; muss gegen App-Lifecycle/Disappear abgesichert werden.

**Erwarteter Nutzen**
- weniger MainActor-Druck
- weniger unnötige SwiftData-/CloudKit-Saves
- sauberere, zentralere Write-Policy

### 2) `CachedAsyncImage.swift` fachlich zerlegen
**Ziel**
- Cover-Pipeline entkoppeln, damit Cache-, Disk- und View-Logik separat wartbar und testbar werden.

**Betroffene Dateien**
- `Shelf Notes/CachedAsyncImage.swift`
- indirekt `Shelf Notes/LibraryView/LibraryRowCoverView.swift`
- indirekt Detail-/Timeline-Cover-Verwendung

**Risiko**
- mittel
- Cover-Regressionen in mehreren Screens möglich; sollte durch gezielte Smoke-Tests in Library, Detail, Timeline abgesichert werden.

**Erwarteter Nutzen**
- bessere Wartbarkeit im zentralen Renderpfad
- leichtere Profilierung von Cache Misses / Decode / Disk I/O
- geringerer Merge-Konflikt-Radius

### 3) Stats invalidation / source store aus dem View-`body` weiter herausziehen
**Ziel**
- die O(n)-Signatur und Snapshot-Neubildung in `StatisticsView` entschärfen.

**Betroffene Dateien**
- `Shelf Notes/Stats/StatisticsView.swift`
- `Shelf Notes/Stats/StatisticsView+Caching.swift`
- `Shelf Notes/Stats/StatisticsComputePipeline.swift`
- optional neue Datei wie `Shelf Notes/Stats/StatisticsSourceStore.swift`

**Risiko**
- mittel
- Statistikscreen ist breit; falsche Invalidation kann stale data erzeugen.

**Erwarteter Nutzen**
- weniger Arbeit pro View-Update
- klarere Trennung zwischen Query/Input, Invalidation und Compute
- bessere Grundlage für weitere Statistik-Features
