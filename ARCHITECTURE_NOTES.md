# ARCHITECTURE_NOTES.md

Stand: E-Book-Erweiterung PR 9 vom 2026-07-18 auf Basis des aktuellen Projektarchivs. Aussagen beziehen sich auf den geprüften Codebestand. Unklare Punkte sind als **UNKNOWN** markiert.

## Scope und Methode

## PR 9 Architekturergänzung

- `ShelfNotesShareExtension` ist ein neues, CloudKit-freies Share-Extension-Target. Es besitzt eigene Entitlements, eine eigene `Info.plist` mit Share-Extension-Point und eingeschränkten Activation Rules für URL- und Textinhalte.
- Die Extension schreibt nur in eine versionierte App-Group-Inbox. Sie importiert keine SwiftData-Modelle, öffnet keine Netzwerkverbindungen, speichert keine Credentials und startet keine Provider-Autorisierung.
- `Shelf Notes/Shared/Sharing` enthält die gemeinsam genutzten DTOs und Pure-Funktionen: `ReadingSharePayload`, `ReadingSharePayloadKind`, `ReadingShareInboxItem`, `ReadingShareInboxCodec`, `ReadingShareInboxStore`, `ReadingSharePayloadParser`, `ReadingShareURLClassifier` und Textnormalisierung.
- Die URL-Sicherheitsgrenze für Shares liegt zentral in `ReadingShareURLClassifier`: nur HTTPS mit öffentlichen Hosts wird akzeptiert. Apple Books, Kindle/Amazon, Google Books und generische HTTPS-Buchlinks werden klassifiziert; private Schemes, localhost und private IPs werden abgelehnt.
- Die Haupt-App konsumiert die Inbox über `ReadingShareInboxProcessor` und `ReadingShareInboxView`. Einträge werden erst nach erfolgreichem Speichern oder bewusstem Verwerfen gelöscht. Beschädigte Inbox-Dateien werden nicht blind gelöscht, sondern können in eine Recovery-Datei verschoben werden.
- Matching ist bewusst konservativ: bestehende `BookExternalReference` und eindeutige ISBN-Treffer sind sichere Matches; Titelkandidaten bleiben unsicher und verlangen Nutzerbestätigung. Kanonische URLs werden nur nach Bestätigung als `BookExternalReference` ergänzt.
- Shares erzeugen ausschließlich `ReadingAnnotation` mit `origin == .shareExtension`. Sie erzeugen keine `ReadingSession`, keine Lesezeit, keinen Lesetag, keinen Streak und keinen Provider-Sync. Unterschiedliche Highlights desselben Buchs bleiben erhalten; derselbe Inbox-Eintrag wird über Inhaltsfingerprint und Annotation-Dedup-Key nicht doppelt gespeichert.
- PR 9 erweitert die Integrations-Capabilities ehrlich um `canReceiveShares` für Apple Books, Kindle, Google Books und Other. Google Books bleibt trotzdem nicht verbunden und bietet weiterhin kein OAuth oder Kontosync an.

## PR 8 Architekturergänzung

- Die neue Integrationsschicht liegt unter `Shelf Notes/ReadingIntegrations`. Sie trennt Provider-Beschreibung, Fähigkeiten, Verfügbarkeit, Präsentation, Launch-Policy und Companion-Koordination in kleine Dateien.
- `ReadingIntegrationCapabilities` ist ein OptionSet. Die Architektur setzt nicht voraus, dass alle Anbieter dieselben Fähigkeiten besitzen. Apple Books, Kindle und Other haben aktuell `canOpenReadingDestination` und `canReceiveShares`; Google Books kann Shares entgegennehmen, bleibt aber ohne Kontoverbindung, Sync oder Launch-Fähigkeit. Local File erhält keine nicht implementierten Fähigkeiten.
- `ReadingIntegrationRegistry.default` ist die zentrale Quelle für Provider-Konfigurationen. SwiftUI liest daraus Availability- und Capability-State, statt Provider-Fähigkeiten in Views zu duplizieren.
- `ReadingProviderLaunchPolicy` ist der einzige Gatekeeper für externe URLs. Die Policy erlaubt nur HTTPS, prüft öffentliche Hosts und validiert providerbezogene Host-/Pfadfamilien. Ungültige Links werden nicht geöffnet.
- `ReadingIntegrationCoordinator` bildet den Begleitfluss: Timer und Live Activity starten zuerst über den vorhandenen Timer-Pfad; danach wird ein validierter Link geöffnet oder eine nicht-fehlerhafte Anleitung für den manuellen Wechsel in die Reader-App zurückgegeben. Blockierte Links werden als Fehler an die UI gemeldet.
- `BookExternalReference` bleibt der einzige Speicherort für Provider-Identifier und kanonische URLs. PR 8 ergänzt Mapping auf `ReadingProviderLaunchReference` und `BookExternalReferenceFactory` für Google-Books-Importe, aber keine neuen Provider-Felder am `Book`.
- Im Buchdetail rendert `ReadingAttemptSourceControl` eine kompakte Quelle für den aktiven Attempt. Änderungen werden über `ReadingSourceAttemptMutation` nur zugelassen, solange der Attempt keine Sessions oder Progress Events hat und für das Buch kein Timer läuft.
- Die Einstellungen enthalten `ReadingIntegrationsSettingsView`. Sie zeigt Verfügbarkeit, Fortschrittsmodus und aktuell implementierte Fähigkeiten, aber keine Verbunden-Anzeige. OAuth, Kontosync und lokaler Reader bleiben weiterhin außerhalb des aktuellen Stands.
- Tests decken Registry/Capabilities, Verfügbarkeiten, Launch-Policy, URL-Ablehnung, Presentation-State, Companion-Start, fehlende Leselinks, Attempt-Source-Wechsel, unveränderte physische Timer-UX und Share-Inbox-Verarbeitung ab.

## PR 7 Architekturergänzung

- Timer-Source ist ein expliziter Wert-Snapshot. App-State, PendingCompletion, Shared Blobs, Live-Activity-Attribute und Snapshot-Presentation speichern dieselben Source-Felder. Dadurch bleiben externe E-Book-Sessions nach App-Neustart und nach späteren Book-Änderungen stabil.
- Die Hintergrundlogik liegt in `ReadingTimerAutoStopPolicy`. SwiftUI-Views entscheiden nicht selbst über Auto-Stop oder Stale-Date. `ReadingTimerManager+AutoStop` ruft nur diese Policy auf.
- Shared Blob Schema-Versionen wurden auf 3 erhöht. Payloads ohne neue Felder werden als physische Legacy-Sessions decodiert. Payloads mit einer Schema-Version größer als die aktuelle Version werden über die unterstützten Decode-Pfade verworfen.
- Live-Activity-Controls verwenden `LiveActivitySharedStore.togglePauseForActiveSession` und `stopActiveSession`. Die Extension dupliziert damit keine PendingCompletion- oder Source-Mapping-Regeln.
- `ReadingSessionMutationService` kann für Timer-Completions eine persistierte Quelle und einen konkreten Attempt beibehalten. Standardpfade ohne diese Parameter behalten ihr bisheriges Verhalten.

Geprüft wurden:

- Ordnerstruktur und Feature-Module
- App Entry Points
- SwiftData-Modelle und Container-Konfiguration
- CloudKit-/Entitlement-Konfiguration
- Root Navigation, Tabs, Sheets und Startup-Maintenance
- Formatneutrale Fortschrittsberechnung, Reading-Attempt-Isolation, Session-/Import-Mutationen, adaptive Quellen-/Fortschritts-UX, Mixed-Media-Analytics, Timer-/Live-Activity-Source-Snapshots und Legacy-Backfill
- Große Dateien nach Zeilenzahl
- Hot Paths für Rendering, Scroll, Sync, Storage, Concurrency und Caching
- Tests und Testpläne

Nicht durchgeführt:

- Kein Xcode Build in der Linux-Arbeitsumgebung
- Keine Ausführung des vollständigen Xcode-Testplans
- Keine CloudKit-Laufzeitprüfung
- Keine App-Store-/Provisioning-Prüfung

## Big Files List: Top 15 Dateien nach Zeilen

### 1. `Shelf Notes/Stats/StatisticsSnapshotBuilder.swift` - 787 Zeilen

- Baut Statistics-Snapshots, Jahres-/Monatswerte, Top-Listen und Nerd-Metriken.
- Risiko: viele fachliche Regeln, Calendar-Logik und Präsentationsableitungen in einer Datei; Mixed-Media-Seitenregeln müssen zentral bleiben.

### 2. `Shelf Notes/BookDetail/Sessions/SessionsCard.swift` - 659 Zeilen

- Session-Start, Timer, Companion-Start, Quick Log, Source-Auswahl, Listen und Mutationsaufrufe im Buchdetail.
- Risiko: UI-, Sheet-, Timer- und Persistenzpfade liegen weiterhin eng beieinander; PR 8 lagert Provider-Launch-Entscheidungen immerhin in `ReadingIntegrationCoordinator` und `ReadingProviderLaunchPolicy` aus.

### 3. `Shelf Notes/LibraryView/LibraryView.swift` - 643 Zeilen

- Zentraler Library-Screen mit Source-Tracking, Navigation und Dashboard-Einbindung.
- Risiko: großer SwiftUI-Invalidationsbereich und viele Main-Actor-Abhängigkeiten.

### 4. `Shelf Notes/Challenges/ChallengeEngine+Compute.swift` - 528 Zeilen

- Berechnet Challenge-Fortschritt, Baselines und Zeitfenster.
- Risiko: dichte fachliche Logik; Mixed-Media-Anpassung ist bewusst noch nicht Teil von PR 5.

### 5. `Shelf Notes/Challenges/ChallengeTemplateRegistry.swift` - 504 Zeilen

- Definiert Challenge-Templates, Texte, Ziele und Verfügbarkeiten.
- Risiko: viele statische Fälle in einer Datei und enge Kopplung an Challenge-Metriken.

### 6. `Shelf Notes/Stats/StatisticsHeatmapBuilder.swift` - 502 Zeilen

- Baut Tages-/Wochen-Buckets, Streaks und Heatmap-Statistiken.
- Risiko: direkte und aggregierte Pfade müssen bei Zeitzonen, Mitternachtsgrenzen und Provider-Imports identisch bleiben.

### 7. `Shelf Notes/LibraryView/LibraryDerivedState.swift` - 480 Zeilen

- Value-Snapshots, Signaturen und vorbereitete Library-Such-/Fortschrittswerte.
- Risiko: sichtbare Source-, Locator- und Fortschrittsfelder vergrößern die Cache-Signatur; nur UI-relevante Felder dürfen enthalten sein.

### 8. `Shelf Notes/Collections/CollectionsSmartActionBuilder.swift` - 470 Zeilen

- Baut Smart Actions und Empfehlungen für Collections.
- Risiko: UI-nahe Heuristiken, viele Auswahlregeln und mögliche Kosten bei großen Bibliotheken.

### 9. `Shelf Notes/ReadingSessionAggregates.swift` - 463 Zeilen

- Bildet Session-, Tages-, Buch- und Jahresaggregate samt Signaturen.
- Risiko: universelle und seitenbasierte Metriken teilen weiterhin einen großen Builder; späterer Split in Records, Bucketing und Hashing ist sinnvoll.

### 10. `Shelf Notes/Settings/AppearanceSettings/AppearancePreferences.swift` - 440 Zeilen

- Beschreibt Appearance-Optionen und persistierte Darstellungspräferenzen.
- Risiko: globale UI-Auswirkungen und viele Optionen in einer Datei.

### 11. `Shelf Notes/Stats/StatisticsSourceStore.swift` - 438 Zeilen

- Beobachtet Book-/Session-Quellen, verwaltet Signaturen und koordiniert Detached-Compute-Caches.
- Risiko: falsche Signaturen führen zu stale Daten oder unnötigen Neuberechnungen; Actor-Grenzen müssen stabil bleiben.

### 12. `Shelf Notes/LibraryView/LibraryView+Header.swift` - 437 Zeilen

- Header, Filter, Suche, Sortierung und Library-Steuerung.
- Risiko: viele Controls hängen am zentralen Library-State und können breite Re-Renders auslösen.

### 13. `Shelf Notes/BookDetail/BookDetailView+Cards.swift` - 435 Zeilen

- Enthält mehrere Karten und Abschnitte der Buchdetailansicht.
- Risiko: große SwiftUI-Datei mit hoher Invalidationsfläche und vielen Book-Abhängigkeiten.

### 14. `Shelf Notes/LibraryView/LibraryView+Grid.swift` - 418 Zeilen

- Grid-/List-Darstellung der Bibliothek und Fortschritts-Cues.
- Risiko: Scroll-Hotpath; Cover, Navigation und adaptive Progress-Darstellung müssen günstig bleiben.

### 15. `Shelf Notes/Widgets/LibraryWidgetSnapshotBuilder.swift` - 417 Zeilen

- Baut lokale Value-Snapshots für das Bibliothekswidget.
- Risiko: Widget-Mixed-Media-Semantik ist noch nicht Teil von PR 5 und darf nicht versehentlich von App-internen Contracts abweichen.

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

### Mixed-Media Derived States und Analytics

Betroffene Dateien:

- `Shelf Notes/ReadingMetrics/ReadingMetricEligibility.swift`
- `Shelf Notes/ReadingMetrics/ReadingMetricContribution.swift`
- `Shelf Notes/ReadingMetrics/ReadingSessionMetricMapper.swift`
- `Shelf Notes/ReadingMetrics/ReadingProgressMetricMapper.swift`
- `Shelf Notes/ReadingSessionAggregates.swift`
- `Shelf Notes/Analytics/ReadingAnalyticsInputMapper.swift`
- `Shelf Notes/Analytics/ReadingAnalyticsIndexBuilder.swift`
- `Shelf Notes/Analytics/ReadingAnalyticsValueTypes.swift`
- `Shelf Notes/Analytics/ReadingCompletionRecord.swift`
- `Shelf Notes/Stats/*`
- `Shelf Notes/Goals/*`
- `Shelf Notes/ProgressHub/*`
- `Shelf Notes/Timeline/*`
- `Shelf Notes/LibraryView/*`

Architekturentscheidung:

- Metrikberechtigung wird nicht nach konkreten Providern verzweigt. `ReadingMetricEligibility` entscheidet zentral anhand von Datenquelle, `ReadingProgressUnit` und `ReadingSessionOrigin`.
- `ReadingSessionMetricMapper` bildet Session-Snapshots in universelle Session-/Zeit-/Lesetagsbeiträge und optional addierbare Seitenbeiträge ab. Prozent- und Locator-Sessions zählen als echte Sessions, tragen aber keine Seiten bei.
- `ReadingProgressMetricMapper` bildet Einzelbuch-Fortschritt und Abschlüsse ab. Ein Provider-Import kann damit einen belastbaren Fortschritt oder Abschluss liefern, erzeugt aber weder Session, Lesezeit, Lesetag noch Streak.
- `ReadingSessionAggregateSnapshot` hält `totalSeconds` und `pageBasedSeconds` getrennt. Durchschnittliche Sessiondauer verwendet alle echten Sessions; Seiten pro Stunde verwendet ausschließlich die Zeitbasis seitenbasierter Sessions.
- `ReadingCompletionRecord` speichert Medium, Provider und Fortschrittseinheit eines historischen Attempts. Die `pageCount` wird nur für `.pages` übernommen. Alle Einheiten zählen als Abschluss, aber nur seitenbasierte Abschlüsse fließen in Seitenstatistiken und Seitendiagramme ein.
- Der aktive `ReadingAttempt` steuert weiterhin den aktuellen Library-Fortschritt. Frühere abgeschlossene Attempts bleiben unabhängig davon in Timeline, Goals und Statistics erhalten.
- SwiftData-Objekte werden am Main Actor in kleine `Sendable`-Records und Snapshots überführt. `ReadingAnalyticsIndexBuilder`, `StatisticsComputePipeline`, `StatisticsHeatmapBuilder` und `ReadingTimelineBuilder` arbeiten anschließend value-basiert und können außerhalb des Main Actors laufen.

Cache- und Signaturregeln:

- Statistics-Book-Signaturen berücksichtigen die Progress Unit der Attempts, aber weder Provider, Medium noch Locator, weil diese Felder globale Statistikwerte nicht verändern.
- Statistics-Session-Signaturen berücksichtigen Progress Unit und Origin, weil beide die Metrikberechtigung beeinflussen.
- Goals berücksichtigen Abschlussdaten, Page Snapshot und Progress Unit. Provider- oder Medium-Wechsel ohne Metrikänderung invalidieren die Zielberechnung nicht.
- Timeline und Library berücksichtigen Medium und Provider, weil diese Informationen sichtbar dargestellt werden. Library berücksichtigt zusätzlich den Locator, weil er Teil des sichtbaren Einzelbuch-Fortschritts ist.

Fachliche Invarianten:

- Sessionanzahl, Lesezeit, Lesetage, Streak und durchschnittliche Sessiondauer sind medienübergreifend und stammen nur aus echten Sessions.
- Seiten, verbleibende Seiten, Seiten pro Stunde und Seitendiagramme stammen ausschließlich aus `.pages`-Daten.
- Prozentwerte verschiedener Bücher werden niemals summiert. Locator werden nicht als Seiten oder Prozente interpretiert.
- `providerImport` erzeugt keine Sessionwirkung. Ein defensiv falsch persistierter Provider-Import als Session wird von den Metrik-Mappern ebenfalls ausgeschlossen.
- Ein aktiver Reread übernimmt weder Seiten noch Prozentstände früherer Attempts. Historische Abschlüsse bleiben trotzdem vollständig erhalten.
- Direkte und aggregierte Heatmap-Pfade müssen dieselben Leseminuten und Lesetage liefern, einschließlich Sessions über Mitternacht.

Risiken und Tradeoffs:

- `ReadingSessionAggregates.swift` bleibt ein wachsender Hotspot. Die neue Kompatibilitätsschicht reduziert fachliche Duplikation, der Builder sollte später dennoch in Records, Bucketing und Signaturbildung aufgeteilt werden.
- Seitenstatistiken sind bei gemischten Bibliotheken bewusst partielle Kennzahlen. UI-Texte kennzeichnen dies dezent; eine globale Prozentleistung wäre fachlich irreführend.
- Locator- oder reine Provider-Metadatenänderungen invalidieren globale Statistiken absichtlich nicht. Ändert ein späterer Provider daraus abgeleitete Metriksemantik, muss die jeweilige Signatur gezielt erweitert werden.
- Challenge Engine und Bibliothekswidget sind seit PR 6 Mixed-Media-fähig. Die Reading-Session-Live-Activity verwendet weiterhin ihren bewusst seitenbasierten Legacy-Contract und bleibt ein separater Ausbau.

### Stufe-1-Abschluss: Challenges und Widget-Snapshots

Betroffene Dateien:

- `Shelf Notes/ReadingMetrics/ReadingProgressIncreaseDetector.swift`
- `Shelf Notes/Challenges/ChallengeEngine+Snapshot.swift`
- `Shelf Notes/Challenges/ChallengeEngine+Compute.swift`
- `Shelf Notes/Challenges/ChallengeSessionImpactBuilder.swift`
- `Shelf Notes/Challenges/ChallengeActionHintBuilder.swift`
- `Shelf Notes/Challenges/ChallengeRefreshPipeline.swift`
- `Shelf Notes/Widgets/LibraryWidgetSnapshotInputMapper.swift`
- `Shelf Notes/Widgets/LibraryWidgetSnapshotBuilder.swift`
- `Shelf Notes/Shared/Widgets/LibraryWidgetSnapshot.swift`
- `Shelf Notes/Shared/Widgets/LibraryWidgetSnapshotPresentation.swift`
- `ShelfNotesLiveActivity/LibraryOverviewWidget/*`

Architekturentscheidung:

- Challenge-Snapshots sind weiterhin kleine `Sendable`-Werte. SwiftData-Sessions und reine Provider-Progress-Events werden am Main Actor eingelesen; `ChallengeEngine+Compute` arbeitet danach SwiftData-frei.
- Sessionmetriken greifen auf `ReadingSessionMetricMapper` zurück. Dadurch zählen echte Sessions medienübergreifend für Zeit, Sessionanzahl und Lesetage, während `providerImport` diese Metriken nicht beeinflusst.
- `booksProgressed` basiert nicht auf Provider-Namen. `ReadingProgressIncreaseDetector` vergleicht je Progress Unit nur belastbare Werte: absolute Seiten, normalisierte Prozentstände und ausschließlich explizit normalisierte Locator-Werte.
- Provider-Events werden für Challenge-Zwecke pro Book-/Attempt-Scope und stabilem Deduplizierungsschlüssel kanonisiert. Derselbe externe Sync-Stand kann ein Buch im Zeitraum nicht mehrfach zählen; gleiche Schlüssel verschiedener Bücher werden nicht zusammengeführt.
- Das Widget-DTO wurde ausschließlich um optionale Source-/Progress-Felder ergänzt. Dadurch bleiben bestehende JSON-Payloads kompatibel und der Payload-Zuwachs begrenzt.
- `pageCount`, `pagesRead` und `remainingPages` werden im Widget nur bei `.pages` geschrieben. Prozent und Locator verwenden `progressFraction`, optional `progressNativeValue` beziehungsweise `progressLocator`.
- App und Widget Extension besitzen weiterhin getrennte DTO-Mirror. Änderungen an optionalen Feldern müssen deshalb in beiden Targets parallel erfolgen und über Legacy-Decoding-Tests abgesichert bleiben.

Pages-Read-Audit:

- Bewusst seitenbasiert: `ReadingProgressEngine`, `ReadingProgressMutationPlanner`, Legacy-Repair, Session-Logging-Kompatibilitätsaufrufe und die aktuelle Reading-Session-Live-Activity.
- Zentral abgesichert: Analytics, Statistics, Goals, Progress Hub, Challenges und Widget-Input verwenden `ReadingMetricEligibility`, `ReadingSessionMetricMapper` oder eine explizite `progressUnit == .pages`-Schranke.
- Reine Presentation-/DTO-Felder namens `pagesRead` bleiben aus Rückwärtskompatibilität bestehen, werden für Prozent, Locator und `none` jedoch nicht befüllt.
- CSV bleibt absichtlich unverändert und exportiert weder Source-Metadaten noch Progress Events.

Risiken und Tradeoffs:

- Für einen echten Fortschrittsanstieg durch Provider-Importe benötigt die Challenge Engine den vorherigen belastbaren Stand desselben Attempts. Der Snapshot lädt deshalb Provider-Events vor dem Periodenende und kann bei sehr großen Importhistorien später einen begrenzten Index beziehungsweise eine Baseline-Projektion benötigen.
- `booksProgressed` ist eine Distinct-Book-Metrik. Mehrere echte Anstiege desselben Buchs innerhalb eines Challenge-Zeitraums erhöhen den Wert bewusst nur einmal.
- Die Widget-Schema-Version bleibt bei `1`, weil nur optionale Felder ergänzt wurden. Eine spätere verpflichtende Source-Struktur benötigt eine neue Schema-Version und explizite Migration.
- Die Reading-Session-Live-Activity ist noch nicht formatneutral. E-Book-Sessions dürfen dort keine erfundenen Seiten erzeugen; eine vollwertige Prozent-/Locator-Präsentation folgt separat.

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
- `Shelf Notes/ReadingSessionAggregates.swift`
- `Shelf Notes/ReadingMetrics/ReadingSessionMetricMapper.swift`

Ist-Zustand:

- `StatisticsSourceStore` hält Book- und Session-Quellen getrennt. Leseminuten und Lesetage fordern die Session-Quelle an; Abschluss-Heatmaps benötigen sie nicht.
- `ReadingSessionAggregateBuilder` bildet pro Scope Tages-Buckets sowie Buch- und Jahresaggregate für Sessionanzahl, universelle Dauer, seitenbasierte Dauer, Seiten und aktive Tage.
- `ReadingSessionMetricMapper` entfernt Provider-Imports zentral aus Sessionzeit und Lesetagen. Prozent- und Locator-Sessions bleiben echte Sessions, tragen aber weder Seiten noch seitenbasierte Dauer bei.
- `StatisticsHeatmapBuilder` kann direkte Session-Snapshots oder vorberechnete Aggregate verwenden. Beide Pfade sind für Leseminuten und Lesetage semantisch identisch.
- Seiten pro Stunde wird aus `totalPages / pageBasedSeconds` gebildet und dadurch nicht von Prozent-Sessions verwässert.

Invalidation:

- ReadingSession insert/update/delete.
- Änderung an `startedAt`, `endedAt`, `durationSeconds`, `pagesRead`, `progressUnitRawValue` oder `originRawValue`.
- Änderungen an Provider, Medium, Locator oder Notiz invalidieren die Session-Aggregate nicht, solange sie die Metrikberechtigung nicht verändern.

Wirkung:

- Weniger wiederholte Sorts und Reduces in Stats.
- Konsistente Heatmap- und Progress-Hub-Werte bei gemischten Medien.
- Keine Sessionwirkung durch reine Provider-Imports.

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

### Share Extension

- Share-Capture läuft über `ShelfNotesShareExtension` und den App-Group-Pfad `ReadingShareInbox/inbox-v1.json`.
- Das Target teilt nur SwiftData-freie Share-DTOs mit der App. Alle SwiftData-Schreibvorgänge bleiben in der Haupt-App.
- `shelfnotes://share-inbox` dient als Rücksprung in die App; zusätzlich liest `RootView` die Inbox beim Aktivwerden.

Risiken:

- Host-Apps liefern Shares unterschiedlich als URL, Plain Text oder Webpage. Der Parser muss defensiv bleiben und darf keine privaten URL-Schemes akzeptieren.
- Mehrfaches Teilen desselben Inhalts und App-Neustarts dürfen keine doppelten Annotationen erzeugen.
- Unsichere Titelmatches dürfen nicht automatisch zusammengeführt werden.

Empfehlung:

- Reale Shares aus Apple Books, Kindle, Google Books, Safari und generischen Readern manuell testen.
- Beschädigte App-Group-Dateien und parallele Shares auf Gerät prüfen.

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
