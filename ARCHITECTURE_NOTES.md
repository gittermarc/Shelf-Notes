# ARCHITECTURE_NOTES.md

## Scope / Methode

Diese Notizen basieren auf statischer Analyse des ZIPs. Es wurden Ordnerstruktur, Swift-Dateien, Xcode-Projektdatei, Entitlements, Info.plist, xcconfig-Dateien und zentrale Hot Paths geprüft. Es wurde kein Build, kein Testlauf und keine Laufzeitprofilierung ausgeführt.

Priorität der Analyse:

1. Sync, Storage und Model: SwiftData, CloudKit, Stores, Migrations, Caches.
2. Entry Points und Navigation.
3. Große Views und Services: Wartbarkeit, Performance, Concurrency.
4. Konventionen und Workflows für künftige Features.

---

## Big Files List

Top 15 Swift-Dateien nach Zeilen aus `Shelf Notes/` und `ShelfNotesLiveActivity/`, gemessen per `wc -l`.

| Rang | Datei | Zeilen | Grober Zweck | Warum riskant |
|---:|---|---:|---|---|
| 1 | `Shelf Notes/Stats/StatisticsSnapshotBuilder.swift` | 667 | Baut Statistik-Snapshots, Summaries und Top-Listen. | Viele Aggregationen, Datumslogik und Sortierungen in einer Datei; hohe Regressions- und Performance-Gefahr bei neuen Feldern. |
| 2 | `Shelf Notes/Challenges/ChallengeEngine+Compute.swift` | 521 | Berechnet Challenge-Fortschritte über Sessions, Bücher und Zeiträume. | Viele Metriken und Periodenregeln; kleine Änderungen können Completion, Reroll oder Progress falsch machen. |
| 3 | `Shelf Notes/Collections/CollectionsSmartActionBuilder.swift` | 470 | Erzeugt Smart Actions für Collections. | Heuristiken hängen an Book-, Tag-, Status- und Collection-Daten; schwer isolierbar ohne klare Submodule. |
| 4 | `Shelf Notes/Stats/StatisticsHeatmapBuilder.swift` | 444 | Baut Heatmap-Daten für Leseaktivität. | Potenziell verschachtelte Datums-/Session-Loops; kritisch für Stats-Renderpfad. |
| 5 | `Shelf Notes/Settings/AppearanceSettings/AppearancePreferences.swift` | 407 | Appearance-Optionen, Storage Keys und Presets. | Viele persistierte UI-Keys in einer Datei; Risiko für Key-Drift und ungewollte globale View-Invalidations. |
| 6 | `Shelf Notes/BookDetail/BookDetailView+Cards.swift` | 400 | Detailkarten für BookDetail. | Große SwiftUI-Builder-Datei; Änderung an einer Card kann Compile-Zeit und View-Invalidation beeinflussen. |
| 7 | `Shelf Notes/LibraryView/LibraryView+Header.swift` | 396 | Bibliotheksheader, Counts, Aktionen und UI-Zusammenfassung. | Header hängt an abgeleiteten Library-Daten; Risiko für teure Rekalkulation und komplexe Zustände. |
| 8 | `Shelf Notes/TagsView/TagHygieneBuilder.swift` | 391 | Erzeugt Tag-Hygiene-Insights. | Normalisierung, Dedupe und Vorschlagslogik sind korrektheitskritisch; ähnliche Logik existiert auch in Suggestions/Index. |
| 9 | `Shelf Notes/TagsView/TagSuggestionEngine.swift` | 387 | Tag-Vorschlagsengine. | Heuristiken scannen Bibliotheksdaten; Risiko für doppelte Normalisierung und O(n) Arbeit bei jeder Aktualisierung. |
| 10 | `Shelf Notes/LibraryView/LibraryView+Grid.swift` | 386 | Grid-Layout der Bibliothek. | Scroll-Hotpath mit Cover-Rendering, Navigation und Selektionszustand; jede Side Effect wäre teuer. |
| 11 | `Shelf Notes/BookDetail/BookDetailView+Bindings.swift` | 386 | Bindings zwischen UI und Book-Feldern. | Viele persistente Felder und Nebenwirkungen gebündelt; Risiko für unbeabsichtigte Saves und Modellkopplung. |
| 12 | `Shelf Notes/BookDetail/Sessions/SessionsCard.swift` | 385 | Session-Liste, Quick-Log/Edit und Challenge-Refresh. | Mischt Query, UI, Mutationen, Save und Challenge-Refresh; Hotspot für MainActor- und Datenkonsistenzprobleme. |
| 13 | `Shelf Notes/AddBook/AddBookViewModel.swift` | 385 | State Machine für manuelles Hinzufügen und Import-Drafts. | Viele Published-Zustände und Validierung; Sheet-/Task-State kann leicht inkonsistent werden. |
| 14 | `Shelf Notes/Stats/StatisticsSourceStore.swift` | 368 | Beobachtet Books/Sessions, baut Signaturen und Cache-State. | MainActor-Signaturen sortieren und hashen viele Felder; bei großen Bibliotheken potenzieller Contention-Punkt. |
| 15 | `Shelf Notes/TagsView/TagsView.swift` | 361 | Tags-Rootscreen mit Dashboard, Suche, Hygiene und Mutationen. | Große Root-View mit viel abgeleitetem Zustand; Risiko für View-Invalidations und UI-/Domain-Kopplung. |

---

## Hot Path Analyse

### Rendering / Scrolling

#### `Shelf Notes/LibraryView/LibraryView.swift`

Hotspot-Gründe:

- `activeDerivedTaskToken` ruft `LibraryDerivedStateBuilder.makeInputToken(books:)` auf.
- `LibrarySourceSnapshot.taskSignature(books:)` iteriert über alle Bücher und hasht Titel, Autor, Status, Tags, Notizstatus, ISBN, Lesezeitraum und Rating-Bucket.
- `displayedBooksForCurrentDerivedState` erstellt pro Zugriff ein `Dictionary(uniqueKeysWithValues: books.map { ($0.id, $0) })`.
- `alphaSectionsForUI` erstellt erneut ein `booksByID`-Dictionary.
- `libraryContent` liest `displayed`, `counts`, `alphaSections` und `alphaLetters` im View-Aufbau.

Bewertung:

- Die Derived-State-Pipeline ist bereits besser als direkte Filter-/Sortierlogik im Body.
- Der Token- und Mapping-Teil bleibt aber O(n) im SwiftUI-Invalidationspfad.
- Für kleine Bibliotheken ist das wahrscheinlich unkritisch; für große Bibliotheken wird jede globale Appearance-/Query-/Search-Invalidation teuer.

Konkreter Optimierungshebel:

- `booksByID`, `sourceSignature`, `displayedBookIDs` und Alpha-Sektionen in einen `LibraryDisplayStore` oder eine erweiterte `LibraryDerivedStateCoordinator`-Schicht verschieben.
- Body nur noch fertige Value-States lesen lassen.
- `booksByID` einmal pro Source-Signature bauen.

#### `Shelf Notes/LibraryView/LibraryView+Grid.swift`

Hotspot-Gründe:

- Grid ist Scroll-Hotpath.
- Cover-Views, NavigationLinks und Selektionszustand laufen in vielen Zellen.
- Gute Gegenmaßnahme ist bereits vorhanden: `LibraryRowCoverView` ist laut Dateikommentar side-effect-free und dekodiert synced thumbnails off-main.

Risiko:

- Jede spätere Persistenz-Aktion oder Remote-URL-Persistierung in Grid-Zellen würde Scroll-Performance und CloudKit-Save-Frequenz verschlechtern.

Konkreter Optimierungshebel:

- Grid-Cards strikt read-only halten.
- Cover-Resolver/Backfill nur in Import, Detail oder expliziten Hintergrundjobs ausführen.

#### `Shelf Notes/CoverThumbnailer/CoverThumbnailer.swift`

Hotspot-Gründe:

- `BookCoverThumbnailView` dekodiert `book.userCoverData` mit `UIImage(data:)` direkt in `body`.
- `localUserCoverUIImage()` liest lokale Full-res-Datei mit `UIImage(contentsOfFile:)` direkt aus dem View-Pfad.
- Bei Remote-Fallback wird in `onResolvedURL` `book.persistResolvedCoverURL` aufgerufen und anschließend ein Task für Thumbnail-Refresh gestartet.

Bewertung:

- Für Detailflächen ist Persistierung des resolved URL nachvollziehbar.
- Für wiederholte Listen-/Grid-Flächen ist diese View ungeeignet. Das Projekt nutzt dafür bereits `LibraryRowCoverView`.
- Falls `BookCoverThumbnailView` in scrollenden Flächen außerhalb der Library verwendet wird, entsteht synchrones Decode-/File-I/O-Risiko.

Konkreter Optimierungshebel:

- `BookCoverThumbnailView` intern auf `SyncedThumbnailImage` und `CoverImageLoader` umstellen.
- `persistResolvedCoverURL` nur durch explizite Policy erlauben, nicht als Default in einer allgemeinen Cover-View.

#### `Shelf Notes/CachedAsyncImage.swift` und `Shelf Notes/CoverImageLoader.swift`

Hotspot-Gründe:

- `CachedAsyncImage` startet `.task(id: url)` pro URL.
- `CoverImageLoader` hat Memory- und Disk-Cache, aber keinen sichtbaren In-flight-Request-Deduper.
- Viele identische oder ähnliche Cover-URLs können parallel geladen werden, bis Cache gefüllt ist.

Gegenmaßnahmen im Code:

- Memory Cache.
- Disk Cache in `Caches/cover-cache`.
- URLRequest nutzt Cache Policy.
- Decode und Disk-I/O laufen off-main.

Konkreter Optimierungshebel:

- In-flight-Dedupe nach normalisierter URL einführen.
- Disk-Cache-Größenlimit und LRU/Pruning ergänzen.
- Remote-Failure-Cache mit kurzer TTL für fehlerhafte Kandidaten ergänzen.

#### `Shelf Notes/Stats/StatisticsView.swift` und `Shelf Notes/Stats/StatisticsSourceStore.swift`

Hotspot-Gründe:

- `StatisticsView` lädt alle Books über `@Query`.
- `StatisticsSourceStore.booksSignature(_:)` sortiert alle Books nach UUID und hasht viele Felder.
- `sessionsSignature(_:)` sortiert Books und Sessions und hasht Session-Daten.
- Signatur- und Snapshot-Erzeugung laufen MainActor-nah, die eigentliche Statistikberechnung wird danach in `StatisticsComputePipeline` detached.

Gegenmaßnahmen im Code:

- `StatisticsSourceSnapshot` und `StatisticsSessionSourceSnapshot` sind Value-Snapshots.
- `StatisticsComputePipeline` nutzt `Task.detached(priority: .utility)`.
- Cache Keys trennen Stats und Heatmap.

Konkreter Optimierungshebel:

- Signature-Inkremente pro Book/Session prüfen, statt komplette sortierte Listen bei jeder relevanten Änderung zu hashen.
- Session-Day-Expansion für Heatmaps cachen.
- Große Berechnungen stärker cancellation-aware machen.

#### `Shelf Notes/TagsView/TagsIndexStore.swift`, `TagSuggestionEngine.swift`, `TagHygieneBuilder.swift`

Hotspot-Gründe:

- Tags-Index, Suggestions und Hygiene scannen ähnliche Book-/Tag-Daten.
- `RootView` triggert `tagsIndexStore.update(books:signature:)` per `.task(id: tagsIndexSignature)`.
- Mehrere Feature-Screens können ähnliche Normalisierung wiederholen.

Konkreter Optimierungshebel:

- Gemeinsamen `LibrarySemanticIndex` oder `TagsDomainIndex` einführen.
- Normalisierte Tags, BookIDs pro Tag, unbenutzte/ähnliche Tags und Tag-Counts einmal pro Books-Signature bauen.
- Suggestions, Hygiene, Tags Dashboard und Library-Filter daraus speisen.

---

### Sync / Storage

#### `Shelf Notes/AppContainerHostView.swift`

Hotspot-Gründe:

- Datei enthält Bootstrapper, StorageMode, ModelContainerFactory, AppContainerHostView, LocalOnlyBanner und FailureView.
- Sync-/Store-Policy ist fachlich kritisch, aber mit UI vermischt.
- `ModelContainerFactory` definiert Schema, Store-URLs, CloudKit-/Local-only-Konfigurationen.

Risiken:

- Künftige Modelländerungen, Store-Migrationen und UX für Startfehler landen in einer großen Datei.
- CloudKit- und Local-only-Datenstände bleiben bewusst getrennt; UX muss das dauerhaft klar kommunizieren.

Konkreter Optimierungshebel:

- `StorageMode`, `AppBootstrapper`, `ModelContainerFactory`, FailureView und Banner splitten.
- Store-Policy testbarer machen.

#### `Shelf Notes/RootView.swift` Cover-Backfill

Hotspot-Gründe:

- Beim aktiven ScenePhase-Start wird ein Utility-Task verzögert gestartet.
- `CoverThumbnailer.backfillAllBooksIfNeeded` fetched alle Books, filtert pending Books und arbeitet in Batches.
- `backfillThumbnailIfNeeded` kann für jedes Book ein `saveWithDiagnostics()` auslösen.

Gegenmaßnahmen im Code:

- Einmal-Flag `did_run_cover_backfill_v2`.
- Verzögerung nach Launch.
- Batchgröße 4 und Inter-Batch-Delay 650 ms.
- Cancel bei inaktiver ScenePhase.

Risiken:

- Viele kleine Saves können viele CloudKit-Transaktionen erzeugen.
- Wird der Task vor Abschluss gecancelt, bleibt das Flag false und der Backfill startet später erneut.
- Remote-Cover-Fetch plus Thumbnail-Save direkt nach Launch kann Startup, Akku und Datenverbrauch beeinflussen.

Konkreter Optimierungshebel:

- Backfill-Fortschritt pro Book oder pro Batch persistieren.
- Saves batchen, wenn SwiftData/CloudKit-Verhalten das zulässt.
- Backfill optional in Settings/Debug-Diagnose sichtbar machen.

#### `Shelf Notes/CollectionMembershipRepair.swift`

Hotspot-Gründe:

- Fetches alle Books und Collections.
- Dedupliziert beide Seiten.
- Erzwingt Symmetrie Book -> Collection und Collection -> Book.
- Läuft einmalig pro Store-Scope beim Container-Ready.

Bewertung:

- Sinnvoller Repair für alte Datenstände.
- Bei sehr großer Bibliothek potenziell spürbarer Launch-Workload.

Konkreter Optimierungshebel:

- Metrik/Log für Anzahl geänderter Beziehungen.
- Repair-Versionen dokumentieren.
- Optional Fortschritt/Fehler in SyncDiagnostics sichtbar machen.

#### `Shelf Notes/Challenges/ChallengeRefreshCoordinator.swift`

Hotspot-Gründe:

- `prepareCurrentChallenges` läuft nach Container-Ready.
- Session-Saves rufen `refreshAfterReadingSessionSave` auf, das Current Challenges vorbereitet, aktive Challenges fetched, Progress Map berechnet und Notifications postet.

Risiken:

- Session-Save wird fachlich an Challenge-Refresh gekoppelt.
- Bei vielen Sessions oder Challenges kann ein Save mehr MainActor-Arbeit auslösen als erwartet.

Konkreter Optimierungshebel:

- Challenge-Fetch/Save in ein Repository kapseln.
- Progress-Berechnung rein value-basiert halten und Caches nach Session-Signature nutzen.

#### `Shelf Notes/SyncDiagnostics.swift`

Hotspot-Gründe:

- Singleton `@MainActor ObservableObject`.
- Beobachtet Network Path, iCloud Account, UserRecordID und lokale Saves.
- `diagnosticsReport` fasst Gerät, Netzwerk, iCloud und lokale Save-Breadcrumbs zusammen.

Limitierung:

- SwiftData-CloudKit-Upload-/Download-Fortschritt wird nicht direkt beobachtet.
- `lastLocalSave` bedeutet nicht, dass CloudKit-Sync abgeschlossen ist.

Konkreter Optimierungshebel:

- Diagnose klar zwischen lokal gespeichert und cloud-synchronisiert unterscheiden.
- Repair-/Migration-/Backfill-Events in Diagnostics aufnehmen.
- Support-Export ohne sensible Daten anbieten.

#### Full-res Cover Storage

Hotspot-Gründe:

- `Book.userCoverData` syncs als Thumbnail.
- `Book.userCoverFileName` referenziert lokale Full-res-Datei.
- Auf einem zweiten Gerät kann die Full-res-Datei fehlen, obwohl das Thumbnail vorhanden ist.

Bewertung:

- Gute CloudKit-Payload-Entscheidung für Performance und Speicher.
- UX muss akzeptieren, dass Full-res User-Cover gerätespezifisch sind.

Open Point:

- **UNKNOWN**: Ob Thumbnail-only für Multi-Device dauerhaft gewünscht ist.

---

### Concurrency

#### MainActor-Grundlage

- Das App-Target setzt `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
- SwiftData-`ModelContext` wird in Views und Services MainActor-nah genutzt.
- `AppBootstrapper`, `ChallengeRefreshCoordinator`, `SyncDiagnostics` und `ReadingTimerManager` sind MainActor-gebunden.

Risiken:

- Große Signaturen, Snapshots und Repairs können MainActor blockieren.
- Entwickler könnten versehentlich teure pure Arbeit auf MainActor halten, weil Default Actor Isolation dies begünstigt.

Gegenmaßnahmen:

- Stats nutzen Value-Snapshots und `Task.detached`.
- Cover-Konvertierung und ImageIO-Thumbnailing laufen off-main.
- CoverImageLoader verlagert File-I/O und Decode auf DispatchQueue.

#### Task-Lifetimes

- `RootView` hält `coverBackfillTask` und cancelt bei inaktiver ScenePhase.
- `LibraryView` debounced Search mit `pendingRecomputeTask`.
- `BookImportViewModel+Tasks.swift` hält eigene Tasks für Suche, Load-More und Debounce und cancelt sie explizit.
- `ReadingTimerManager` persistiert aktive und pending Sessions in App Group UserDefaults.

Risiken:

- Nicht jede detached Berechnung prüft innerhalb langer Loops kooperativ auf Cancellation.
- View-Tasks können bei schneller Navigation mehrfach starten, wenn Tokens zu grob oder zu fein sind.
- Timer-Pending-Completion hängt davon ab, dass die App die Pending-Daten später verarbeitet.

#### Reading Timer / Live Activity

- App-seitig: `Shelf Notes/Shared/LiveActivity/ReadingTimerManager.swift`.
- Extension-seitig: `ShelfNotesLiveActivity/ReadingSessionLiveActivityIntents.swift`.
- Steuerung läuft über App-Group-UserDefaults-Blobs für active und pending completion.

Risiken:

- Wenn Stop über Live Activity erfolgt und die App lange nicht geöffnet wird, bleibt nur Pending Completion persistiert; eine `ReadingSession` entsteht erst später.
- `ReadingTimerManager` verwendet manuelle `objectWillChange.send`-Aufrufe wegen dokumentiertem Update-Problem im Code; das ist ein bewusster Workaround, sollte aber nicht überall kopiert werden.

---

## Refactor Map

### Konkrete Splits

#### `Shelf Notes/AppContainerHostView.swift` -> Persistence/AppBootstrap

Ziel:

- Store-/Sync-Policy aus UI entfernen.

Vorschlag:

- `Shelf Notes/Persistence/StorageMode.swift`
- `Shelf Notes/Persistence/ModelContainerFactory.swift`
- `Shelf Notes/Persistence/AppBootstrapper.swift`
- `Shelf Notes/AppBootstrap/AppContainerHostView.swift`
- `Shelf Notes/AppBootstrap/ModelContainerFailureView.swift`
- `Shelf Notes/AppBootstrap/LocalOnlyBanner.swift`

Nutzen:

- Leichtere Tests für Container-Erstellung.
- Klarere Verantwortlichkeit für CloudKit vs Local-only.
- Weniger Risiko bei SwiftData-Migrationen.

#### `Shelf Notes/LibraryView/LibraryView.swift` -> Display Store / Index

Ziel:

- Body-nahe O(n)-Arbeit entfernen.

Vorschlag:

- `Shelf Notes/LibraryView/LibraryDisplayStore.swift`
- `Shelf Notes/LibraryView/LibraryBooksIndex.swift`
- `Shelf Notes/LibraryView/LibraryAlphaSectionResolver.swift`
- `Shelf Notes/LibraryView/LibrarySearchDebouncer.swift`

Verschiebung:

- `LibrarySourceSnapshot.taskSignature(books:)` aus Body-Token-Pfad in Store.
- `booksByID` in Index pro Source-Signature.
- `displayedBooksForCurrentDerivedState` und `alphaSectionsForUI` als Store-Ausgabe.

Nutzen:

- Stabilere SwiftUI-Invalidations.
- Weniger Dictionary-Allokationen im Renderpfad.
- Besser messbare Search-/Sort-Performance.

#### `Shelf Notes/CoverThumbnailer/CoverThumbnailer.swift` -> Cover Pipeline

Ziel:

- Cover-Rendering, Remote-Resolution, Thumbnail-Sync und Cache klar trennen.

Vorschlag:

- `Shelf Notes/Cover/CoverRenderPolicy.swift`
- `Shelf Notes/Cover/CoverImageRepository.swift`
- `Shelf Notes/Cover/CoverThumbnailWriter.swift`
- `Shelf Notes/Cover/CoverRemoteResolver.swift`
- `Shelf Notes/Cover/CoverBackfillService.swift`

Verschiebung:

- UI-Views lesen nur Render-State.
- Persistierende URL-/Thumbnail-Updates laufen über Service-Methoden.
- `BookCoverThumbnailView` wird read-only by default; persistierende Variante explizit benennen.

Nutzen:

- Weniger Sync-Side-Effects aus Views.
- Einfachere Cache-Invalidation.
- Einheitliche off-main Decode-Pipeline.

#### `Shelf Notes/Stats/StatisticsSnapshotBuilder.swift`

Ziel:

- Aggregationen nach Verantwortung trennen.

Vorschlag:

- `StatisticsSummaryBuilder.swift`
- `StatisticsTopListsBuilder.swift`
- `StatisticsRatingStatsBuilder.swift`
- `StatisticsYearOptionsBuilder.swift`
- `StatisticsDateParsing.swift`

Nutzen:

- Kleinere Testflächen.
- Weniger Merge-Konflikte.
- Schnellere Orientierung bei neuen Statistik-Kennzahlen.

#### `Shelf Notes/Stats/StatisticsHeatmapBuilder.swift`

Ziel:

- Datumslogik, Session-Splitting und Heatmap-Layout trennen.

Vorschlag:

- `StatisticsHeatmapRangeBuilder.swift`
- `StatisticsSessionDayExpander.swift`
- `StatisticsHeatmapGridBuilder.swift`
- `StatisticsMonthAxisBuilder.swift`

Nutzen:

- Session-Day-Expansion kann separat gecacht und getestet werden.
- Weniger Risiko bei Kalender-/Zeitzonenbugs.

#### `Shelf Notes/Challenges/ChallengeEngine+Compute.swift`

Ziel:

- Metrikberechnung nach ChallengeMetric modularisieren.

Vorschlag:

- `ChallengeProgressComputing.swift` als Protokoll oder enum-dispatch.
- `ChallengeReadingMinutesComputer.swift`
- `ChallengeBooksFinishedComputer.swift`
- `ChallengePagesReadComputer.swift`
- `ChallengeSessionNotesComputer.swift`

Nutzen:

- Neue Metriken ohne Änderung an einer 500-Zeilen-Datei.
- Testfälle pro Metric fokussierter.

#### `Shelf Notes/TagsView/TagHygieneBuilder.swift` und `TagSuggestionEngine.swift`

Ziel:

- Gemeinsame Normalisierung und Indexbildung zentralisieren.

Vorschlag:

- `Shelf Notes/TagsView/TagsDomainIndex.swift`
- `Shelf Notes/TagsView/TagSimilarityIndex.swift`
- `Shelf Notes/TagsView/TagUsageIndex.swift`

Nutzen:

- Weniger doppelte Scans.
- Einheitlichere Vorschläge und Hygiene-Regeln.

#### `Shelf Notes/Settings/AppearanceSettings/AppearancePreferences.swift`

Ziel:

- Persistierte Keys, Optionen, Presets und Reset-Logik entkoppeln.

Vorschlag:

- `AppearanceStorageKey.swift`
- `AppearanceOptions.swift`
- `AppearancePreset.swift`
- `AppearancePreferenceStore.swift`

Nutzen:

- Weniger Key-Drift.
- Einfachere Tests für Defaults und Presets.

---

### Cache- und Index-Ideen

#### Library

- `LibraryBooksIndex`
  - Key: `sourceSignature`.
  - Daten: `booksByID`, `bookSnapshots`, `tagCounts`, `statusCounts`.
- `LibraryDisplayCacheKey`
  - Key-Bestandteile: `sourceSignature`, Search Text, Statusfilter, Tagfilter, Notesfilter, SortField, SortDirection, Layout/Alpha-Flag.
- Invalidation:
  - Book-Feldänderungen, die in `LibrarySourceSnapshot` enthalten sind, invalidieren Display-State.
  - Cover-Feldänderungen sollten Display-State nicht invalidieren, wenn Sort/Filter davon unabhängig bleiben.

#### Tags

- `TagsDomainIndex`
  - Key: `TagsIndexBuilder.taskSignature(books:)` oder gemeinsamer Book-Semantic-Key.
  - Daten: normalisierte Tags, Originalschreibweisen, BookIDs pro Tag, Counts, ähnliche Tags.
- Invalidation:
  - Nur bei Änderungen an `Book.tags`, `Book.status`, optional `Book.title/author` für Suggestions.

#### Stats / Challenges

- `StatisticsBookSnapshot` existiert bereits; Signatur inkrementell prüfen.
- `SessionDayExpansionCache`
  - Key: `sessionsSignature`, Kalender-ID, Zeitzone, Jahr.
  - Daten: Minuten/Tage/Counts pro Tag.
- `ChallengeProgressCacheKey`
  - Key: `periodStart`, `periodEnd`, `metric`, `sessionsSignature`, `finishedBooksSignature`.
- Invalidation:
  - Session-Add/Edit/Delete invalidiert Session-Signature.
  - Book-Statuswechsel zu oder von finished invalidiert Challenge/Stats für finished books.
  - Rating/Notes-Änderungen invalidieren nur betroffene Metriken.

#### Cover

- `CoverMemoryKey`
  - Key: `bookID`, Hash von `userCoverData`, target maxPixel, contentMode.
- `RemoteCoverKey`
  - Key: normalisierte URL inklusive Google-Zoom-Policy.
- `RemoteFailureCache`
  - Key: URL.
  - TTL: kurz, zum Beispiel 1 bis 24 Stunden je nach Fehlerart.
- Invalidation:
  - `userCoverData` geändert: synced thumbnail cache entfernen.
  - `thumbnailURL` oder `coverURLCandidates` geändert: remote candidate cache für Book erneuern.
  - User löscht Cover-Cache in Settings: Disk, Memory und SyncedThumbnailMemoryCache werden bereits gelöscht.

---

### Vereinheitlichungen

#### Repository / Store Pattern

Aktueller Zustand:

- Views nutzen `@Query` direkt.
- Viele Builder sind pure und gut testbar.
- SwiftData-Fetch/Save ist noch teilweise in Views, Coordinators und Engines verteilt.

Vorschlag:

- Für SwiftData-kritische Domänen schlanke Repositories einführen:
  - `BookRepository`
  - `ReadingSessionRepository`
  - `CollectionRepository`
  - `ChallengeRepository`
  - `GoalRepository`
- Repositories sollen nicht schwergewichtig sein; Ziel ist konsistente FetchDescriptor, Save-Diagnostics und Mutation-Policy.

#### Domain Indices

- Ein gemeinsamer Book-Snapshot/Index kann Library, Tags, Stats und Collections entlasten.
- Wichtig: Nicht ein riesiges God-Object bauen. Besser getrennte, kleine Indices mit klaren Keys:
  - `LibraryBooksIndex`
  - `TagsDomainIndex`
  - `ReadingAnalyticsIndex`
  - `CollectionDashboardIndex`

#### Dependency Injection

Aktueller Zustand:

- Singletons: `GoogleBooksClient.shared`, `ImageDiskCache.shared`, `ImageMemoryCache.shared`, `SyncDiagnostics.shared`, `ProManager` als EnvironmentObject.

Vorschlag:

- Für Tests und Previewbarkeit Protokolle oder Environment Keys für Netzwerk, CoverLoader und Purchase-Service ergänzen.
- Nicht alles auf einmal refactoren; zuerst GoogleBooksClient und CoverImageLoader, weil sie externe I/O haben.

---

## Risiken & Edge Cases

### Datenverlust / Datenabweichung

- Local-only-Modus ist ein separater Store. Nutzer können Änderungen im Local-only-Store erzeugen, die später nicht automatisch im CloudKit-Store erscheinen.
- App zeigt Banner/Alert, aber ein späterer Merge-Workflow ist **UNKNOWN**.
- Full-res User-Cover sind lokal. Zweitgeräte bekommen nur das synchronisierte Thumbnail.
- `Book.userCoverFileName` kann auf einem anderen Gerät oder nach Datenbereinigung auf eine fehlende lokale Datei zeigen.

### SwiftData / CloudKit Migration

- Modelle vermeiden Unique Constraints und nutzen Defaults; das ist CloudKit-kompatibel.
- Neue nicht-optionale Felder ohne Defaults würden Migration/CloudKit-Modell brechen.
- Many-to-many `Book` <-> `BookCollection` ist optional und wird manuell über Helper gepflegt; Drift bleibt ein Risiko bei direkter Mutation.
- `CollectionMembershipRepair` läuft einmal pro Store-Scope. Spätere Bugs nach gesetztem Repair-Flag werden nicht automatisch erneut repariert.

### Multi-Device / Sync

- Keine explizite app-level Dedupe-Strategie für logisch gleiche Books mit unterschiedlichen UUIDs gefunden.
- Keine Unique Constraints wegen CloudKit; Duplikate müssen fachlich behandelt werden.
- CloudKit-Konfliktregeln bei parallelen Edits an Tags, Notes, Ratings und Collections sind **UNKNOWN**.
- `SyncDiagnostics` kann lokale Saves zeigen, aber keinen Abschluss der CloudKit-Replikation.

### Offline

- Offline-Lokalsaves werden in Diagnostics gezählt.
- Exakte Wiederanlauf- und Konfliktauflösung hängt an SwiftData/CloudKit und ist im App-Code nicht sichtbar.
- Remote-Cover-Fetches können fehlschlagen; Disk/Memory-Cache mindert das, aber Failure-Caching ist nicht sichtbar.

### Live Activity / Timer

- Stop/Pause aus der Extension kommuniziert über App-Group-Defaults.
- Pending Completion muss später in der App in eine `ReadingSession` überführt werden.
- Auto-Stop nach Inaktivität ist per AppStorage steuerbar, Standard 45 Minuten.
- Edge Case: Gerät stoppt Session über Live Activity, App bleibt lange geschlossen, Challenge/Stats aktualisieren sich erst beim späteren Persistieren der Session.

### Secrets / Configuration

- `Shelf Notes/config/secrets.xcconfig` war im ZIP enthalten und enthält einen Google-Books-Key. Der Wert ist in dieser Dokumentation nicht wiedergegeben.
- `.gitignore` ignoriert diese Datei, aber ZIP-/Backup-Prozesse können sie trotzdem enthalten.
- Rotation des Keys ist ratsam, falls das ZIP außerhalb eines sicheren Kontexts geteilt wurde.

### Build / Plattform

- `IPHONEOS_DEPLOYMENT_TARGET = 26.0` ist im Projekt gesetzt.
- **UNKNOWN**: Ob iOS 26 absichtlich ist. Falls nicht, schränkt das Test- und Nutzerbasis stark ein.
- UI unterstützt iPhone und iPad über `TARGETED_DEVICE_FAMILY = "1,2"`; konkrete iPad-UX-Qualität ist **UNKNOWN**.

### Template / Dead Code

- `ShelfNotesLiveActivity/ShelfNotesLiveActivityBundle.swift` inkludiert nur `ShelfNotesLiveActivityLiveActivity()`.
- `ShelfNotesLiveActivity/ShelfNotesLiveActivity.swift` und `ShelfNotesLiveActivity/ShelfNotesLiveActivityControl.swift` sehen nach Template-/Beispielresten aus.
- `ShelfNotesLiveActivity/ShelfNotesLiveActivityControl.swift` enthält einen Platzhalterzustand `isRunning = true`.
- Risiko entsteht, falls diese Widgets später versehentlich in das Bundle aufgenommen werden.

---

## Observability / Debuggability

### Vorhanden

- `Shelf Notes/ModelContext+Diagnostics.swift`
  - `saveWithDiagnostics()` zeichnet lokale Saves mit Quelle auf.
- `Shelf Notes/SyncDiagnostics.swift`
  - Beobachtet Netzwerkstatus über `NWPathMonitor`.
  - Prüft iCloud Account Status und UserRecordID über CloudKit.
  - Speichert letzte lokale Save-Zeit, Fehler, Quelle und Offline-Save-Anzahl.
  - Erzeugt Diagnosebericht mit App-, Device-, System-, Netzwerk-, iCloud- und Save-Infos.
- `Shelf Notes/SyncDiagnosticsView.swift`
  - UI-Zugang in Settings.
- `Shelf NotesTests/`
  - Gute Abdeckung für viele pure Builder und Mutationen, darunter LibraryDerivedState, Tags, Stats, Challenges, CSV und Collections.

### Lücken

- Kein direkter CloudKit-Progress oder CloudKit-Operation-Log sichtbar.
- Kein strukturierter Performance-Trace für Library-Search, Stats-Compute, Cover-Backfill oder Challenge-Refresh sichtbar.
- Kein einheitliches Event-Log für Migrationen, Repairs und Backfills sichtbar.
- Keine im Scan erkennbare UI-Performance- oder Large-Library-Test-Fixture.

### Empfehlungen

- `SyncDiagnostics` erweitern um:
  - letzte Migration/Repair mit Erfolg, Dauer und Count.
  - Cover-Backfill: pending, processed, failed, saved.
  - Challenge refresh: Dauer und Anzahl aktiver Records.
- Debug-only Performance-Marker ergänzen:
  - Library derived state compute duration.
  - Stats snapshot duration.
  - Heatmap duration.
  - Tags index duration.
- Repro-Szenarien als Tests oder Debug-Menü dokumentieren:
  - 1.000 Bücher mit Tags, Sessions und Covers.
  - Offline Save, danach CloudKit-Start.
  - Local-only Start, danach CloudKit-Start.
  - Zweitgerät ohne Full-res User-Cover.
  - Live Activity Stop, App später öffnen.

---

## Open Questions

- **UNKNOWN**: Ist `IPHONEOS_DEPLOYMENT_TARGET = 26.0` absichtlich?
- **UNKNOWN**: Was ist die erwartete maximale Bibliotheksgröße?
- **UNKNOWN**: Soll Local-only-Datenbestand in CloudKit importierbar sein?
- **UNKNOWN**: Gibt es fachliche Dedupe-Regeln für gleiche Bücher ohne Unique Constraint?
- **UNKNOWN**: Welche CloudKit-Konfliktstrategie gilt für parallele Edits an Notes, Tags, Ratings und Collections?
- **UNKNOWN**: Sollen Full-res User-Cover künftig synchronisiert werden oder bleibt Thumbnail-only die Produktentscheidung?
- **UNKNOWN**: Wie groß darf `Book.userCoverData` maximal werden, bevor CloudKit-Payload oder Speicher ein Problem wird?
- **UNKNOWN**: Gibt es Production-Store-Snapshots für SwiftData-Migrationstests?
- **UNKNOWN**: Ist die Live-Activity-Control-Datei bewusst nicht im Bundle enthalten oder nur Template-Rest?
- **UNKNOWN**: Welche Release-Diagnostik darf Support erhalten, ohne sensible Nutzerdaten offenzulegen?
- **UNKNOWN**: Sind Share- oder Collaboration-Features geplant?
- **UNKNOWN**: Welche Geräteklasse ist Performance-Baseline?

---

## First 3 Refactors I would do

### P0.1: Persistence Bootstrap aus `AppContainerHostView.swift` splitten

Ziel:

- Sync-/Store-Policy isolieren und testbarer machen.
- UI für Startfehler von SwiftData/CloudKit-Konfiguration trennen.

Betroffene Dateien:

- `Shelf Notes/AppContainerHostView.swift`
- Neu: `Shelf Notes/Persistence/StorageMode.swift`
- Neu: `Shelf Notes/Persistence/ModelContainerFactory.swift`
- Neu: `Shelf Notes/Persistence/AppBootstrapper.swift`
- Neu: `Shelf Notes/AppBootstrap/ModelContainerFailureView.swift`
- Neu: `Shelf Notes/AppBootstrap/LocalOnlyBanner.swift`

Risiko:

- Niedrig bis mittel. Funktional sollte sich nichts ändern, aber Bootstrap ist App-kritisch. Manuelle Tests für CloudKit, Local-only und In-memory sind nötig.

Erwarteter Nutzen:

- Klarere Architektur für das wichtigste Risiko im Projekt: SwiftData/CloudKit-Start, Store-Separation und Migration.
- Bessere Grundlage für Tests und künftige Store-Policy-Änderungen.

### P0.2: Library Display Store einführen und Body-nahe O(n)-Arbeit entfernen

Ziel:

- `LibraryView` soll im Body keine Dictionaries und Signaturen über alle Bücher bauen.
- Search, Sort, Filter und Alpha-Sektionen sollen als gecachter Display-State bereitstehen.

Betroffene Dateien:

- `Shelf Notes/LibraryView/LibraryView.swift`
- `Shelf Notes/LibraryView/LibraryDerivedState.swift`
- `Shelf Notes/LibraryView/LibraryDerivedStateBuilder.swift`
- `Shelf Notes/LibraryView/LibraryView+Grid.swift`
- `Shelf Notes/LibraryView/LibraryView+Lists.swift`
- Optional: `Shelf Notes/TagsView/TagsIndexStore.swift`
- Neu: `Shelf Notes/LibraryView/LibraryDisplayStore.swift`
- Neu: `Shelf Notes/LibraryView/LibraryBooksIndex.swift`

Risiko:

- Mittel. Library ist Hauptscreen; Fehler betreffen Suche, Sortierung, Counts, A-Z-Index, Bulk Selection und Navigation.

Erwarteter Nutzen:

- Weniger SwiftUI-Invalidationskosten.
- Bessere Scroll- und Search-Performance bei großen Bibliotheken.
- Klarer Testpunkt für Library-Derived-State.

### P0.3: Cover Pipeline vereinheitlichen und persistierende Side Effects aus generischen Cover-Views entfernen

Ziel:

- Ein gemeinsamer Weg für Decode, Cache, Remote-Fetch, URL-Resolution und synced thumbnail writes.
- `BookCoverThumbnailView` nicht mehr synchron in `body` dekodieren lassen.
- Persistierende Aktionen nur über explizite Services ausführen.

Betroffene Dateien:

- `Shelf Notes/CoverThumbnailer/CoverThumbnailer.swift`
- `Shelf Notes/CoverThumbnailer/CoverThumbnailer+Backfill.swift`
- `Shelf Notes/CoverThumbnailer/CoverThumbnailer+RemoteFetch.swift`
- `Shelf Notes/CoverThumbnailer/CoverThumbnailer+Apply.swift`
- `Shelf Notes/CoverImageLoader.swift`
- `Shelf Notes/CachedAsyncImage.swift`
- `Shelf Notes/LibraryView/LibraryRowCoverView.swift`
- `Shelf Notes/ImageViews/SyncedThumbnailImage.swift`
- Neu: `Shelf Notes/Cover/CoverRenderPolicy.swift`
- Neu: `Shelf Notes/Cover/CoverImageRepository.swift`
- Neu: `Shelf Notes/Cover/CoverBackfillService.swift`

Risiko:

- Mittel. Cover betreffen Library, Detail, Import und CloudKit-Payload. Regressionen sind sichtbar, aber gut manuell testbar.

Erwarteter Nutzen:

- Weniger MainActor-Arbeit im Renderpfad.
- Weniger doppelte Netzwerk-/Decode-Arbeit.
- Kontrolliertere CloudKit-Saves durch Thumbnail-Refresh.
- Sauberere Multi-Device-Story für Thumbnail vs Full-res Cover.
