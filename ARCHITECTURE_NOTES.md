# ARCHITECTURE_NOTES.md

Stand: E-Book-Erweiterung PR 4 vom 2026-07-17 auf Basis des aktuellen Projektarchivs. Aussagen beziehen sich auf den geprüften Codebestand. Unklare Punkte sind als **UNKNOWN** markiert.

## Scope und Methode

Geprüft wurden:

- Ordnerstruktur und Feature-Module
- App Entry Points
- SwiftData-Modelle und Container-Konfiguration
- CloudKit-/Entitlement-Konfiguration
- Root Navigation, Tabs, Sheets und Startup-Maintenance
- Formatneutrale Fortschrittsberechnung, Reading-Attempt-Isolation, Session-/Import-Mutationen, adaptive Quellen-/Fortschritts-UX und Legacy-Backfill
- Große Dateien nach Zeilenzahl
- Hot Paths für Rendering, Scroll, Sync, Storage, Concurrency und Caching
- Tests und Testpläne

Nicht durchgeführt:

- Kein Xcode Build in der Linux-Arbeitsumgebung
- Keine Ausführung des vollständigen Xcode-Testplans
- Keine CloudKit-Laufzeitprüfung
- Keine App-Store-/Provisioning-Prüfung

## Big Files List: Top 15 Dateien nach Zeilen

### 1. `Shelf Notes/Stats/StatisticsSnapshotBuilder.swift` - 667 Zeilen

Zweck:

- Baut Statistik-Snapshots für Fortschritt, Jahreswerte, Monatswerte, Top-Listen, Genres und weitere Auswertungen.

Warum riskant:

- Sehr viele fachliche Statistikregeln in einer Datei.
- Date-/Calendar-Logik, Aggregation und Präsentationsableitung liegen eng zusammen.
- Änderungen können viele Statistikbereiche gleichzeitig beeinflussen.
- Hotspot bei großen Libraries, weil Statistiken über viele Bücher und Sessions aggregieren.

### 2. `Shelf Notes/Challenges/ChallengeEngine+Compute.swift` - 521 Zeilen

Zweck:

- Berechnet Challenge-Fortschritt, Baselines, Metriken und Zielerreichung.

Warum riskant:

- Dichte Fachlogik mit vielen Challenge-Metriken.
- Date-Window- und Session-Overlap-Logik ist fehleranfällig.
- Änderungen können Completion, Rewards und Hints beeinflussen.
- Potenzieller Hotspot nach Session-Saves, weil Challenge-Refresh häufig getriggert wird.

### 3. `Shelf Notes/Collections/CollectionsSmartActionBuilder.swift` - 470 Zeilen

Zweck:

- Baut Smart Actions und Empfehlungen für Collections.

Warum riskant:

- UI-nahe Heuristiken und fachliche Auswahlregeln sind in einer großen Datei gekoppelt.
- Hohe Regression-Gefahr bei Änderungen an Collection-Snapshots.
- Performance-Risiko, falls der Builder im Renderpfad großer Collections läuft.

### 4. `Shelf Notes/Stats/StatisticsHeatmapBuilder.swift` - 444 Zeilen

Zweck:

- Baut Heatmap-Daten, Tages-/Wochenwerte und vermutlich Streak-nahe Auswertungen.

Warum riskant:

- Calendar-/Timezone-Logik und Aggregation sind empfindlich.
- Bei vielen Sessions kann tägliche Aggregation teuer werden.
- Muss konsistent mit `StatisticsSnapshotBuilder` bleiben.

### 5. `Shelf Notes/BookDetail/BookDetailView+Cards.swift` - 408 Zeilen

Zweck:

- Enthält mehrere Karten/Abschnitte der Buchdetailansicht.

Warum riskant:

- Große SwiftUI-Datei mit vielen View-Zweigen.
- Bindings, Navigation und Mutationen können indirekt gekoppelt sein.
- Hohe Invalidationsfläche bei Änderungen an `Book`.

### 6. `Shelf Notes/Settings/AppearanceSettings/AppearancePreferences.swift` - 407 Zeilen

Zweck:

- Beschreibt Appearance-Optionen, Darstellungseinstellungen und vermutlich zugehörige Presentation Values.

Warum riskant:

- Globale App-Darstellung hängt an `@AppStorage` in `RootView`.
- Änderungen an Appearance können Root- und Tab-Invalidationen auslösen.
- Viele Optionen in einer Datei erschweren Review.

### 7. `Shelf Notes/TagsView/TagSuggestionEngine.swift` - 402 Zeilen

Zweck:

- Erzeugt Tag-Vorschläge aus Buchdaten, Kategorien, Autor, Titel und vorhandenen Tags.

Warum riskant:

- String-Normalisierung und Heuristiken können leicht Edge Cases erzeugen.
- Performance-Risiko bei großen Bibliotheken, wenn Vorschläge häufig neu gebaut werden.
- Muss konsistent mit Tag-Hygiene und Tag-Mutationen bleiben.

### 8. `Shelf Notes/BookDetail/BookDetailView+Bindings.swift` - 399 Zeilen

Zweck:

- Bindings, State-Ableitungen und Mutationsbrücken für `BookDetailView`.

Warum riskant:

- Viele Speicherpfade und UI-Bindings in einer Datei.
- Änderungen können SwiftData-Saves, Ratings, Status, Dates, Tags und Notizen betreffen.
- Hohe MainActor- und View-Invalidation-Relevanz.

### 9. `Shelf Notes/TagsView/TagHygieneBuilder.swift` - 398 Zeilen

Zweck:

- Ermittelt Tag-Hygiene-Probleme wie Dubletten, Case-Varianten oder Singular/Plural-Kandidaten.

Warum riskant:

- Data-Cleanup-Logik ist fachlich sensibel.
- Falsche Gruppierung kann zu falschen Merge-/Rename-Vorschlägen führen.
- Muss sehr gut getestet bleiben, weil Nutzeraktionen Daten verändern können.

### 10. `Shelf Notes/LibraryView/LibraryView+Header.swift` - 396 Zeilen

Zweck:

- Header, Filter, Such-/Sortiersteuerung und UI-Controls der Bibliothek.

Warum riskant:

- Viele UI-Controls hängen am zentralen Library-Zustand.
- `@AppStorage`, Filter-State und Derived State können viele Re-Renders auslösen.
- Header-Änderungen können den gesamten Library-Screen invalidieren.

### 11. `Shelf Notes/BookDetail/Sessions/SessionsCard.swift` - 385 Zeilen

Zweck:

- Zeigt Lesesessions, Timer-Controls, Session-Aktionen und Challenge-Hints im Buchdetail.

Warum riskant:

- Nutzt eigene Queries und reagiert auf Session-/Challenge-Änderungen.
- UI, Mutation, Notification und Async-Refresh liegen nah beieinander.
- Risiko für wiederholte Challenge-Refreshes und MainActor-Arbeit.

### 12. `Shelf Notes/AddBook/AddBookViewModel.swift` - 385 Zeilen

Zweck:

- ViewModel für Buch-Hinzufügen, Draft State, Such-/Importzustand und Speichern.

Warum riskant:

- Viele `@Published` Zustände können breite UI-Updates erzeugen.
- Netzwerk-, Draft-, Routing- und Persistenzlogik sind wahrscheinlich gekoppelt.
- Hohe Änderungsfrequenz bei Import-UX.

### 13. `Shelf Notes/Stats/StatisticsSourceStore.swift` - 368 Zeilen

Zweck:

- Beobachtet Bücher/Sessions, baut Source-Snapshots und steuert Statistik-Compute-Caches.

Warum riskant:

- `@MainActor` Store mit Observation Tracking.
- Muss SwiftData-Objekte sicher in Value-Snapshots überführen.
- Fehlerhafte Signaturen führen zu stale oder zu häufig neu berechneten Statistiken.

### 14. `Shelf Notes/LibraryView/LibraryView+Grid.swift` - 362 Zeilen

Zweck:

- Grid-/List-Darstellung der Bibliothek.

Warum riskant:

- Scroll-Hotpath.
- Viele Cover-Views, Navigation Links und Cell-Zustände können SwiftUI-Invalidationskosten erhöhen.
- Muss strikt vermeiden, beim Rendern SwiftData zu mutieren.

### 15. `Shelf Notes/TagsView/TagsView.swift` - 358 Zeilen

Zweck:

- Hauptscreen für Tags Dashboard, Suche, Sortierung, Hygiene und Navigation.

Warum riskant:

- Volle Bibliotheksdaten werden für Tag-Indizes genutzt.
- Mehrere Sheets/Flows und Cleanup-Aktionen sind gekoppelt.
- Datenqualität und UI-Performance hängen an denselben Indizes.

## Hot Path Analyse

## Rendering / Scrolling

### Library

Betroffene Dateien:

- `Shelf Notes/LibraryView/LibraryView.swift`
- `Shelf Notes/LibraryView/LibraryBooksIndex.swift`
- `Shelf Notes/LibraryView/LibraryDerivedState.swift`
- `Shelf Notes/LibraryView/LibraryDerivedStateBuilder.swift`
- `Shelf Notes/LibraryView/LibraryDisplayStore.swift`
- `Shelf Notes/LibraryView/LibraryView+Grid.swift`
- `Shelf Notes/ImageViews/LibraryRowCoverView.swift`

Beobachtung:

- `LibraryView` nutzt `@Query(sort: \Book.createdAt, order: .reverse)` und hält damit die Buchliste direkt im Screen.
- `activeBooksIndex` baut aus den `Book`-Objekten einen `LibraryBooksIndex`.
- `LibraryDerivedState` erzeugt Signaturen über viele Book-Felder, darunter Titel, Autor, Status, Tags, Notizen, Lesezeitraum und Ratings.
- `LibraryDerivedStateBuilder` filtert, sortiert und sectioned über Value-Snapshots.
- `LibraryDisplayStore` reduziert direkte Arbeit im `body`, aber die Quelle bleibt eine vollständige `@Query`.

Hotspot-Grund:

- Full-array Fetch in einem zentralen Screen.
- Snapshot-/Index-Aufbau über alle Bücher.
- Suche, Sortierung und Filter können bei großen Libraries teuer werden.
- Breite Invalidierung möglich, wenn globale Appearance-/Library-AppStorage-Werte wechseln.

Positiv:

- Derived State ist bereits testbar ausgelagert.
- Suchtext wird debounced.
- Grid-Cover nutzen scroll-schonende Views.

Empfohlener Hebel:

- `LibraryBooksIndex` nur neu bauen, wenn sich eine Source-Signature geändert hat.
- Search Tokens und normalisierte Felder im Snapshot speichern.
- Sort-/Filter-Ergebnis im `LibraryDisplayStore` stärker memoizen.

### Cover in Listen und Grids

Betroffene Dateien:

- `Shelf Notes/CoverImageLoader.swift`
- `Shelf Notes/CachedAsyncImage.swift`
- `Shelf Notes/ImageCaching/ImageDiskCache.swift`
- `Shelf Notes/ImageCaching/CoverImageRequestDeduper.swift`
- `Shelf Notes/ImageCaching/RemoteCoverFailureCache.swift`
- `Shelf Notes/CoverThumbnailer/CoverThumbnailer.swift`
- `Shelf Notes/ImageViews/LibraryRowCoverView.swift`
- `Shelf Notes/ImageViews/SyncedThumbnailImage.swift`

Beobachtung:

- Remote-Requests werden per normalisierter URL dedupliziert.
- Remote-Fehler werden kurzzeitig gecacht.
- Disk Cache ist lokal und auf 120 MB begrenzt.
- Decoding läuft off-main.
- `SyncedThumbnailImage` downscaled JPEGs via ImageIO off-main und cached im Memory Cache.
- `LibraryRowCoverView` ist explizit read-only und triggert keine SwiftData-Saves im Scrollpfad.
- `BookCoverThumbnailView` kann beim Auflösen einer Remote-URL `book.persistResolvedCoverURL` und Thumbnail-Refresh triggern.

Hotspot-Grund:

- Viele gleichzeitige Cover in Grids/Listen erzeugen I/O, Decoding und Netzwerkdruck.
- Request-Deduping löst nur identische URLs, nicht viele unterschiedliche URLs.
- SwiftData-Mutationen aus Cover-Views können Sync und View-Invalidation anstoßen, wenn diese View in scroll-intensiven Kontexten eingesetzt wird.

Positiv:

- Die Library nutzt eine side-effect-freie Cover-Variante.
- Disk- und Memory-Caches existieren.
- Decoding ist off-main.

Empfohlener Hebel:

- Zusätzlich ein globales Limit für parallele unterschiedliche Remote-Cover-Downloads einführen.
- Sicherstellen, dass in allen Listen/Grid-Kontexten `LibraryRowCoverView` oder eine gleichwertig read-only Variante genutzt wird.
- Cover-Persistenz nur in Detail-/Import-Kontexten erlauben.

### Stats

Betroffene Dateien:

- `Shelf Notes/Stats/StatisticsView.swift`
- `Shelf Notes/Stats/StatisticsSourceStore.swift`
- `Shelf Notes/Stats/StatisticsComputePipeline.swift`
- `Shelf Notes/Stats/StatisticsSnapshotBuilder.swift`
- `Shelf Notes/Stats/StatisticsHeatmapBuilder.swift`

Beobachtung:

- `StatisticsView` liest alle Bücher über `@Query`.
- `StatisticsSourceStore` beobachtet Buch- und Session-Quellen und hält Snapshots/Caches.
- Schwere Berechnungen laufen in `Task.detached(priority: .utility)` über Value-Snapshots.
- Session-Source wird nur bei Bedarf für bestimmte Auswertungen aufgebaut.

Hotspot-Grund:

- Vollständiger Buchbestand wird als Source betrachtet.
- Session-Snapshots über alle relevanten Bücher können bei vielen Sessions teuer werden.
- Observation Tracking kann bei vielen Einzeländerungen mehrfach refreshen.

Positiv:

- Compute Pipeline ist bereits vom MainActor entkoppelt.
- Es gibt Source-Signaturen und Tests.

Empfohlener Hebel:

- Per-Book Session-Aggregate cachen.
- Session-Source strikter nach aktivem Zeitraum und aktiver Statistikansicht laden.
- Observation-Refresh coalescen.

### Tags

Betroffene Dateien:

- `Shelf Notes/TagsView/TagsView.swift`
- `Shelf Notes/TagsView/TagsIndexStore.swift`
- `Shelf Notes/TagsView/TagsIndexBuilder.swift`
- `Shelf Notes/TagsView/TagsDomainIndex.swift`
- `Shelf Notes/TagsView/TagSuggestionEngine.swift`
- `Shelf Notes/TagsView/TagHygieneBuilder.swift`

Beobachtung:

- Tags werden aus dem gesamten Buchbestand abgeleitet.
- Root aktualisiert den `TagsIndexStore` beim Aktivwerden der App und beim Startup.
- Suggestions, Hygiene und Dashboard nutzen verwandte, aber nicht vollständig identische Indizes.

Hotspot-Grund:

- Tag-Indizes wachsen mit Anzahl Bücher und Tags.
- Hygiene-Analysen sind stringlastig und können bei vielen Tags teuer werden.
- Cleanup-Flows haben Datenqualitätsrisiko.

Empfohlener Hebel:

- Einen gemeinsamen `TagsDomainIndex` als Quelle für Dashboard, Suggestions und Hygiene etablieren.
- Index nur bei Tag-relevanter Source-Signature neu bauen.
- Cleanup-Aktionen nach Mutation mit gezielter Index-Invalidation koppeln.

### Sessions im Buchdetail

Betroffene Dateien:

- `Shelf Notes/BookDetail/Sessions/SessionsCard.swift`
- `Shelf Notes/BookDetail/Sessions/ReadingTimerManager/*`
- `Shelf Notes/ReadingSessionChangeNotification.swift`
- `Shelf Notes/Challenges/ChallengeRefreshCoordinator.swift`

Beobachtung:

- `SessionsCard` kombiniert Sessionliste, Timer-UI und Challenge-Hints.
- Nach Session-Mutationen werden Challenge-Refreshes und Notifications ausgelöst.
- Pro Buch ist die Sessionmenge kleiner als global, aber häufige Updates können dennoch mehrere Nebenwirkungen auslösen.

Hotspot-Grund:

- Mutation und UI liegen nah beieinander.
- Notifications können mehrere Screens triggern.
- Challenge-Hints können nach jeder Session neu berechnet werden.

Empfohlener Hebel:

- `SessionsCardViewModel` oder `SessionsCardController` einführen.
- Challenge-Hints coalescen und nur bei relevanter Signature aktualisieren.
- Session-Zusammenfassungen pro Buch cachen.

## Sync / Storage

### Container-Strategie

Betroffene Dateien:

- `Shelf Notes/AppBootstrap/AppBootstrapper.swift`
- `Shelf Notes/AppContainerHostView.swift`
- `Shelf Notes/Persistence/ModelContainerFactory.swift`
- `Shelf Notes/Persistence/StorageMode.swift`

Beobachtung:

- App startet mit CloudKit-Store.
- Bei Fehlern wird nicht gecrasht, sondern eine Failure UI angeboten.
- Local-only und In-Memory sind explizite Modi.
- Local-only nutzt separaten Store und andere Repair-Scope-ID.

Risiko:

- Local-only Daten sind getrennt von CloudKit-Daten.
- Eine spätere automatische Zusammenführung von Local-only nach CloudKit wurde nicht gefunden: **UNKNOWN**.
- Nutzer können unterschiedliche Datenstände je Modus sehen.

Empfehlung:

- Local-only Mode weiterhin deutlich kennzeichnen.
- In Docs und UI klar machen: separater Store, kein automatischer Merge.
- Optional Export-Hinweis im Local-only Mode anbieten.

### CloudKit-Kompatibilität des Modells

Betroffene Dateien:

- `Shelf Notes/BookModel/Book.swift`
- `Shelf Notes/ReadingAttempts/ReadingAttempt.swift`
- `Shelf Notes/ReadingSession.swift`
- `Shelf Notes/ReadingSources/*`
- `Shelf Notes/ReadingGoal.swift`
- `Shelf Notes/BookCollection.swift`
- `Shelf Notes/Challenges/ChallengeModels.swift`

Beobachtung:

- Kommentare im Modell weisen auf CloudKit-Einschränkungen hin.
- IDs sind nicht unique markiert.
- Beziehungen sind optional.
- Defaults sind vorhanden.
- Die Reading-Source-Erweiterung speichert Enums als stabile englische Raw Values und kapselt unbekannte Werte über sichere Fallbacks.
- `Book` bleibt Bibliothekseintrag; `ReadingAttempt` ist der konkrete Anker für Medium, Provider und Fortschrittseinheit.
- `Book.isEbook` bleibt importierte Google-Books-Metainformation und ist nicht mit `ReadingMedium` gekoppelt.
- Neue Book-Beziehungen löschen abhängige Fortschrittsereignisse, externe Referenzen und Annotationen per Cascade nur zusammen mit dem Buch.
- Das Löschen eines `ReadingAttempt` nullifiziert dessen Sessions, Progress Events und Annotationen, damit Historie nicht verloren geht.

Risiko:

- Ohne Unique Constraints sind Dubletten fachlich möglich.
- `deduplicationKey` ist bewusst kein Unique Attribute; Deduplizierung muss in Import- oder Mutation-Services erfolgen.
- Konfliktauflösung zwischen Geräten ist nicht zentral dokumentiert: **UNKNOWN**.
- Merge-Regeln für gleiche ISBN oder gleiche Google Volume ID sind nicht als globale Policy sichtbar: **UNKNOWN**.

Empfehlung:

- Fachliche Duplicate-Detection in Import und Repair klar dokumentieren.
- Optional `BookIdentityIndex` als nicht-persistierten Index einführen.
- Multi-Device-Konfliktfälle gezielt testen.

### Migration und Repair

Betroffene Dateien:

- `Shelf Notes/Persistence/ReadingStatusMigrator.swift`
- `Shelf Notes/CollectionMembershipRepair.swift`
- `Shelf Notes/AppLifecycle/AppStartupMaintenanceService.swift`
- `Shelf Notes/AppLifecycle/AppStartupMaintenanceState.swift`
- `Shelf Notes/ReadingAttempts/ReadingAttemptRepair.swift`
- `Shelf Notes/ReadingProgress/ReadingProgressRepair.swift`
- `Shelf Notes/ReadingProgress/ReadingProgressRepair+Relationships.swift`
- `Shelf Notes/ReadingProgress/ReadingProgressRepair+Baseline.swift`
- `Shelf Notes/ReadingProgress/ReadingProgressRepair+Dedupe.swift`
- `Shelf Notes/AppContainerHostView.swift`

Beobachtung:

- Es gibt konkrete Reparatur-/Migration-Jobs für Status und Collection Membership.
- Cover-Backfill wird beim Startup geplant.
- `ReadingAttemptRepair` stellt zuerst Lesedurchgänge und Session-Zuordnungen her.
- `ReadingProgressRepair` läuft direkt danach und bewusst ohne einmaligen `UserDefaults`-Schalter, damit später eintreffende CloudKit-Legacy-Daten erneut verarbeitet werden.
- Leere Legacy-Source-Felder werden auf `physical`, `none`, `pages` und `legacy` klassifiziert; unbekannte nicht-leere Raw Values bleiben unangetastet.
- Fehlende Book-/Attempt-Beziehungen von Sessions und Progress Events werden anhand vorhandener Beziehungen, Source-Session-IDs und deterministischer Baseline-Keys repariert.
- Pro Reading Attempt wird höchstens ein Baseline-Event mit dem Key `legacy-pages-baseline:<attempt-id>` geführt. Neue Legacy-Sessions aktualisieren dieses Event idempotent.
- Exakte Event-Dubletten werden nur bei stabiler Identität entfernt. Semantisch unterschiedliche Nutzerereignisse bleiben erhalten.
- Eine zentrale Modellversions- oder Migration-Policy wurde nicht gefunden.

Risiko:

- SwiftData/CloudKit-Schemaänderungen sind besonders sensibel.
- Unkoordinierte Modelländerungen können CloudKit-Sync oder bestehende Stores beschädigen.
- Der Repair ist absichtlich wiederholbar und läuft bei jedem App-Start. Sein Fetch- und Vergleichsaufwand wächst damit mit Bibliothek, Sessions und Progress Events.

Empfehlung:

- `MIGRATIONS.md` einführen.
- Jede Modelländerung mit Migration/Repair/Backfill-Plan dokumentieren.
- Tests für Migration-Helfer ergänzen.
- Bei wachsendem Eventvolumen Repair-Laufzeit und Speicherdruck beobachten; erst dann gezielt indexieren oder in sichere Batches teilen.

### Formatneutrales Reading-Source-Fundament

Betroffene Dateien:

- `Shelf Notes/ReadingSources/ReadingMedium.swift`
- `Shelf Notes/ReadingSources/ReadingProvider.swift`
- `Shelf Notes/ReadingSources/ReadingProgressUnit.swift`
- `Shelf Notes/ReadingSources/ReadingSessionOrigin.swift`
- `Shelf Notes/ReadingSources/ReadingAnnotationKind.swift`
- `Shelf Notes/ReadingSources/ReadingProgressEvent.swift`
- `Shelf Notes/ReadingSources/BookExternalReference.swift`
- `Shelf Notes/ReadingSources/ReadingAnnotation.swift`
- `Shelf Notes/ReadingAttempts/ReadingAttempt.swift`
- `Shelf Notes/ReadingSession.swift`
- `Shelf Notes/ReadingProgress/*`

Architekturentscheidung:

- Persistiert werden Strings mit stabilen englischen Raw Values, nicht Swift-Enums direkt als SwiftData-Attribute.
- Typisierte Computed Properties bilden unbekannte Raw Values auf sichere Defaults ab.
- Bestehende Reading Attempts migrieren semantisch auf `physical`, `none` und `pages`.
- Bestehende Reading Sessions migrieren semantisch auf `physical`, `none`, `legacy` und `pages`.
- `ReadingProgressEvent` speichert native Fortschrittswerte und optional normalisierte Werte. Die Ableitung erfolgt zentral über die formatneutrale Engine.
- `BookExternalReference` trennt Bibliotheksmetadaten von provider-spezifischen Identifikatoren.
- `ReadingAnnotation` hält Highlights, Notizen und Lesezeichen providerunabhängig.
- Tokens, Zugangsdaten und lokale Dateipfade gehören ausdrücklich nicht in SwiftData oder CloudKit.

Noch nicht Teil dieser Stufe:

- Keine Provider-API und kein Token-Handling
- Keine lokale EPUB-/PDF-Dateiverwaltung
- Kein Readium und kein integrierter Reader
- Keine neue Oberfläche
- Keine konkrete Provider-Integration; vorhanden ist nur ein providerneutraler Progress-Import-Mutationspfad
- Kein großer Umbau bestehender UI-Callsites

### Formatneutrale Fortschritts-Engine

Betroffene Dateien:

- `Shelf Notes/ReadingProgress/ReadingProgressUpdate.swift`
- `Shelf Notes/ReadingProgress/ReadingProgressSnapshot.swift`
- `Shelf Notes/ReadingProgress/ReadingProgressAttemptSnapshot.swift`
- `Shelf Notes/ReadingProgress/ReadingProgressEngine.swift`
- `Shelf Notes/ReadingProgress/ReadingAttempt+Progress.swift`
- `Shelf Notes/BookModel/Book+ReadingProgress.swift`
- `Shelf Notes/BookDetail/Sessions/ReadingSessionLogging.swift`
- `Shelf Notes/Widgets/LibraryWidgetSnapshotInputMapper.swift`

Architekturentscheidung:

- Die eigentliche Berechnung arbeitet ausschließlich auf `Sendable` Value-Snapshots. SwiftData-Modelle werden nur in schmalen Adaptern in diese Werte überführt.
- Jeder Engine-Aufruf betrachtet genau einen Reading Attempt. Sessions und Events mit explizit abweichender Attempt-ID werden ausgeschlossen.
- Seitenfortschritt summiert nur positive Session-Seiten. Die Gesamtzahl wird aus `pageCountSnapshot`, einem belastbaren ganzzahligen Total-Snapshot oder einem passenden Seiten-Update gewählt.
- Prozentfortschritt verwendet den neuesten gültigen absoluten Stand. Bei identischen Zeitpunkten entscheidet ein stabiler Identifier deterministisch.
- Ein expliziter normalisierter Prozentwert hat Vorrang. Fehlt er, wird ein nicht-negativer nativer Wert gegen einen belastbaren Totalwert oder fachlich gegen 100 normalisiert, ohne Seitenwerte zu erzeugen.
- Locator werden getrimmt, aber nicht interpretiert. Ein normalisierter Fortschritt entsteht nur aus einem explizit gespeicherten Wert.
- Fehlende Messwerte bleiben `nil`. Damit können Sessions nur Zeit und Notizen enthalten, ohne fälschlich null Prozent zu behaupten.
- Ein abgeschlossener Attempt wird unabhängig von der Einheit als vollständig behandelt.
- `Book+ReadingProgress` erhält bestehende Aufrufer und Status-Semantik. Ein aktiver Reread übernimmt keinen Fortschritt früherer Attempts; ein bereits als finished markiertes Book bleibt für bestehende Anzeigen vollständig.
- `ReadingSessionLogging` delegiert seine bisherigen Seiten-Helfer an die Engine. Das Widget verwendet für Seitenfortschritt die bereits vorhandene Attempt-Selektion.

Risiken und Tradeoffs:

- Der 100er-Fallback bei prozentbasierten nativen Werten ist eine fachliche Konvention für Prozentangaben, kein erfundener Gesamtwert; `snapshot.totalValue` bleibt dabei `nil`.
- Gleich datierte Events benötigen dauerhaft stabile Identifier, damit die deterministische Auswahl geräteübergreifend reproduzierbar bleibt.
- Baseline-Events sind abgeleitete Legacy-Artefakte. Zukünftige Schreibpfade müssen echte Nutzer- oder Provider-Events weiterhin getrennt persistieren.
- Prozent- und Locator-Fortschritt werden über den gemeinsamen adaptiven Editor erfasst. Bestehende Seiten-Aufrufer bleiben als Kompatibilitätspfad erhalten.

### Formatneutrale Session- und Progress-Mutationen

Betroffene Dateien:

- `Shelf Notes/BookDetail/Sessions/ReadingSessionContext.swift`
- `Shelf Notes/BookDetail/Sessions/ReadingSessionLogging.swift`
- `Shelf Notes/BookDetail/Sessions/ReadingSessionMutationModels.swift`
- `Shelf Notes/BookDetail/Sessions/ReadingSessionMutationService.swift`
- `Shelf Notes/BookDetail/Sessions/ReadingSessionDeletionService.swift`
- `Shelf Notes/ReadingProgress/ReadingProgressMutationModels.swift`
- `Shelf Notes/ReadingProgress/ReadingProgressMutationPlanning.swift`
- `Shelf Notes/ReadingProgress/ReadingProgressEventMutationService.swift`
- `Shelf Notes/ReadingProgress/ReadingProgressImportMutationService.swift`
- `Shelf Notes/ReadingProgress/ReadingProgressEventFingerprint.swift`
- `Shelf Notes/ReadingAttempts/ReadingAttemptSessionCoordinator.swift`

Architekturentscheidung:

- `ReadingSessionSource` ist der providerneutrale Eingabewert für Medium, Provider, Fortschrittseinheit, Origin und optionalen Gesamtwert. `ReadingSessionContext` verbindet diese Quelle mit dem tatsächlich verwendeten `ReadingAttempt`.
- `ReadingSessionLogging` plant nicht mehr ausschließlich `pages: Int?`, sondern ein optionales `ReadingProgressUpdate`. Der alte Seitenaufruf bleibt als dünner Kompatibilitätsadapter bestehen.
- `ReadingProgressMutationPlanner` trennt reine Validierung und Berechnung von SwiftData. Unterstützt werden positive Seitendifferenzen, absolute Prozentstände, native Locator mit optionalem Normalized Progress, explizite Abschlüsse und Sessions ohne Fortschritt.
- Standardmutationen dürfen einen bekannten absoluten Fortschritt nicht reduzieren. Ein niedrigerer Stand ist nur über `ReadingProgressMutationMode.correction` zulässig.
- Seitenmutationen bleiben Differenzen in `ReadingSession.pagesRead`; das zugehörige `ReadingProgressEvent` speichert den daraus resultierenden absoluten Stand. Prozent- und Locator-Updates werden als absolute Beobachtungen persistiert.
- `ReadingSessionMutationService` mutiert Session, Progress Event, Reading Attempt und Book vor genau einem `ModelContext.saveWithDiagnostics()`-Aufruf. Der Event-Key `session-progress:<session-id>` und `sourceSessionID` garantieren ein idempotentes Re-Save derselben Session.
- `ReadingProgressImportMutationService` speichert reine, deduplizierte Progress Events ohne `ReadingSession`. Es entstehen weder Lesezeit noch Session-basierter Lesetag; `Book.readFrom` und `readTo` bleiben unverändert.
- Konkrete Provider-Clients sind nicht Teil dieser Stufe. Der Importdienst akzeptiert providerneutrale Requests und kann später von Google Books oder weiteren Adaptern aufgerufen werden.
- `ReadingSessionDeletionService` ist der einzige UI-nahe Löschpfad für Sessions. Er entfernt zuerst alle über `sourceSessionID` oder den Session-Key gebundenen Progress Events und speichert anschließend Session- und Event-Löschung gemeinsam.
- Quick Log und Timer verwenden denselben `ReadingProgressInputBuilder` und dieselbe Mutationsschicht; Unterschiede bestehen nur in Dauerquelle und Origin `.quickLog` beziehungsweise `.timer`.

Fachliche Invarianten:

- Ein aktiver Reread verwendet ausschließlich Sessions und Events seines aktiven Attempts.
- Ein Seitenupdate darf die verbleibenden Seiten nicht überschreiten. Ein Legacy-Supplement eines abgeschlossenen Books bleibt weiterhin zulässig und verändert den historischen Lesezeitraum nicht.
- Locator werden gespeichert, aber nicht interpretiert. Fehlt ein belastbarer normalisierter Stand, bleibt er unbekannt.
- Ein normales Prozent- oder Locator-Update ohne neuen Normalized Progress darf einen bereits bekannten Stand nicht versehentlich auf `nil` oder einen niedrigeren Wert zurücksetzen.
- 100 Prozent, letzte Seite oder expliziter Abschluss beendet den aktiven Attempt und setzt das Book auf `finished`.

Risiken und Tradeoffs:

- Session- und Import-Upserts laden aktuell Progress Events zur robusten Deduplizierung aus dem `ModelContext`. Das ist korrekt und CloudKit-tolerant, kann bei sehr großen Eventmengen aber ein späterer Performance-Hotspot werden.
- `sourceSessionID` ist absichtlich nur eine UUID und keine zweite SwiftData-Beziehung. Dadurch bleibt das Schema einfacher, die referenzielle Bereinigung muss jedoch zentral im Löschservice erhalten bleiben.
- Ein fehlgeschlagener Save lässt wie bei bestehenden Mutationsdiensten Änderungen im aktuellen `ModelContext` zurück. Der persistente Store bleibt atomar, die UI sollte den Fehler anzeigen und gegebenenfalls den Context neu laden.
- Die adaptiven Eingabeoberflächen sind bewusst manuell. Sie behaupten weder Provider-Synchronisierung noch einen bereits verfügbaren lokalen Reader.

### Einheitliche Reading-Source- und Progress-Experience

Betroffene Dateien:

- `Shelf Notes/ReadingSources/ReadingSourceSelection.swift`
- `Shelf Notes/ReadingSources/ReadingSourceDraft.swift`
- `Shelf Notes/ReadingSources/ReadingSourceAttemptMutation.swift`
- `Shelf Notes/BookDetail/Sessions/ReadingSourceSelectionSheet.swift`
- `Shelf Notes/BookDetail/Sessions/ProgressInput/*`
- `Shelf Notes/BookDetail/Sessions/Presentation/*`
- `Shelf Notes/BookDetail/Sessions/QuickSessionLogSheet.swift`
- `Shelf Notes/TimerSessionCompletionSheet.swift`
- `Shelf Notes/BookDetail/Sessions/ReReadStartSheet.swift`
- `Shelf Notes/BookDetail/Sessions/ReadingProgressView.swift`
- `Shelf Notes/BookDetail/Sessions/ReadingJourneyCard.swift`
- `Shelf Notes/BookDetail/Sessions/SessionRow.swift`
- `Shelf Notes/BookDetail/Sessions/AllSessionsListSheet.swift`

Architekturentscheidung:

- `ReadingSourceSelection` ist reine UI-Domäne und mappt deterministisch auf persistierte `ReadingMedium`, `ReadingProvider` und `ReadingProgressUnit`. `Book.isEbook` bleibt davon strikt getrennt.
- Externe E-Book-Quellen sind manuell getrackt. Es gibt keine Kontoverknüpfung, automatische Synchronisierung oder privaten URL-Schemes.
- `localFile` ist ein ehrlicher Placeholder: sichtbar zur Orientierung, aber deaktiviert, solange kein integrierter EPUB-/PDF-Reader existiert.
- Die Quellenwahl wird vor der ersten Session am aktiven `ReadingAttempt` gespeichert. Nach der ersten Session oder dem ersten Progress Event bleibt die Attempt-Quelle unverändert. Ein Reread erzeugt einen neuen Attempt und verändert abgeschlossene Attempts nicht.
- `ReadingProgressInputState` enthält ausschließlich editierbaren UI-Zustand. `ReadingProgressInputBuilder` wandelt ihn pure in `ReadingProgressUpdate` und `ReadingProgressMutationMode` um; fachliche Grenzwerte validiert weiterhin `ReadingProgressMutationPlanner`.
- Quick Log und Timer teilen denselben Editor und Builder. Views duplizieren weder Seitenbegrenzung noch Rückschrittsvalidierung.
- `ReadingProgressPresentationBuilder` entscheidet ausschließlich nach Fortschrittseinheit. Seitenwerte werden niemals aus Prozent- oder Locator-Daten abgeleitet.
- Session- und Journey-Präsentationen lesen die auf Session beziehungsweise Attempt gespeicherten Source-Snapshots. Damit bleibt die historische Anzeige stabil, auch wenn Metadaten des Books später geändert werden.

UX-Invarianten:

- Leere Fortschrittsangaben bleiben zulässig; Dauer und Notiz können allein gespeichert werden.
- Ein bekannter absoluter Prozentstand darf nur nach sichtbarer Bestätigung reduziert werden.
- Locator werden unverändert gespeichert und nicht interpretiert. Ohne expliziten Prozentwert bleibt der Prozentfortschritt unbekannt.
- Physische Legacy-Attempts funktionieren weiterhin ohne Quellen-Dialog mit Seitenfortschritt.
- Der neue Attempt eines Wiederholungsdurchgangs erhält eine eigene Quelle; frühere Durchgänge bleiben unverändert.

Risiken und Tradeoffs:

- Der lokale Reader ist bereits als deaktivierte Auswahl sichtbar. Texte und Availability müssen beim späteren Readium-PR gemeinsam umgestellt werden, damit kein widersprüchlicher Zustand entsteht.
- Die Quellenänderung ist vor der ersten Session erlaubt. Bei späteren automatischen Imports muss dieselbe Sperre auch Progress Events berücksichtigen, damit die Attempt-Semantik stabil bleibt.
- Provider-spezifische Locator-Formate bleiben opaque Strings. Eine spätere Reader-Integration benötigt einen versionierten Locator-Contract, statt bestehende Strings nachträglich heuristisch zu interpretieren.

### Secrets und Konfiguration

Betroffene Dateien:

- `Shelf Notes/config/base.xcconfig`
- `Shelf Notes/config/secrets.xcconfig`
- `Shelf Notes/.gitignore`
- `Shelf Notes/Info.plist`

Beobachtung:

- `Info.plist` liest `GOOGLE_BOOKS_API_KEY` aus Build Settings.
- `base.xcconfig` inkludiert `secrets.xcconfig`.
- `.gitignore` schließt `config/secrets.xcconfig` aus.
- Das bereitgestellte ZIP enthält trotzdem eine `secrets.xcconfig` mit einem echten Key im Klartext.

Risiko:

- Key-Leak über ZIP, Backup oder historisches Git ist möglich.
- Ob der Key in Google Cloud eingeschränkt ist, ist **UNKNOWN**.

Empfehlung:

- Key rotieren, falls das ZIP geteilt wurde.
- Key in Google Cloud auf Bundle ID/API einschränken.
- Optional `secrets.template.xcconfig` ohne echten Key committen.

## Concurrency

### Projektweite Actor-Isolation

Betroffene Datei:

- `Shelf Notes.xcodeproj/project.pbxproj`

Beobachtung:

- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` ist gesetzt.
- Viele UI-nahe Stores und ViewModels sind `@MainActor`.

Risiko:

- MainActor-Arbeit ist leichter korrekt, aber Performance-kritischer.
- Heavy Builder dürfen nicht versehentlich wieder in den MainActor-Renderepfad wandern.

Empfehlung:

- Rechenintensive Builder strikt mit Value-Snapshots und `Task.detached` ausführen.
- MainActor-Funktionen kurz halten.
- Signposts für MainActor-Hotpaths ergänzen.

### Task Lifetimes

Betroffene Dateien:

- `Shelf Notes/BookImport/BookImportView/BookImportViewModel+Tasks.swift`
- `Shelf Notes/LibraryView/LibraryView.swift`
- `Shelf Notes/Challenges/ChallengesView.swift`
- `Shelf Notes/BookDetail/Sessions/SessionsCard.swift`
- `Shelf Notes/ImageCaching/CoverImageRequestDeduper.swift`
- `Shelf Notes/CoverImageLoader.swift`

Beobachtung:

- Book Import nutzt Debounce, Generation Guards und Cancellation.
- Library-Suche nutzt eine Debounce-Task.
- Challenge-Refresh wird über Tasks nach Notifications und View-Lifecycle ausgelöst.
- Cover-Deduper hält geteilte Tasks pro URL.

Risiko:

- Unstrukturierte Tasks können länger laufen als die View.
- Deduper-Tasks sind für geteilte Loads sinnvoll, aber brauchen saubere Completion-Entfernung.
- Mehrere Session-Notifications können Challenge-Refreshes stapeln.

Empfehlung:

- Challenge-Refresh-Coalescer als Actor oder `@MainActor` Coordinator einführen.
- Import-Patterns als Standard für neue Netzwerkflows dokumentieren.
- Cover-Deduper zusätzlich mit globaler Remote-Concurrency-Begrenzung kombinieren.

## Refactor Map

## Konkrete Splits

### `StatisticsSnapshotBuilder.swift`

Ziel:

- Statistikregeln isolieren und testbarer machen.

Vorschlag:

- `StatisticsYearOptionsBuilder.swift`
- `StatisticsMonthlySeriesBuilder.swift`
- `StatisticsTopListsBuilder.swift`
- `StatisticsGenreDistributionBuilder.swift`
- `StatisticsNerdStatsBuilder.swift`
- `StatisticsSnapshotFormatting.swift`

Risiko:

- Niedrig bis mittel, wenn Tests grün bleiben.
- Gefahr liegt vor allem in identischer Sortier- und Rundungslogik.

### `ChallengeEngine+Compute.swift`

Ziel:

- Challenge-Metriken, Baselines und Auswahlpolitik trennen.

Vorschlag:

- `ChallengeMetricProgressCalculator.swift`
- `ChallengeBaselineCalculator.swift`
- `ChallengeDateWindowMath.swift`
- `ChallengeCompletionEvaluator.swift`
- `ChallengeTargetPolicy.swift`

Risiko:

- Mittel.
- Challenge-Completion und Rewards dürfen sich nicht sichtbar ändern.

### `BookDetailView+Cards.swift`

Ziel:

- Buchdetail-UI wartbarer und mit weniger Invalidationsfläche strukturieren.

Vorschlag:

- `BookDetailStatusCard.swift`
- `BookDetailMetadataCard.swift`
- `BookDetailRatingCard.swift`
- `BookDetailTagsCard.swift`
- `BookDetailCollectionsCard.swift`
- `BookDetailNotesCard.swift`

Risiko:

- Niedrig bis mittel.
- Hauptgefahr sind versehentlich veränderte Bindings oder Animationen.

### `BookDetailView+Bindings.swift`

Ziel:

- Mutationen klarer und zentraler machen.

Vorschlag:

- `BookDetailDraftBindings.swift`
- `BookDetailRatingBindings.swift`
- `BookDetailStatusMutations.swift`
- `BookDetailDateRangePolicy.swift`

Risiko:

- Mittel.
- Statuswechsel haben Seiteneffekte auf Dates und Ratings.

### `SessionsCard.swift`

Ziel:

- UI, Mutation, Timer und Challenge-Hints entkoppeln.

Vorschlag:

- `SessionsCardViewModel.swift`
- `SessionsSummaryBuilder.swift`
- `SessionsPreviewList.swift`
- `SessionTimerControls.swift`
- `SessionChallengeHintController.swift`

Risiko:

- Mittel.
- Timer- und Live-Activity-Verhalten muss unverändert bleiben.

### `AddBookViewModel.swift`

Ziel:

- Draft, Routing, Import-Mapping und Persistenz trennen.

Vorschlag:

- `AddBookDraft.swift`
- `AddBookDraftMapper.swift`
- `AddBookSaveService.swift`
- `AddBookRoutingState.swift`
- `AddBookDuplicatePolicy.swift`

Risiko:

- Mittel.
- Import- und manuelle Anlage dürfen keine Felder verlieren.

### `TagsView.swift` und Tag Builder

Ziel:

- Tags-Domain-Index als zentrale Quelle etablieren.

Vorschlag:

- `TagsDashboardScene.swift`
- `TagsHygieneScene.swift`
- `TagsNavigationState.swift`
- `TagsDomainIndexStore.swift`

Risiko:

- Mittel.
- Cleanup-Flows müssen exakt bestätigt und reversibel nachvollziehbar bleiben.

### `CollectionsSmartActionBuilder.swift`

Ziel:

- Smart Actions nach Intent und Datenquelle splitten.

Vorschlag:

- `CollectionSmartActionModels.swift`
- `CollectionSmartActionRules.swift`
- `CollectionSmartActionRanker.swift`
- `CollectionSmartActionPresentationBuilder.swift`

Risiko:

- Niedrig bis mittel.
- Gefahr liegt in geänderter Reihenfolge oder fehlenden Actions.

## Cache- und Index-Ideen

### Library Source Index

Betroffene Dateien:

- `Shelf Notes/LibraryView/LibraryView.swift`
- `Shelf Notes/LibraryView/LibraryBooksIndex.swift`
- `Shelf Notes/LibraryView/LibraryDerivedState.swift`
- `Shelf Notes/LibraryView/LibraryDisplayStore.swift`

Idee:

- `LibraryBooksIndex` nur neu berechnen, wenn eine `LibrarySourceSignature` sich ändert.
- Normalisierte Suchfelder pro BookSnapshot cachen:
  - lowercased title
  - lowercased author
  - normalized tags
  - note-presence flag
  - rating average bucket

Invalidation:

- Änderung an titel-/autor-/tag-/status-/rating-/date-/note-relevanten Feldern.
- Änderung an globalem Sort-/Filter-State.

Erwarteter Effekt:

- Weniger MainActor-Arbeit bei großen Libraries.
- Stabilere Scroll-Performance.

### Stats Session Aggregates

Betroffene Dateien:

- `Shelf Notes/Stats/StatisticsSourceStore.swift`
- `Shelf Notes/Stats/StatisticsSnapshotBuilder.swift`
- `Shelf Notes/Stats/StatisticsHeatmapBuilder.swift`

Idee:

- Pro Buch und Jahr Session-Aggregate bilden:
  - Minuten
  - Seiten
  - Session Count
  - aktive Tage
  - Notizen Count
- Für Heatmap zusätzlich Tages-Buckets cachen.

Invalidation:

- ReadingSession insert/update/delete.
- Änderung an `startedAt`, `endedAt`, `durationSeconds`, `pagesRead`, `note`.

Erwarteter Effekt:

- Weniger wiederholte Sorts und Reduces in Stats.
- Schnellere Heatmap und Monatsauswertung.

### Challenge Refresh Coalescing

Betroffene Dateien:

- `Shelf Notes/Challenges/ChallengeRefreshCoordinator.swift`
- `Shelf Notes/Challenges/ChallengeEngine.swift`
- `Shelf Notes/BookDetail/Sessions/SessionsCard.swift`
- `Shelf Notes/Challenges/ChallengesView.swift`

Idee:

- Refresh-Anfragen innerhalb eines kurzen Fensters bündeln.
- Aktive Challenge-Snapshot-Signatur wiederverwenden.
- Unterschiedliche Gründe protokollieren, aber nur einmal compute ausführen.

Invalidation:

- Session-Mutation.
- Statuswechsel zu `finished`.
- Rating-/Notizänderungen, falls aktive Challenge-Metrik betroffen ist.
- Periodenwechsel.

Erwarteter Effekt:

- Weniger SwiftData-Fetches und Challenge-Computes nach Session-Saves.

### Cover Network Concurrency

Betroffene Dateien:

- `Shelf Notes/CoverImageLoader.swift`
- `Shelf Notes/ImageCaching/CoverImageRequestDeduper.swift`
- `Shelf Notes/ImageCaching/ImageDiskCache.swift`

Idee:

- Bestehendes Deduping pro URL behalten.
- Zusätzlich globale Obergrenze für parallele unterschiedliche Remote-URLs einführen.
- Disk-Cache-Pruning optional im Batch oder nach Schwellenwert statt nach jedem Store.

Invalidation:

- Keine fachliche Invalidation, nur Cache-Verhalten.

Erwarteter Effekt:

- Besseres Verhalten bei schlechter Verbindung und großen Grids.
- Weniger I/O-Spikes.

## Vereinheitlichungen

### Mutation Services

Ist-Zustand:

- Session-Erstellung, sessiongebundene Progress Events und Session-Löschung sind über `ReadingSessionMutationService`, `ReadingProgressEventMutationService` und `ReadingSessionDeletionService` zentralisiert.
- Reine Fortschrittsimporte besitzen mit `ReadingProgressImportMutationService` einen eigenen Pfad ohne Session-Side-Effects.
- Andere Buch-, Collection- und allgemeine Detailmutationen liegen weiterhin teilweise in Views, Bindings, Sheets und einzelnen Helpern verteilt.

Vorschlag:

- `BookMutationService`
- `ReadingSessionMutationService` ist vorhanden
- `ReadingProgressImportMutationService` ist vorhanden
- `ReadingSessionDeletionService` ist vorhanden
- `CollectionMutationService`
- `TagMutationService` existiert fachlich bereits teilweise über `TagLibraryMutation`

Nutzen:

- Einheitliche Saves mit Diagnose.
- Weniger versehentliche Side Effects in Views.
- Bessere Testbarkeit.

### Repository / Store Pattern

Problem:

- Viele Views nutzen direkte `@Query` und bauen eigene Derived State.

Vorschlag:

- UI-nahe Stores pro Hotpath, keine große globale Repository-Schicht erzwingen.
- Kandidaten:
  - `LibrarySourceStore`
  - `StatsSourceStore` existiert bereits
  - `TagsDomainIndexStore`
  - `ChallengeSourceStore`

Nutzen:

- Weniger SwiftUI-Body-Arbeit.
- Explizite Signaturen und Invalidation.

### Logging

Problem:

- Diagnose existiert für Sync, aber Performance- und Feature-Logs sind nicht als einheitliches Pattern sichtbar.

Vorschlag:

- `os.Logger` Kategorien:
  - `storage`
  - `sync`
  - `covers`
  - `import`
  - `library`
  - `stats`
  - `challenges`
  - `tags`

Nutzen:

- Bessere Reproduktion von Sync-/Performance-Problemen.
- Weniger Debug-Print-Wildwuchs.

## Risiken & Edge Cases

### Datenverlust / Divergente Stores

- Local-only Store ist getrennt vom CloudKit Store.
- Automatischer Merge Local-only nach CloudKit ist **UNKNOWN**.
- Nutzer könnten im Fallback-Modus Daten erfassen und später im CloudKit-Modus andere Daten sehen.

Empfehlung:

- Export-Hinweis im Local-only Banner.
- Debug-Anzeige für aktiven `StorageMode`.
- Dokumentierte Wiederherstellungsstrategie.

### CloudKit und SwiftData Schema

- Keine Unique Constraints bedeutet fachliche Dubletten sind möglich.
- Optionale Beziehungen schützen CloudKit-Kompatibilität, erhöhen aber Nil-Handling-Aufwand.
- Migration Strategy ist **UNKNOWN**.
- Die neuen Reading-Source-Felder sind additiv und besitzen Defaults. Der reale CloudKit-Schema-Rollout auf Produktionsdaten bleibt dennoch ein manueller Testpunkt.
- Externe IDs und Deduplizierungsschlüssel dürfen nicht als Unique Attribute modelliert werden; Konflikte und Doppelimporte müssen fachlich behandelt werden.

Empfehlung:

- Modelländerungen nur mit Migration-Notiz.
- Multi-Device-Testfälle für neue Beziehungen.
- Duplicate Policy für ISBN/Google Volume ID dokumentieren.

### Offline und Multi-Device

- SwiftData/CloudKit synchronisiert im Hintergrund.
- Sync-Fortschritt ist laut Code nicht detailliert verfügbar.
- `SyncDiagnostics` zeigt iCloud Account, User Record, Netzwerkstatus, lokale Saves und Offline-Save-Counter.

Risiken:

- Nutzer kann Sync-Verzögerung mit Datenverlust verwechseln.
- Konflikte bei gleichzeitiger Bearbeitung auf mehreren Geräten sind **UNKNOWN**.

Empfehlung:

- Sync-Diagnose um “letzter lokaler Save” und “aktiver Store” prominent halten.
- Konfliktfälle manuell testen:
  - gleicher Book-Edit auf zwei Geräten
  - Session auf Gerät A, Statuswechsel auf Gerät B
  - Tag-Rename während Buch auf anderem Gerät bearbeitet wird

### Cover-Daten

- `userCoverData` ist synced/externalStorage.
- Full-res User Cover liegt lokal im App Group Container.
- Remote Cover Cache ist lokal und darf gelöscht werden.

Risiken:

- Auf Zweitgerät ist eventuell nur Thumbnail verfügbar.
- Große synced Thumbnails könnten CloudKit-Payloads belasten.
- Remote-URL-Änderungen können unnötige Thumbnail-Refreshes auslösen.

Empfehlung:

- Thumbnail-Größe hart begrenzen und testen.
- Full-res als bewusst lokales Feature dokumentieren.
- Cover-Refresh nur außerhalb des Scrollpfads persistieren.

### Live Activity

- Live Activity Support ist per `NSSupportsLiveActivities = true` aktiviert.
- Shared-Typen liegen unter `Shelf Notes/Shared/LiveActivity`.
- Extension nutzt App Group für Timer-State, Pending Completion und kleine Cover-Thumbnails.
- App-seitig baut `ReadingSessionLiveActivitySnapshotBuilder` die Darstellungsdaten. Die Extension rendert nur Shared-/Presentation-Werte und importiert keine SwiftData-App-Domain.
- `ReadingSessionLiveActivityCoordinator` hält eine aktive Reading Live Activity, setzt `staleDate`, prüft Activity Authorization und räumt verwaiste Cover auf.

Risiken:

- Live Activity und Reading Timer müssen bei App-Lifecycle-Events konsistent bleiben.
- App-Group-State muss defensiv decodiert werden, damit alte oder korrupte Daten keine Intent-Fehler auslösen.

Empfehlung:

- Timer-Ende, App-Kill, Geräte-Neustart, fehlende Cover-Datei und mehrfaches Stop/Pause aus der Live Activity als Edge Cases testen.

### StoreKit / Pro

- StoreKit-Konfigurationsdatei: `Shelf Notes/unlimited_collections.storekit`.
- `ProManager` wird root-level als Environment Object injiziert.

Risiken:

- Produktionsprodukt-IDs, Restore-Flow und App-Store-Konfiguration wurden nicht verifiziert: **UNKNOWN**.

Empfehlung:

- StoreKit Tests und manuelle Sandbox-Checkliste dokumentieren.

### Secrets

- Google-Books-Key liegt im ZIP im Klartext.
- `.gitignore` schließt die Datei aus, aber Repository-Historie ist **UNKNOWN**.

Empfehlung:

- Key rotieren, falls das ZIP geteilt wurde.
- `secrets.template.xcconfig` einführen.
- CI/Build-Doku ergänzen.

## Observability / Debuggability

### Vorhanden

- `Shelf Notes/SyncDiagnostics.swift`
  - iCloud Account Status
  - User Record Short ID
  - Netzwerkstatus über `NWPathMonitor`
  - letzter lokaler Save
  - Offline-Save-Counter
  - Diagnose-Report
- `Shelf Notes/SyncDiagnosticsView.swift`
  - UI für Sync-Diagnose.
- `Shelf Notes/ModelContext+Diagnostics.swift`
  - zeichnet erfolgreiche und fehlgeschlagene Saves auf.
- `Shelf Notes/ReadingSessionChangeNotification.swift`
  - signalisiert Session-Änderungen an andere Bereiche.
- `Shelf Notes/ImageCaching/ImageDiskCache.swift`
  - liefert Cache-Größe als Byte/String.
- Tests:
  - Library: `LibraryDerivedStateBuilderTests`, `LibraryDisplayStoreTests`, `LibraryBooksIndexTests`
  - Stats: `StatisticsSnapshotBuilderTests`, `StatisticsSourceStoreTests`, `StatisticsComputePipelineTests`
  - Challenges: mehrere `Challenge*Tests`
  - Tags: mehrere `Tag*Tests`
  - Collections: mehrere `Collection*Tests`
  - Covers: `CoverImageCachingPerformanceTests`, `CoverPipelineSplitTests`

### Lücken

- Keine zentrale Logging-Konvention sichtbar.
- Keine Performance-Signposts sichtbar.
- Keine zentrale Migration-Historie sichtbar.
- Testplan `Shelf Notes.xctestplan` enthält keine Testtargets.
- CloudKit Runtime-Fortschritt bleibt durch SwiftData limitiert.

### Empfohlene Ergänzungen

- `os.Logger` Wrapper:
  - `ShelfLogger.storage`
  - `ShelfLogger.sync`
  - `ShelfLogger.covers`
  - `ShelfLogger.stats`
  - `ShelfLogger.challenges`
  - `ShelfLogger.import`
- Signposts für:
  - Library Derived State rebuild
  - Stats Source refresh
  - Stats Compute pipeline
  - Challenge refresh
  - Cover remote load
  - Cover disk prune
- Debug-Screen-Erweiterung:
  - aktiver `StorageMode`
  - SwiftData store URL ohne persönliche Pfade im Export
  - Cover disk usage
  - letzte Challenge refresh duration
  - letzte Stats compute duration
- Reproduktions-Checklisten:
  - iCloud ausloggen
  - Offline speichern
  - große Library importieren
  - 500+ Sessions erzeugen
  - Cover-Cache löschen

## Open Questions

- Ist iOS 26.0 als Deployment Target fachlich bewusst gesetzt oder nur aktueller Xcode-Stand? **UNKNOWN**.
- Gibt es eine verbindliche SwiftData-Migrationsstrategie für zukünftige Modelländerungen? **UNKNOWN**.
- Wie werden `deduplicationKey`-Kollisionen und konkurrierende Provider-Imports geräteübergreifend aufgelöst? **UNKNOWN**.
- Welche Locator-Formate werden je Provider und für lokale EPUB/PDF-Dateien verbindlich unterstützt? **UNKNOWN**.
- Soll Local-only jemals zurück in CloudKit migriert werden können? **UNKNOWN**.
- Wie sollen Dubletten über ISBN, Google Volume ID und Titel/Autor global behandelt werden? **UNKNOWN**.
- Welche Konfliktauflösung wird bei Multi-Device-Edits fachlich erwartet? **UNKNOWN**.
- Ist der Google-Books-Key in Google Cloud auf Bundle/API eingeschränkt? **UNKNOWN**.
- Wurde der im ZIP enthaltene Key jemals committed oder extern geteilt? **UNKNOWN**.
- Sind Produktions-Entitlements für Push/Live Activities final konfiguriert? **UNKNOWN**.
- Welche Live-Activity-Daten werden exakt persistiert oder über App Group geteilt? **UNKNOWN**.
- Gibt es eine App-Store-Privacy-Dokumentation jenseits von `PrivacyInfo.xcprivacy`? **UNKNOWN**.
- Soll die Extension Zugriff auf SwiftData haben oder ausschließlich App-Group-State lesen? **UNKNOWN**.
- Gibt es geplante Share-/Collaboration-Funktionen jenseits von CloudKit Private Database? **UNKNOWN**.
- Sind Performance-Zielwerte definiert, zum Beispiel maximale Library-Größe oder maximale Sessions? **UNKNOWN**.
- Welcher Testplan ist der kanonische Plan für lokale Entwicklung und CI? **UNKNOWN**.

## First 3 Refactors I would do (P0)

### P0.1 Library Source Index kontrolliert invalidieren

Ziel:

- Full-library Snapshot-/Index-Arbeit aus dem SwiftUI-Renderpfad weiter reduzieren.
- `LibraryBooksIndex` nur neu bauen, wenn sich die relevante Source-Signature ändert.

Betroffene Dateien:

- `Shelf Notes/LibraryView/LibraryView.swift`
- `Shelf Notes/LibraryView/LibraryBooksIndex.swift`
- `Shelf Notes/LibraryView/LibraryDerivedState.swift`
- `Shelf Notes/LibraryView/LibraryDerivedStateBuilder.swift`
- `Shelf Notes/LibraryView/LibraryDisplayStore.swift`
- `Shelf NotesTests/LibraryBooksIndexTests.swift`
- `Shelf NotesTests/LibraryDerivedStateBuilderTests.swift`
- `Shelf NotesTests/LibraryDisplayStoreTests.swift`

Risiko:

- Mittel.
- Hauptgefahr ist stale UI, wenn die Signature ein Feld vergisst.
- Such-, Sortier- und Filterverhalten muss exakt gleich bleiben.

Erwarteter Effekt:

- Weniger MainActor-Arbeit bei großen Libraries.
- Stabileres Scrollen und schnellere Filterwechsel.
- Bessere Grundlage für spätere Fetch-Limits oder Pagination.

### P0.2 Challenge Refresh coalescen und Snapshot-Reuse einführen

Ziel:

- Mehrere Session-/Statusänderungen in kurzer Zeit zu einem Challenge-Refresh bündeln.
- Wiederholte Fetch-/Compute-Runden nach Session-Saves vermeiden.

Betroffene Dateien:

- `Shelf Notes/Challenges/ChallengeRefreshCoordinator.swift`
- `Shelf Notes/Challenges/ChallengeEngine.swift`
- `Shelf Notes/Challenges/ChallengeEngine+Snapshot.swift`
- `Shelf Notes/Challenges/ChallengeEngine+Compute.swift`
- `Shelf Notes/Challenges/ChallengesView.swift`
- `Shelf Notes/BookDetail/Sessions/SessionsCard.swift`
- `Shelf Notes/ReadingSessionChangeNotification.swift`
- `Shelf NotesTests/ChallengeSummarySignatureTests.swift`
- `Shelf NotesTests/ChallengeTemplateProgressTests.swift`

Risiko:

- Mittel.
- Zu aggressives Debouncing kann sichtbaren Challenge-Fortschritt verzögern.
- Periodenwechsel und Completion müssen sofort korrekt bleiben.

Erwarteter Effekt:

- Weniger SwiftData-Fetches nach Session-Mutationen.
- Weniger MainActor-Contention im Buchdetail.
- Stabilere Challenge-Hints und weniger doppelte Refresh-Arbeit.

### P0.3 Secrets-, Migration- und Testplan-Guardrails einziehen

Ziel:

- Projekt sicherer und wartbarer machen, bevor weitere Modell-/Sync-Änderungen kommen.
- Secrets sauber trennen, Migrationen dokumentieren, Testplan eindeutig machen.

Betroffene Dateien:

- `Shelf Notes/config/base.xcconfig`
- `Shelf Notes/config/secrets.xcconfig`
- `Shelf Notes/.gitignore`
- `Shelf Notes/Info.plist`
- `Shelf Notes/Persistence/ModelContainerFactory.swift`
- `Shelf Notes.xctestplan`
- `ShelfNotesAppTests.xctestplan`
- Neue Datei: `MIGRATIONS.md`
- Neue Datei: `Shelf Notes/config/secrets.template.xcconfig`

Risiko:

- Niedrig bis mittel.
- Key-Rotation und lokale Dev-Setups müssen sauber kommuniziert werden.
- Testplan-Änderungen können Xcode-Scheme-Verhalten berühren.

Erwarteter Effekt:

- Weniger Sicherheitsrisiko durch Klartext-Keys.
- Schnellere Onboarding- und Debug-Zeit.
- Geringeres Risiko bei zukünftigen SwiftData/CloudKit-Modelländerungen.
