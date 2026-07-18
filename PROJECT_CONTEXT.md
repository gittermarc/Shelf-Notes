# PROJECT_CONTEXT.md

Stand: E-Book-Erweiterung PR 8 vom 2026-07-18 auf Basis des aktuellen Projektarchivs. Stufe 2 ergänzt eine capability-basierte Integrationsarchitektur und den Companion-Startfluss für externe Reader-Apps. Der aktuelle Code ist die Quelle der Wahrheit.

## TL;DR

Shelf Notes ist eine SwiftUI-App für iOS/iPadOS zur Verwaltung einer persönlichen Buchbibliothek mit Lesestatus, Lesesessions, Zielen, Challenges, Statistiken, Tags, Listen/Sammlungen, CSV-Import/-Export, Google-Books-Import, Cover-Caching und Live-Activity-Unterstützung. Das Persistenzmodell, die Session-UX, zentrale Derived States, Challenges und das Bibliothekswidget sind formatneutral für physische Bücher und manuell getrackte externe E-Books. Eine zentrale value-basierte Fortschritts-Engine berechnet Seiten-, Prozent- und Locator-Fortschritt pro `ReadingAttempt`; ein idempotenter Startup-Repair klassifiziert Legacy-Daten und pflegt stabile Baseline-Events nach. Die Mixed-Media-Kompatibilitätsschicht trennt universelle Session-/Zeit-/Abschlussmetriken von ausschließlich addierbaren Seitenmetriken. Prozentstände bleiben Einzelbuch-Fortschritt und werden nie bibliotheksweit summiert; reine Provider-Imports erzeugen weder Sessionzeit, Session, Lesetag noch Streak. Quick Log und Timer nutzen denselben adaptiven Fortschrittseditor und dieselbe Mutationslogik. PR 8 ergänzt eine ehrliche capability-basierte Integrationsschicht: Apple Books, Kindle und Other starten als Companion-Integrationen den Timer plus Live Activity und öffnen nur validierte HTTPS-/Universal-Leselinks; ohne Link bleibt der Timer aktiv und die UI zeigt eine kurze Anleitung. Google Books ist als später erweiterbare, noch nicht verbundene Integration sichtbar. Local File bleibt bis zum echten lokalen Reader deaktiviert. Kontosynchronisierung, OAuth, Share Extension, automatische Fortschrittssynchronisierung und lokaler EPUB-/PDF-Reader sind weiterhin nicht Teil des aktuellen Stands. Persistenz läuft über SwiftData; die primäre Store-Konfiguration nutzt CloudKit über `ModelConfiguration(cloudKitDatabase: .automatic)`. Das Deployment Target ist laut `Shelf Notes.xcodeproj/project.pbxproj` iOS 26.0.

## Key Concepts / Domänenbegriffe

## PR 8 Integrations- und Companion-Kontext

- `Shelf Notes/ReadingIntegrations/*` kapselt Provider-Fähigkeiten als Werttypen. `ReadingIntegrationCapabilities` beschreibt unabhängig voneinander, ob ein Anbieter Leselinks öffnen, Shares empfangen, Bibliotheken importieren, Fortschritt synchronisieren, lokal lesen oder Autorisierung benötigen kann. Die Registry setzt nur Fähigkeiten, die im aktuellen Stand wirklich nutzbar sind.
- `ReadingIntegrationRegistry.default` enthält Apple Books, Kindle und Other als Companion-Integrationen mit `canOpenReadingDestination`. Google Books ist bewusst `notConnected` ohne Sync- oder OAuth-Fähigkeit. Local File ist als zukünftiger Reader-Eintrag vorhanden, aber ohne `canReadLocally` und deshalb nicht als aktive Reader-Funktion verfügbar.
- `ReadingProviderLaunchPolicy` validiert zentral alle externen Leselinks. Erlaubt werden nur öffentliche HTTPS-Links zu dokumentierten beziehungsweise belastbaren Provider-Webzielen; private URL-Schemes, lokale Hosts, private IPs und providerfremde Hosts werden abgelehnt.
- `ReadingIntegrationCoordinator` startet zuerst Timer und Live Activity über den bestehenden Timer-Pfad und entscheidet danach, ob ein externer Leselink geöffnet, eine Anleitung gezeigt oder ein unsicherer Link blockiert wird. SwiftUI-Views duplizieren diese Policy nicht.
- Einstellungen zeigen unter „Lesequellen und Integrationen“ pro Provider Verfügbarkeit, aktuelle Fähigkeiten und Fortschrittsmodus. Es gibt keine irreführende Verbunden-Anzeige.
- Das Buchdetail zeigt die Quelle des aktiven `ReadingAttempt` kompakt an und erlaubt einen Wechsel nur, solange der Attempt noch keine Sessions oder Progress Events enthält und kein Timer für das Buch läuft.
- Externe Referenzen laufen weiterhin über `BookExternalReference`; Google-Books-Importe legen daraus eine providerbezogene Referenz mit Volume-ID und validierter kanonischer URL an. Es werden keine neuen Provider-Felder an `Book` ergänzt und Provider-Referenzen werden nicht automatisch unsicher zusammengeführt.

## PR 7 Timer- und Live-Activity-Kontext

- `ReadingTimerManager.ActiveState`, `PendingCompletion` und die App-Group-Blobs speichern seit PR 7 einen `ReadingTimerSessionSourceSnapshot` mit `readingAttemptID`, `ReadingMedium`, `ReadingProvider`, `ReadingProgressUnit`, `ReadingSessionOrigin`, optionalem Gesamtwert und `expectedExternalReading`.
- Der Source-Snapshot wird beim Timer-Start aus dem aktuellen Lesedurchgang übernommen und danach nicht mehr aus einem später geänderten `Book` abgeleitet. `TimerSessionCompletionSheet` baut seinen Fortschrittseditor aus dem persistierten Pending-Completion-Snapshot.
- `ReadingTimerAutoStopPolicy` ist die zentrale, testbare Policy für Hintergrund-Stop und Live-Activity-Stale-Dates. Physische Sessions nutzen weiterhin die konfigurierte kurze Auto-Stop-Grenze. Externe Reader-Sessions dürfen beim Verlassen von Shelf Notes weiterlaufen und verwenden nur eine lange Sicherheitsgrenze gegen vergessene Timer.
- `ReadingSessionLiveActivitySnapshot`, `ReadingSessionActivityAttributes.ContentState` und `ReadingSessionLiveActivityPresentation` transportieren und rendern Fortschritt formatneutral: Seiten bleiben Seiten, Prozent wird als Prozentwert angezeigt, Locator ohne Prozent erzeugt keinen künstlichen Fortschrittsbalken, und `none` bleibt ohne Fortschrittsanzeige.
- Pause und Stop aus der Live Activity mutieren den App-Group-Store über `LiveActivitySharedStore`, damit App und Extension dieselben Schema-, Legacy- und Source-Regeln verwenden.

- `Book`: Zentrale Entität für Bücher, Metadaten, Lesestatus, Tags, Notizen, Cover-Daten, Bewertungen und Beziehungen zu Sessions/Sammlungen. Pfad: `Shelf Notes/BookModel/Book.swift`.
- `ReadingAttempt`: Primärer Anker für Medium, Standardanbieter und Fortschrittseinheit eines konkreten Lesedurchgangs. `Book` bleibt der Bibliothekseintrag. Pfad: `Shelf Notes/ReadingAttempts/ReadingAttempt.swift`.
- `ReadingStatus`: Fachlicher Lesestatus mit stabilen Raw Values `toRead`, `reading`, `finished`. Legacy-Werte auf Deutsch werden in `Shelf Notes/BookModel/Book+Status.swift` gemappt.
- `ReadingSession`: Einzelne Leseeinheit mit Start, Ende, Dauer, Seiten und optionaler Notiz sowie formatneutralen Source-Snapshots. Pfad: `Shelf Notes/ReadingSession.swift`.
- Reading-Source Raw Values: `ReadingMedium`, `ReadingProvider`, `ReadingProgressUnit`, `ReadingSessionOrigin` und `ReadingAnnotationKind` besitzen stabile englische Raw Values und sichere Fallbacks. Pfad: `Shelf Notes/ReadingSources/*`.
- `ReadingProgressEvent`: Provider- und formatneutrales Fortschrittsereignis mit nativen und optional normalisierten Werten. Pfad: `Shelf Notes/ReadingSources/ReadingProgressEvent.swift`.
- `ReadingProgressEngine`: Pure, formatneutrale Berechnung für genau einen Lesedurchgang auf Basis von `ReadingProgressAttemptSnapshot` und `ReadingProgressUpdate`. Pfad: `Shelf Notes/ReadingProgress/*`.
- `ReadingSessionSource` / `ReadingSessionContext`: Kleine Source-Werte für Attempt, Medium, Provider, Fortschrittseinheit, Origin und optionalen Gesamtwert. Pfad: `Shelf Notes/BookDetail/Sessions/ReadingSessionContext.swift`.
- `ReadingSourceSelection` / `ReadingSourceDraft`: Testbare Abbildung der Nutzerwahl auf Medium, Provider, Fortschrittseinheit und Session-Quelle. Externe Anbieter sind manuell getrackt; `localFile` ist sichtbar, aber noch nicht auswählbar. Pfade: `Shelf Notes/ReadingSources/ReadingSourceSelection.swift`, `Shelf Notes/ReadingSources/ReadingSourceDraft.swift`.
- `ReadingProgressInputView`: Gemeinsamer adaptiver Editor für Seiten, absolute Prozentstände, Locator und Sessions ohne messbaren Fortschritt. Parsing und Korrekturbestätigung liegen im pure `ReadingProgressInputBuilder`. Pfad: `Shelf Notes/BookDetail/Sessions/ProgressInput/*`.
- Reading-Presentation-Modelle: `ReadingProgressPresentation`, `ReadingSourcePresentation` und `ReadingSessionPresentation` verhindern künstliche Seitenangaben bei E-Books und halten Journey-/Session-Zeilen kompakt. Pfad: `Shelf Notes/BookDetail/Sessions/Presentation/*`.
- Mixed-Media-Metriken: `ReadingMetricEligibility`, `ReadingMetricContribution`, `ReadingSessionMetricMapper` und `ReadingProgressMetricMapper` entscheiden zentral nach Datenquelle, Fortschrittseinheit und Origin, welche Werte zu Zeit, Sessions, Lesetagen, Seiten, Einzelbuch-Fortschritt oder Abschlüssen beitragen. Pfad: `Shelf Notes/ReadingMetrics/*`.
- `ReadingProgressIncreaseDetector`: Pure Vergleichsschicht für echte Fortschrittsanstiege bei Seiten, Prozent und explizit normalisierten Locator-Werten. Unbekannte Locator werden nicht interpretiert. Pfad: `Shelf Notes/ReadingMetrics/ReadingProgressIncreaseDetector.swift`.
- `ReadingSessionAggregateSnapshot`: Sendable Session-Aggregate mit universeller Zeit/Sessionanzahl sowie separater seitenbasierter Zeitbasis für korrekte Seiten-pro-Stunde-Werte. Pfad: `Shelf Notes/ReadingSessionAggregates.swift`.
- `ReadingSessionMutationService`: Zentraler atomarer Schreibpfad für Session, sessiongebundenes Fortschrittsereignis, Reading Attempt und Book. Der kompatible `pages:`-Aufruf bleibt bestehen. Pfad: `Shelf Notes/BookDetail/Sessions/ReadingSessionMutationService.swift`.
- `ReadingProgressImportMutationService`: Speichert deduplizierte reine Fortschrittsimporte ohne Session, Lesezeit oder Book-Lesetag. Der Dienst ist providerneutral und enthält keinen Google-Books-Code. Pfad: `Shelf Notes/ReadingProgress/ReadingProgressImportMutationService.swift`.
- `ReadingSessionDeletionService`: Entfernt Sessions und alle über `sourceSessionID` beziehungsweise den stabilen Session-Key gebundenen Progress Events in einem gemeinsamen Save. Pfad: `Shelf Notes/BookDetail/Sessions/ReadingSessionDeletionService.swift`.
- `ReadingProgressRepair`: Idempotenter Backfill ohne einmaligen Migrationsschalter; läuft nach `ReadingAttemptRepair`, repariert Beziehungen und hält pro Legacy-Attempt höchstens ein deterministisches Seiten-Baseline-Event aktuell. Pfad: `Shelf Notes/ReadingProgress/ReadingProgressRepair*.swift`.
- `BookExternalReference`: Provider-spezifische Referenz eines Bibliothekseintrags ohne Tokens, Zugangsdaten oder lokale Dateipfade. Pfad: `Shelf Notes/ReadingSources/BookExternalReference.swift`.
- `ReadingAnnotation`: Provider-neutrales Modell für Highlight, Notiz oder Lesezeichen. Pfad: `Shelf Notes/ReadingSources/ReadingAnnotation.swift`.
- `ReadingGoal`: Jahresziel für gelesene Bücher. Pfad: `Shelf Notes/ReadingGoal.swift`.
- `BookCollection`: Nutzerdefinierte Liste/Sammlung von Büchern. Pfad: `Shelf Notes/BookCollection.swift`.
- `ChallengeRecord`: Persistierte Challenge für Wochen-/Monatszeiträume mit Metrik, Zielwert, Completion und Reroll-Status. Pfad: `Shelf Notes/Challenges/ChallengeModels.swift`.
- Tags: Freie String-Tags am Buch, normalisiert über `TagNormalization` und verarbeitet in `Shelf Notes/TagsView/*`.
- Synced Thumbnail: Kleines Cover-Bild in SwiftData, gespeichert als `Book.userCoverData` mit `@Attribute(.externalStorage)`. Pfad: `Shelf Notes/BookModel/Book.swift`.
- Full-Res User Cover: Lokale Originaldatei im App-Group-Container; nur der Dateiname wird am Buch gespeichert. Pfad: `Shelf Notes/ImageCaching/UserCoverStore.swift`.
- `StorageMode`: Startmodus für CloudKit, lokalen Store oder In-Memory-Store. Pfad: `Shelf Notes/Persistence/StorageMode.swift`.
- Local-only Mode: Separater lokaler SwiftData-Store ohne CloudKit, sichtbar über Banner in `Shelf Notes/AppContainerHostView.swift`.
- `saveWithDiagnostics`: Wrapper um `ModelContext.save()` mit lokalen Diagnose-Breadcrumbs. Pfad: `Shelf Notes/ModelContext+Diagnostics.swift`.
- Pro/StoreKit: `ProManager` und `Shelf Notes/unlimited_collections.storekit` steuern Pro-Funktionalität, unter anderem unbegrenzte Sammlungen.

## Architecture Map

### Start und Container

- `Shelf Notes/Shelf_NotesApp.swift`
  - `@main` App-Einstieg.
  - Rendert `AppContainerHostView()`.
- `Shelf Notes/AppContainerHostView.swift`
  - Hält `AppBootstrapper` als `@StateObject`.
  - Zeigt Loading, Ready oder Failure UI.
  - Injiziert `ModelContainer` über `.modelContainer(container)` in `RootView()`.
  - Startet nach Container-Ready zuerst `ReadingAttemptRepair`, danach `ReadingProgressRepair` und anschließend die Challenge-Vorbereitung.
- `Shelf Notes/AppBootstrap/AppBootstrapper.swift`
  - Baut den SwiftData-Container.
  - Versucht zuerst `.cloudKit`.
  - Bietet Retry, Local-only und In-Memory-Fallback.
- `Shelf Notes/Persistence/ModelContainerFactory.swift`
  - Definiert das SwiftData-Schema und die Store-Konfigurationen.

### UI-Schicht

- `RootView` ist der zentrale Tab-Host. Pfad: `Shelf Notes/RootView.swift`.
- Feature-Screens leben überwiegend in eigenen Ordnern:
  - Bibliothek: `Shelf Notes/LibraryView/*`
  - Fortschritt/Ziele/Statistiken/Timeline/Challenges: `Shelf Notes/ProgressHub/*`, `Shelf Notes/Goals/*`, `Shelf Notes/Stats/*`, `Shelf Notes/Timeline/*`, `Shelf Notes/Challenges/*`
  - Listen/Sammlungen: `Shelf Notes/Collections/*`
  - Tags: `Shelf Notes/TagsView/*`
  - Buchdetails: `Shelf Notes/BookDetail/*`
  - Import: `Shelf Notes/AddBook/*`, `Shelf Notes/BookImport/*`, `Shelf Notes/CSVImportExport/*`
  - Einstellungen: `Shelf Notes/Settings/*`

### Persistenz und Sync

- SwiftData-Modelle liegen teils im Root und teils unter `BookModel`/`Challenges`.
- CloudKit wird über SwiftData `.automatic` aktiviert. Pfad: `Shelf Notes/Persistence/ModelContainerFactory.swift`.
- CloudKit-Voraussetzungen werden im Datenmodell sichtbar berücksichtigt:
  - keine `@Attribute(.unique)` auf IDs,
  - optionale Beziehungen,
  - Default-Werte für nicht-optionale Felder.
- Diagnostik liegt in `Shelf Notes/SyncDiagnostics.swift`, `Shelf Notes/SyncDiagnosticsView.swift` und `Shelf Notes/ModelContext+Diagnostics.swift`.

### Derived-State- und Builder-Schicht

- Viele schwere Berechnungen sind in testbare Builder ausgelagert.
- Beispiele:
  - Library: `LibraryBooksIndex`, `LibraryDerivedStateBuilder`, `LibraryDisplayStore`
  - Mixed-Media-Metriken: `ReadingSessionMetricMapper`, `ReadingProgressMetricMapper`, `ReadingSessionAggregateBuilder`
  - Analytics: `ReadingAnalyticsInputMapper`, `ReadingAnalyticsIndexBuilder`, `ReadingCompletionRecordBuilder`
  - Stats: `StatisticsSourceStore`, `StatisticsComputePipeline`, `StatisticsSnapshotBuilder`, `StatisticsHeatmapBuilder`
  - Timeline: `ReadingTimelineBookSnapshot`, `ReadingTimelineBuilder`, `ReadingTimelineDisplayStore`
  - Tags: `TagsIndexBuilder`, `TagsDomainIndex`, `TagSuggestionEngine`, `TagHygieneBuilder`
  - Challenges: `ChallengeEngine`, `ChallengeEngine+Compute`, `ChallengeEngine+Snapshot`
  - Collections: `CollectionsDashboardBuilder`, `CollectionsSmartActionBuilder`

### Cover-/Image-Pipeline

- Remote-/Disk-/Memory-Loading: `Shelf Notes/CoverImageLoader.swift`, `Shelf Notes/CachedAsyncImage.swift`, `Shelf Notes/ImageCaching/*`.
- Disk Cache: `Shelf Notes/ImageCaching/ImageDiskCache.swift` mit Default-Limit 120 MB.
- Request-Deduping: `Shelf Notes/ImageCaching/CoverImageRequestDeduper.swift`.
- Temporärer Failure Cache: `Shelf Notes/ImageCaching/RemoteCoverFailureCache.swift`.
- Thumbnail-Erzeugung und Backfill: `Shelf Notes/CoverThumbnailer/CoverThumbnailer.swift`.
- Scroll-schonende Anzeige: `Shelf Notes/ImageViews/LibraryRowCoverView.swift` und `Shelf Notes/ImageViews/SyncedThumbnailImage.swift`.

### Live Activity

- Shared Live-Activity-Modelle: `Shelf Notes/Shared/LiveActivity/*`.
- App Extension: `ShelfNotesLiveActivity/*`.
- Reading Timer, Snapshot Builder, ActivityKit Coordinator, App-Group-State und Extension-UI sind bewusst getrennt.
- Live Activity zeigt Timer, Cover/Fallback, Status, Fortschritt, Challenge-Hinweise und Pause/Stop-Controls.
- App-Group-Entitlement ist in App und Extension vorhanden.

## Folder Map

- `Shelf Notes/BookModel`: Book-Modell und fachliche Extensions für Status, Ratings, Fortschritt, Collections, Import und Cover-URLs.
- `Shelf Notes/Persistence`: SwiftData-Container-Fabrik und Storage-Mode-Konzept.
- `Shelf Notes/AppBootstrap`: Startlogik für Container-Aufbau und Fallbacks.
- `Shelf Notes/AppLifecycle`: Startup-Maintenance, zum Beispiel Cover-Backfill und einmalige Jobs.
- `Shelf Notes/LibraryView`: Bibliotheksansicht, Filter, Sortierung, Grid/List, Header, Derived State.
- `Shelf Notes/BookDetail`: Detailansicht, Karten, Bindings, Sessions, Notizen und Timer-Integration.
- `Shelf Notes/BookDetail/Sessions`: Gemeinsame Quellenwahl, adaptiver Fortschrittseditor, formatneutrale Präsentation, Session-Kontexte, atomare Session-Mutationen, zentrale Löschung, Timer-Manager und Live-Activity-Brücke.
- `Shelf Notes/ReadingAttempts`: Reading-Attempt-Modell, Repair-Logik und Session-Zuordnung für Lesedurchgänge und Rereads.
- `Shelf Notes/ReadingSources`: Stabile Reading-Source Raw Values, formatneutrale Fortschrittsereignisse, externe Buchreferenzen, Annotationen und typisierte Modellzugriffe.
- `Shelf Notes/ReadingIntegrations`: Provider-Registry, Capabilities, Verfügbarkeit, URL-Policy, Companion-Koordination und Integrations-Präsentationszustände.
- `Shelf Notes/ReadingProgress`: Value-Snapshots, zentrale Fortschritts-Engine, Mutationsplanung, reine Progress-Imports, SwiftData-Adapter, deterministische Event-Fingerprints und idempotenter Legacy-Repair.
- `Shelf Notes/AddBook`: Klassischer Buch-Hinzufügen-Flow mit Google-Books-Suche und Formularlogik.
- `Shelf Notes/BookImport`: Moderner Import-Flow mit Query Builder, Filter Engine, Result Views und Seed Queries.
- `Shelf Notes/CSVImportExport`: CSV-Import/-Export und Import-Ausführung.
- `Shelf Notes/ImageCaching`: Memory-/Disk-Caches, Cover-Deduper, Failure Cache und User-Cover-Store.
- `Shelf Notes/ImageViews`: Wiederverwendbare Cover-/Thumbnail-Views.
- `Shelf Notes/CoverThumbnailer`: Thumbnail-Erzeugung, Remote-Cover-Anwendung und Backfill.
- `Shelf Notes/ProgressHub`: Fortschritts-Hub und aggregierte Fortschrittsmetriken.
- `Shelf Notes/Goals`: Jahresziel-UI und Zielmetriken.
- `Shelf Notes/Stats`: Statistikquelle, Snapshot Builder, Compute Pipeline, Heatmaps und Präsentationsmodelle.
- `Shelf Notes/Timeline`: Timeline-UI und Builder.
- `Shelf Notes/Challenges`: Challenge-Modelle, Engine, Templates, Rewards, Dashboard, Hints und Refresh-Koordination.
- `Shelf Notes/Collections`: Collections Hub, Detail, Mutationen, Dashboard und Smart Actions.
- `Shelf Notes/TagsView`: Tags Dashboard, Detail, Index, Suggestions, Hygiene Insights und Cleanup.
- `Shelf Notes/Settings`: Einstellungen, Lesequellen-/Integrationsübersicht, Sync-Diagnose, Pro-Screen, Appearance und Library Appearance.
- `Shelf Notes/Analytics`: Leseanalyse-Indizes und Hilfsmodelle.
- `Shelf Notes/Shared/LiveActivity`: Gemeinsame Typen zwischen App und Live-Activity-Extension.
- `ShelfNotesLiveActivity`: Live-Activity-Extension Target.
- `Shelf NotesTests`: Unit Tests für Builder, Mutationen, Caches, Tags, Library, Stats, Challenges und Storage.
- `Shelf NotesUITests`: UI-Test-Stubs.

## Data Model Map

### `Book`

Pfad: `Shelf Notes/BookModel/Book.swift`

Wichtige Felder:

- Identität: `id`, `createdAt`
- Kernmetadaten: `title`, `author`, `subtitle`, `publisher`, `publishedDate`, `language`, `categories`, `mainCategory`, `bookDescription`
- Status: `statusRawValue`, fachlich gekapselt über `readingStatus`
- Nutzerinhalt: `tags`, `notes`, `readFrom`, `readTo`
- Import-IDs: `googleVolumeID`, `isbn13`
- Cover: `thumbnailURL`, `coverURLCandidates`, `userCoverData`, `userCoverFileName`
- Google-Books-Links: `previewLink`, `infoLink`, `canonicalVolumeLink`
- Google-Books-Verfügbarkeit: `viewability`, `isPublicDomain`, `isEmbeddable`, `isEpubAvailable`, `isPdfAvailable`, `epubAcsTokenLink`, `pdfAcsTokenLink`, `saleability`, `isEbook`
- Ratings: sechs Integer-Felder für Plot, Charaktere, Schreibstil, Atmosphäre, Genre Fit und Präsentation

Wichtig: `Book.isEbook` bleibt ausschließlich importierte Google-Books-Metainformation. Die vom Nutzer verwendete Leseart liegt auf `ReadingAttempt.readingMediumRawValue`.

Beziehungen:

- `collections: [BookCollection]?`
- `readingSessions: [ReadingSession]?` mit Cascade Delete
- `readingAttempts: [ReadingAttempt]?` mit Cascade Delete
- `readingProgressEvents: [ReadingProgressEvent]?` mit Cascade Delete
- `externalReferences: [BookExternalReference]?` mit Cascade Delete
- `readingAnnotations: [ReadingAnnotation]?` mit Cascade Delete

### `ReadingAttempt`

Pfad: `Shelf Notes/ReadingAttempts/ReadingAttempt.swift`

- Identität und Lifecycle: `id`, `sequenceNumber`, `statusRawValue`, `startedAt`, `finishedAt`, `createdAt`, `updatedAt`
- Kompatibilität: `pageCountSnapshot` bleibt unverändert erhalten
- Reading Source: `readingMediumRawValue`, `defaultProviderRawValue`, `progressUnitRawValue`
- Externe Metadaten: `totalValueSnapshot`, `providerItemIdentifier`, `lastExternalSyncAt`
- Beziehungen: `book`, `sessions`, `progressEvents`, `annotations`
- Delete Rules: Session-, Event- und Annotation-Beziehungen werden beim Löschen eines Attempts nullifiziert, damit Historie erhalten bleibt
- Derived Progress: `progressInputSnapshot` bildet nur zugehörige Sessions und Events in Value-Typen ab; `readingProgressSnapshot` delegiert an die zentrale Engine

### `ReadingSession`

Pfad: `Shelf Notes/ReadingSession.swift`

- `id`
- `book: Book?`
- `readingAttempt: ReadingAttempt?`
- `startedAt`, `endedAt`, `durationSeconds`
- `pagesRead`
- `note`
- Source-Snapshots: `mediumRawValue`, `providerRawValue`, `originRawValue`, `progressUnitRawValue`
- Fortschritts-Snapshots: `startValue`, `endValue`, `startNormalizedProgress`, `endNormalizedProgress`, `startLocator`, `endLocator`
- Externe Zuordnung: `externalEventIdentifier`
- `createdAt`

Legacy-Defaults bleiben `physical`, `none`, `legacy` und `pages`.

### `ReadingProgressEvent`

Pfad: `Shelf Notes/ReadingSources/ReadingProgressEvent.swift`

- Beziehungen: `book`, optional `readingAttempt`
- Zeit und Quelle: `occurredAt`, Medium, Provider, Unit, Origin
- Fortschritt: `nativeValue`, optional `totalValue`, `normalizedProgress`, `locator`
- Import/Deduplizierung: `externalIdentifier`, `deduplicationKey`, `sourceSessionID`, `importedAt`
- Audit: `createdAt`, `updatedAt`
- Legacy-Baseline: `ReadingProgressRepair` verwendet `legacy-pages-baseline:<attempt-id>` und aktualisiert dieses Event bei später eintreffenden Legacy-Sessions, statt neue Events anzulegen

### Formatneutrale Fortschrittsberechnung

Pfade: `Shelf Notes/ReadingProgress/*`, `Shelf Notes/BookModel/Book+ReadingProgress.swift`, `Shelf Notes/BookDetail/Sessions/ReadingSessionLogging.swift`

- Seitenfortschritt summiert ausschließlich positive `pagesRead`-Werte der betrachteten Attempt-Sessions. Gesamtwerte stammen bevorzugt aus `pageCountSnapshot`, danach aus belastbaren ganzzahligen Total-Snapshots.
- Prozentfortschritt wählt den neuesten gültigen absoluten Stand. Gleich datierte Updates werden über einen stabilen Identifier deterministisch entschieden. Es werden keine Seitenwerte erfunden.
- Locator-Fortschritt bewahrt den nativen Locator. Ein Prozentwert wird nur aus einem explizit gespeicherten normalisierten Wert übernommen; unbekannte Locator-Formate werden nicht interpretiert.
- Fehlender Fortschritt bleibt unbekannt (`nil`) und wird nicht automatisch als null Prozent dargestellt. Reine Zeit- oder Notiz-Sessions sind damit zulässig.
- Ein abgeschlossener Attempt liefert vollständig. Aktive Wiederholungslesungen verwenden ausschließlich den aktiven Attempt und übernehmen keinen Fortschritt früherer Durchgänge.
- `ReadingProgressMutationPlanner` validiert Seitendifferenzen, absolute Prozent-/Locator-Stände, explizite Abschlüsse und einen ausdrücklich gewählten Korrekturmodus. Normale Updates dürfen bekannten Fortschritt nicht zurücksetzen.
- Jede Session mit Fortschritt besitzt höchstens ein Event mit `sourceSessionID` und `session-progress:<session-id>`. Erneutes Speichern aktualisiert dieses Event statt ein zweites anzulegen.
- Reine Fortschrittsimporte verwenden einen vom Aufrufer gelieferten stabilen Deduplizierungsschlüssel, erzeugen keine Session und verändern `Book.readFrom`/`readTo` nicht.
- Session-Löschungen laufen über `ReadingSessionDeletionService`, damit sessiongebundene Progress Events nicht verwaist oder weiterhin wirksam bleiben.
- Bestehende Aufrufer bleiben über `Book+ReadingProgress`, `ReadingSessionLogging` und den kompatiblen `pages:`-Mutationspfad korrekt. Quick Log und Timer erzeugen über `ReadingProgressInputBuilder` nun dieselben Seiten-, Prozent-, Locator- oder leeren Updates.

### Einheitliche Lesequellen- und Fortschritts-UX

Pfade: `Shelf Notes/ReadingSources/ReadingSource*.swift`, `Shelf Notes/BookDetail/Sessions/ProgressInput/*`, `Shelf Notes/BookDetail/Sessions/Presentation/*`

- Neue Lesedurchgänge speichern die gewählte Quelle direkt am `ReadingAttempt`. Bestehende Legacy-Attempts bleiben ohne Zwangsabfrage `physical`/`none`/`pages`.
- Verfügbare manuelle Quellen sind physisches Buch, Apple Books, Kindle, Google Books und andere E-Book-Apps. EPUB/PDF in Shelf Notes wird als späterer lokaler Reader angezeigt, ist aber noch nicht auswählbar.
- `ReadingProgressInputBuilder` akzeptiert leere Eingaben, Seitendifferenzen, absolute Prozentstände, Locator mit optionalem Prozentwert und expliziten Abschluss. Ein niedrigerer absoluter Stand erfordert eine bewusste Korrekturbestätigung.
- `ReadingProgressPresentationBuilder` zeigt Seiten ausschließlich für `.pages`. Prozent- und Locator-Quellen erhalten eigene Texte; unbekannter Fortschritt bleibt sichtbar unbekannt.
- `ReadingJourneyCard`, `SessionRow`, gruppierte Session-Vorschauen und die vollständige Session-Liste zeigen Medium/Provider, Fortschritt und hilfreiche Herkunft kompakt.
- `Book.isEbook` bleibt reine Google-Books-Metainformation und wird nicht für die Nutzer-Leseart herangezogen.

### Mixed-Media Derived States und Analytics

Pfade: `Shelf Notes/ReadingMetrics/*`, `Shelf Notes/ReadingSessionAggregates.swift`, `Shelf Notes/Analytics/*`, `Shelf Notes/Stats/*`, `Shelf Notes/Goals/*`, `Shelf Notes/ProgressHub/*`, `Shelf Notes/Timeline/*`, `Shelf Notes/LibraryView/*`

- Universell für echte Sessions sind Sessionanzahl, Dauer, Lesetage, Streaks und durchschnittliche Sessiondauer. Ein `providerImport`-Event oder eine defensiv als `providerImport` klassifizierte Session trägt dazu nicht bei.
- Seitenmetriken werden nur aus `.pages`-Daten gebildet. `pageBasedDurationSeconds` hält die Zeitbasis für Seiten pro Stunde getrennt von Prozent- und Locator-Sessions.
- Prozent- und Locator-Fortschritt kann den aktuellen Fortschritt und Abschluss eines einzelnen Books beeinflussen, wird aber nicht bibliotheksweit addiert und erzeugt keine künstlichen Seitenwerte.
- Abschlussstatistiken zählen jeden beendeten `ReadingAttempt`; Wiederholungslesungen bleiben historische Abschlüsse, während der aktive Attempt allein den aktuellen Bibliotheksfortschritt steuert.
- `ReadingAnalyticsInputMapper`, Statistics-Snapshots und Timeline-Snapshots lesen SwiftData ausschließlich am Main Actor in kleine `Sendable`-Werte. Analytics-, Heatmap- und Timeline-Builder arbeiten anschließend value-basiert außerhalb des Main Actors.
- Cache-Signaturen enthalten nur ergebnis- oder darstellungsrelevante Quellenfelder: Stats und Goals berücksichtigen die Fortschrittseinheit, Session-Signaturen zusätzlich die Origin; Timeline und Library berücksichtigen sichtbare Medium-/Provider-Informationen. Locator-Änderungen invalidieren keine globalen Statistiken.
- Library, Continue Reading, Stats, Goals und Timeline zeigen gemischte Quellen formatneutral. Seitenkennzahlen werden bei gemischten Daten dezent als ausschließlich seitenbasiert gekennzeichnet.

### Stufe 1 abgeschlossen: Challenges und Bibliothekswidget

Pfade: `Shelf Notes/Challenges/*`, `Shelf Notes/Widgets/*`, `Shelf Notes/Shared/Widgets/*`, `ShelfNotesLiveActivity/LibraryOverviewWidget/*`

- Universelle Challenge-Metriken (`readingMinutes`, `sessions`, `readingDays`) verwenden ausschließlich echte Sessions. Prozent- und Locator-Sessions zählen dabei wie physische Sessions; `providerImport` zählt nicht.
- `pagesRead` und seitenbezogene Challenge-Ziele verwenden ausschließlich `.pages`-Beiträge. Prozent- und Locator-Werte werden nie in Seiten umgerechnet.
- `booksProgressed` erkennt pro Buch einen echten Fortschrittsanstieg bei Seiten, Prozent oder explizit normalisiertem Locator. Provider-Events werden über stabilen Schlüssel sowie Book-/Attempt-Scope dedupliziert.
- Challenge-Hinweise richten sich nach der Progress Unit. Prozentbasierte Attempts erhalten keine Restseiten-Texte; physische Hinweise bleiben unverändert seitenbasiert.
- Das Bibliothekswidget transportiert optional Medium, Provider, Progress Unit, nativen Wert und Locator. Seitenfelder werden nur für `.pages` serialisiert; Prozentwerte und Locator erhalten eigene kompakte Darstellungen.
- Alte Widget-Payloads ohne Source-Felder bleiben decodierbar. Die Schema-Version bleibt deshalb unverändert; fehlende Source-Felder werden nur für alte vorhandene Seitenwerte als `.pages` interpretiert.
- CSV-Import und -Export behalten ihren bisherigen flachen Contract `title,isbn13`. Progress Events, Annotationen, externe Referenzen, Tokens und lokale Dateipfade werden nicht exportiert.
- Die Suche nach direkten `pagesRead`-Verwendungen ist abgeschlossen: Fortschritts-Engine, Session-Mutation, seitenbasierte Analytics, Challenge-Seitenmetrik und Legacy-Live-Activity sind bewusst seitenbezogen; gemischte globale Metriken laufen über `ReadingMetrics`.

### `BookExternalReference`

Pfad: `Shelf Notes/ReadingSources/BookExternalReference.swift`

- Beziehung: `book`
- Provider: `providerRawValue`, `providerItemIdentifier`
- Edition: `canonicalURL`, `isbn13`, `editionNote`
- Audit: `createdAt`, `updatedAt`

### `ReadingAnnotation`

Pfad: `Shelf Notes/ReadingSources/ReadingAnnotation.swift`

- Beziehungen: `book`, optional `readingAttempt`
- Klassifikation: `kindRawValue`, `providerRawValue`, `originRawValue`
- Inhalt und Position: `selectedText`, `note`, `locator`, `normalizedProgress`
- Import/Deduplizierung: `externalIdentifier`, `deduplicationKey`, `importedAt`
- Audit: `createdAt`, `updatedAt`

### `ReadingGoal`

Pfad: `Shelf Notes/ReadingGoal.swift`

- `id`
- `year`
- `targetCount`
- `updatedAt`

### `BookCollection`

Pfad: `Shelf Notes/BookCollection.swift`

- `id`
- `name`
- `createdAt`, `updatedAt`
- `books: [Book]?`
- Helper: `booksSafe`, Add/Remove/Contains

### `ChallengeRecord`

Pfad: `Shelf Notes/Challenges/ChallengeModels.swift`

- `id`
- `periodStart`, `periodEnd`
- `kindRawValue`, `metricRawValue`
- `title`, `detail`
- `targetValue`
- `createdAt`, `completedAt`, `acknowledgedAt`
- `rerollsUsed`, `rerolledAt`

### Model-Schema

Pfad: `Shelf Notes/Persistence/ModelContainerFactory.swift`

Schema enthält:

- `Book`
- `ReadingAttempt`
- `ReadingSession`
- `ReadingProgressEvent`
- `BookExternalReference`
- `ReadingAnnotation`
- `ReadingGoal`
- `BookCollection`
- `ChallengeRecord`

## Sync / Storage

- Primärer Store: `ShelfNotesCloud.store` unter Application Support. Pfad: `Shelf Notes/Persistence/ModelContainerFactory.swift`.
- Local-only Store: `ShelfNotesLocal.store` unter Application Support. Pfad: `Shelf Notes/Persistence/ModelContainerFactory.swift`.
- In-Memory-Store: Emergency/Fallback-Modus für Startfehler. Pfad: `Shelf Notes/Persistence/ModelContainerFactory.swift`.
- CloudKit: App-Konfiguration nutzt `cloudKitDatabase: .automatic`.
- Entitlements:
  - App: `Shelf Notes/Shelf_Notes.entitlements`
  - Extension: `ShelfNotesLiveActivityExtension.entitlements`
  - Container: `iCloud.de.marcfechner.Shelf-Notes`
  - App Group: `group.de.marcfechner.Shelf-Notes`
- Offline-Verhalten:
  - Normale CloudKit-Konfiguration speichert lokal und synchronisiert über SwiftData/CloudKit im Hintergrund.
  - Detaillierter CloudKit-Fortschritt ist im Code als nicht verfügbar dokumentiert. Pfad: `Shelf Notes/SyncDiagnostics.swift`.
  - Local-only Mode verwendet absichtlich einen separaten lokalen Store und synchronisiert nicht.
- Caches:
  - Cover Disk Cache: Caches-Verzeichnis `cover-cache`, Default 120 MB. Pfad: `Shelf Notes/ImageCaching/ImageDiskCache.swift`.
  - Cover Memory Cache: `Shelf Notes/ImageCaching/ImageMemoryCache.swift`.
  - Synced Thumbnail Memory Cache: `Shelf Notes/ImageCaching/SyncedThumbnailMemoryCache.swift`.
  - Remote Failure Cache: `Shelf Notes/ImageCaching/RemoteCoverFailureCache.swift`.
  - Search History: `Shelf Notes/SearchHistoryStore.swift`.
- Migration:
  - Status-Legacy-Werte werden über `Shelf Notes/BookModel/Book+Status.swift` und `Shelf Notes/Persistence/ReadingStatusMigrator.swift` behandelt.
  - Reading-Source-Erweiterungen sind additiv. Neue nicht-optionale Raw-Value-Felder besitzen migrationssichere Defaults; unbekannte persistierte Werte werden typisiert auf sichere Fallbacks abgebildet.
  - `ReadingProgressRepair` läuft bei jedem Startup nach `ReadingAttemptRepair`. Es gibt bewusst keinen `UserDefaults`-Migrationsschalter, damit später eintreffende CloudKit-Legacy-Daten erneut klassifiziert und eingegliedert werden können.
  - Der Repair repariert fehlende Book-/Attempt-Beziehungen, klassifiziert leere Source-Felder als `physical`, `none`, `pages` und `legacy`, entfernt nur exakt identische Events mit stabiler Identität und aktualisiert ein deterministisches Seiten-Baseline-Event pro Attempt.
  - Eine explizite SwiftData-Versionierung oder umfassende Migration Strategy wurde im Scan nicht als zentrale Policy gefunden: **UNKNOWN**.

## UI Map

### Root Navigation

Pfad: `Shelf Notes/RootView.swift`

`TabView` mit fünf Tabs:

1. Bibliothek: `LibraryView()`
2. Fortschritt: `ProgressHubView()`
3. Listen: `CollectionsView()`
4. Tags: `TagsView()`
5. Einstellungen: `SettingsView()`

Root-Level Environment Objects:

- `ProManager`
- `ReadingTimerManager`
- `TagsIndexStore`

Root-Level AppStorage/SceneStorage:

- Aktiver Tab via `@SceneStorage("root_selected_tab_v1")`
- Appearance- und Library-Settings via `@AppStorage`
- CSV-First-Run-State via `@AppStorage`

### Wichtige Flows und Sheets

- CSV-Import beim ersten Start ohne Bücher: `CSVImportExportView`
- Timer-Abschluss: `TimerSessionCompletionSheet`
- Lesequellenauswahl: `ReadingSourceSelectionSheet`
- Adaptiver Fortschrittseditor: `ReadingProgressInputView`, genutzt von `QuickSessionLogSheet` und `TimerSessionCompletionSheet`
- Wiederholungsdurchgang: `ReReadStartSheet` mit eigener Quellenwahl für den neuen Attempt
- Buch hinzufügen/importieren: `AddBook`, `BookImport`
- Buchdetail: `BookDetailView` mit Status, Metadaten, Tags, Ratings, Sessions, Notizen und Collections
- Collections: Hub, Detail, New Collection, Bulk Add
- Tags: Dashboard, Detail, Suggestions, Hygiene Insights, Cleanup Confirmation
- Challenges: Dashboard, Reward Sheet, Reroll, Session Action Hints
- Settings: Appearance, Library Appearance, Sync Diagnostics, Pro

## Build & Configuration

- Xcode-Projekt: `Shelf Notes.xcodeproj`
- App Target: `Shelf Notes`
- Unit-Test Target: `Shelf NotesTests`
- UI-Test Target: `Shelf NotesUITests`
- Extension Target: `ShelfNotesLiveActivityExtension`
- Deployment Target: iOS 26.0 laut `Shelf Notes.xcodeproj/project.pbxproj`
- Swift Version: 5.0 laut `Shelf Notes.xcodeproj/project.pbxproj`
- Concurrency Settings:
  - `SWIFT_APPROACHABLE_CONCURRENCY = YES`
  - `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
- Bundle IDs:
  - App: `de.marcfechner.Shelf-Notes`
  - Extension: `de.marcfechner.Shelf-Notes.ShelfNotesLiveActivity`
- Versionierung laut Projektdatei:
  - `MARKETING_VERSION = 1.08`
  - `CURRENT_PROJECT_VERSION = 5`
- Info.plist: `Shelf Notes/Info.plist`
  - `GOOGLE_BOOKS_API_KEY = $(GOOGLE_BOOKS_API_KEY)`
  - Kamera- und Foto-Library-Beschreibungen
  - `NSSupportsLiveActivities = true`
  - `UIBackgroundModes = remote-notification`
- xcconfig:
  - `Shelf Notes/config/base.xcconfig`
  - `Shelf Notes/config/secrets.xcconfig`
- Secrets:
  - `Shelf Notes/config/secrets.xcconfig` liegt im ZIP und enthält einen Google-Books-Key im Klartext.
  - `.gitignore` unter `Shelf Notes/.gitignore` schließt `config/secrets.xcconfig` aus.
  - Ob dieser Key historisch committed wurde, ist **UNKNOWN**.
- SPM:
  - Im Projekt wurden keine Package Product Dependencies gefunden.
- Privacy Manifest:
  - `Shelf Notes/PrivacyInfo.xcprivacy`
- Testpläne:
  - `ShelfNotesAppTests.xctestplan` enthält Unit- und UI-Testtargets.
  - `Shelf Notes.xctestplan` enthält keine Testtargets.

## Conventions

### SwiftData / CloudKit

- Keine `@Attribute(.unique)` auf Modell-IDs verwenden, solange CloudKit-Kompatibilität Priorität hat.
- Beziehungen optional halten, wenn CloudKit-Kompatibilität relevant ist.
- Nicht-optionale Modellfelder mit Defaults versehen.
- Neue Modelle in `ModelContainerFactory.schema` aufnehmen.
- Bei Model-Änderungen immer Migration, Backfill oder Repair-Job mitdenken.
- Mutationen möglichst über `modelContext.saveWithDiagnostics()` speichern.

### UI / SwiftUI

- Große Views werden über Extensions und kleine Subviews gesplittet.
- Teure Berechnungen in Builder/Stores auslagern, nicht direkt in `body`.
- Für Listen/Grid-Cover `LibraryRowCoverView` nutzen, weil diese View keine SwiftData-Saves aus dem Scrollpfad triggert.
- UI-State und fachliche Derived-State-Berechnung trennen.
- AppStorage-Keys stabil und versioniert benennen.

### Builder / Stores / Tests

- Fachlogik bevorzugt in pure Builder legen.
- Für neue Builder Unit Tests im Target `Shelf NotesTests` ergänzen.
- Bestehende Muster:
  - `LibraryDerivedStateBuilderTests`
  - `StatisticsSnapshotBuilderTests`
  - `Challenge*Tests`
  - `Tag*Tests`
  - `Collection*Tests`
  - `ReadingProgressEngineTests`
  - `ReadingProgressMutationPlannerTests`
  - `ReadingProgressRepairTests`
  - `BookReadingProgressTests`
  - `ReadingSessionMutationServiceTests`
  - `ReadingSessionProgressMutationTests`
  - `ReadingProgressImportMutationServiceTests`
  - `ReadingSessionDeletionServiceTests`
  - `ReadingSessionAttemptIsolationTests`
  - `ReadingSourceSelectionTests`
  - `ReadingProgressInputBuilderTests`
  - `ReadingProgressPresentationTests`
  - `ReadingSessionPresentationTests`
  - `ReadingSourceSessionUXTests`
  - `ReadingMetricCompatibilityTests`
  - `ReadingAnalyticsIndexBuilderTests`
  - `StatisticsSnapshotBuilderTests`
  - `StatisticsComputePipelineTests`
  - `ReadingTimelineBuilderTests`
  - `LibraryBookPresentationTests`

### Projektstruktur

- Neue Feature-Dateien klein und modular halten.
- Neue Dateien innerhalb der bestehenden Feature-Ordner ablegen.
- Das Projekt nutzt synchronized file groups; neue Dateien werden automatisch vom Target erkannt.

## How to work on this project

### Setup Steps

1. Projekt in Xcode 26 öffnen: `Shelf Notes.xcodeproj`.
2. Signing Team für App und Extension prüfen.
3. iCloud Container `iCloud.de.marcfechner.Shelf-Notes` und App Group `group.de.marcfechner.Shelf-Notes` im Apple Developer Portal prüfen.
4. `Shelf Notes/config/secrets.xcconfig` lokal bereitstellen, aber nicht committen.
5. App Scheme `Shelf Notes` bauen.
6. Tests vorzugsweise über `ShelfNotesAppTests.xctestplan` laufen lassen.
7. Bei Sync-Problemen zuerst `Settings` und `SyncDiagnosticsView` prüfen.

### Wo anfangen für neue Entwickler

- App-Start: `Shelf Notes/Shelf_NotesApp.swift`, `Shelf Notes/AppContainerHostView.swift`, `Shelf Notes/RootView.swift`
- Persistenz: `Shelf Notes/Persistence/ModelContainerFactory.swift`, `Shelf Notes/BookModel/Book.swift`
- Fortschritt und Session-Mutationen: `Shelf Notes/ReadingProgress/*`, `Shelf Notes/BookDetail/Sessions/ReadingSessionMutationService.swift`, `Shelf Notes/BookDetail/Sessions/ReadingSessionDeletionService.swift`, `Shelf Notes/BookModel/Book+ReadingProgress.swift`, `Shelf Notes/ReadingAttempts/ReadingAttemptSessionCoordinator.swift`
- Library-Hotpath: `Shelf Notes/LibraryView/LibraryView.swift`, `Shelf Notes/LibraryView/LibraryDerivedStateBuilder.swift`
- Stats-Hotpath: `Shelf Notes/Stats/StatisticsSourceStore.swift`, `Shelf Notes/Stats/StatisticsComputePipeline.swift`
- Cover-Hotpath: `Shelf Notes/CoverImageLoader.swift`, `Shelf Notes/CoverThumbnailer/CoverThumbnailer.swift`, `Shelf Notes/ImageViews/LibraryRowCoverView.swift`

### Feature-Workflow

- Neues Datenfeld:
  - Modell anpassen.
  - CloudKit-Kompatibilität prüfen.
  - Migration/Repair/Default definieren.
  - Tests ergänzen.
- Neue UI-Funktion:
  - Kleinen Feature-Ordner oder bestehendes Feature-Modul nutzen.
  - View, Builder, Presentation Model und Tests trennen.
  - Keine schweren Berechnungen in `body`.
- Neue Persistenzmutation:
  - Mutation zentralisieren.
  - `saveWithDiagnostics()` verwenden.
  - Bei Session-/Challenge-/Stats-Relevanz passende Refresh-Signale prüfen.
- Neuer Import-/Sync-Flow:
  - Netzwerk, Parsing, Draft und Save getrennt halten.
  - Cancellation und Generation Guards einbauen.

## Quick Wins

1. Google-Books-Key rotieren und sicherstellen, dass `secrets.xcconfig` nie committed wird. Pfade: `Shelf Notes/config/secrets.xcconfig`, `Shelf Notes/.gitignore`.
2. Leeren Testplan `Shelf Notes.xctestplan` entweder entfernen oder mit denselben Targets wie `ShelfNotesAppTests.xctestplan` füllen.
3. `StatisticsSnapshotBuilder.swift` in kleinere Builder splitten, um Review- und Regression-Risiko zu senken.
4. `ChallengeEngine+Compute.swift` nach Metrikberechnung, Baseline und Auswahlpolitik trennen.
5. Challenge-Refresh nach Session-Änderungen coalescen, damit mehrere Saves nicht mehrere Fetch-/Compute-Runden auslösen.
6. Library-Index nur bei Source-Signature-Änderungen neu bauen, nicht bei jeder Root-View-Invalidation.
7. Cover-Pipeline zusätzlich mit globalem Limit für parallele unterschiedliche Remote-URLs absichern.
8. Eine kurze `MIGRATIONS.md` ergänzen: Modelländerungen, Repair-Jobs, CloudKit-Risiken.
9. `os.Logger`-Kategorien für Storage, Sync, Covers, Stats, Challenges und Import einführen.
10. Local-only Mode in Docs und UI noch klarer erklären: separater Store, keine spätere automatische CloudKit-Merge-Logik.
