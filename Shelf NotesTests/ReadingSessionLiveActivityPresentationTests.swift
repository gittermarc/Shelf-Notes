import Foundation
import Testing
@testable import Shelf_Notes

struct ReadingSessionLiveActivityPresentationTests {
    @Test func runningStateUsesReadableStatusAndTimerCopy() {
        let (attributes, state) = makePayload(isPaused: false)

        let presentation = ReadingSessionLiveActivityPresentation(attributes: attributes, state: state)

        #expect(presentation.statusText == ReadingSessionLiveActivitySnapshot.runningStateLabel)
        #expect(presentation.timerCaption == "Lesezeit")
        #expect(presentation.compactStatusText == "Live")
        #expect(presentation.minimalSystemImage == "book.closed.fill")
        #expect(presentation.toggleTitle == "Pause")
        #expect(presentation.toggleSystemImage == "pause.fill")
        #expect(presentation.toggleAccessibilityLabel == "Lesesession pausieren")
    }

    @Test func pausedStateUsesPausedStatusAndResumeControl() {
        let (attributes, state) = makePayload(isPaused: true)

        let presentation = ReadingSessionLiveActivityPresentation(attributes: attributes, state: state)

        #expect(presentation.statusText == ReadingSessionLiveActivitySnapshot.pausedStateLabel)
        #expect(presentation.timerCaption == "Angehalten")
        #expect(presentation.compactStatusText == "Pause")
        #expect(presentation.minimalSystemImage == "pause.fill")
        #expect(presentation.toggleTitle == "Weiter")
        #expect(presentation.toggleSystemImage == "play.fill")
        #expect(presentation.toggleAccessibilityLabel == "Lesesession fortsetzen")
    }

    @Test func progressPayloadProducesPercentPagesAndAccessibilityText() {
        let snapshot = ReadingSessionLiveActivitySnapshot(
            bookID: UUID(),
            bookTitle: "Progress",
            pageCount: 300,
            pagesRead: 75,
            remainingPages: 225,
            progressFraction: 0.25,
            hasCover: false
        )
        let attributes = ReadingSessionActivityAttributes(snapshot: snapshot)
        let state = ReadingSessionActivityAttributes.ContentState(
            isPaused: false,
            effectiveStartDate: Date(timeIntervalSince1970: 1_000),
            pausedElapsedSeconds: 0,
            snapshot: snapshot
        )

        let presentation = ReadingSessionLiveActivityPresentation(attributes: attributes, state: state)

        #expect(presentation.hasProgress)
        #expect(presentation.progressText == "25 % gelesen")
        #expect(presentation.compactProgressText == "25 %")
        #expect(presentation.progressDetailText == "75 von 300 Seiten")
        #expect(presentation.remainingPagesText == "noch 225 Seiten")
        #expect(presentation.progressAccessibilityLabel == "Fortschritt: 25 % gelesen, 75 von 300 Seiten")
    }

    @Test func missingProgressPayloadKeepsProgressTextsEmpty() {
        let (attributes, state) = makePayload(pageCount: nil, pagesRead: nil, remainingPages: nil, progressFraction: nil)

        let presentation = ReadingSessionLiveActivityPresentation(attributes: attributes, state: state)

        #expect(!presentation.hasProgress)
        #expect(presentation.progressText == nil)
        #expect(presentation.compactProgressText == nil)
        #expect(presentation.progressDetailText == nil)
        #expect(presentation.remainingPagesText == nil)
        #expect(presentation.progressAccessibilityLabel == nil)
    }

    @Test func challengePayloadProducesMotivationTexts() {
        let snapshot = ReadingSessionLiveActivitySnapshot(
            bookID: UUID(),
            bookTitle: "Challenge",
            challengeTitle: "Tagesmission",
            challengeDetail: "Noch 12 Minuten",
            challengeProgressFraction: 0.6,
            hasCover: false
        )
        let attributes = ReadingSessionActivityAttributes(snapshot: snapshot)
        let state = ReadingSessionActivityAttributes.ContentState(
            isPaused: false,
            effectiveStartDate: Date(timeIntervalSince1970: 2_000),
            pausedElapsedSeconds: 0,
            snapshot: snapshot
        )

        let presentation = ReadingSessionLiveActivityPresentation(attributes: attributes, state: state)

        #expect(presentation.hasChallenge)
        #expect(presentation.challengeTitle == "Tagesmission")
        #expect(presentation.challengeDetail == "Noch 12 Minuten")
        #expect(abs((presentation.challengeProgressFraction ?? 0) - 0.6) < 0.0001)
        #expect(presentation.challengeAccessibilityLabel == "Motivation: Tagesmission, Noch 12 Minuten")
    }

    @Test func missingChallengePayloadKeepsMotivationTextsEmpty() {
        let (attributes, state) = makePayload()

        let presentation = ReadingSessionLiveActivityPresentation(attributes: attributes, state: state)

        #expect(!presentation.hasChallenge)
        #expect(presentation.challengeTitle == nil)
        #expect(presentation.challengeDetail == nil)
        #expect(presentation.challengeProgressFraction == nil)
        #expect(presentation.challengeAccessibilityLabel == nil)
    }

    @Test func longTitleIsPreservedForLockScreenAndLimitedForCompactIsland() {
        let longTitle = String(repeating: "Sehr langer Titel ", count: 8)
        let (attributes, state) = makePayload(title: longTitle)

        let presentation = ReadingSessionLiveActivityPresentation(attributes: attributes, state: state)

        #expect(presentation.title.count == 80)
        #expect(presentation.compactTitle.count == 28)
    }

    @Test func missingAuthorDoesNotCreateEmptyAuthorLine() {
        let (attributes, state) = makePayload(author: "   ")

        let presentation = ReadingSessionLiveActivityPresentation(attributes: attributes, state: state)

        #expect(presentation.authorText == nil)
        #expect(presentation.title == "Testbuch")
    }

    @Test func missingPageCountCanStillDescribeReadPages() {
        let (attributes, state) = makePayload(pageCount: nil, pagesRead: 18, remainingPages: nil, progressFraction: nil)

        let presentation = ReadingSessionLiveActivityPresentation(attributes: attributes, state: state)

        #expect(presentation.hasProgress)
        #expect(presentation.progressText == nil)
        #expect(presentation.progressDetailText == "18 Seiten gelesen")
        #expect(presentation.remainingPagesText == nil)
        #expect(presentation.progressAccessibilityLabel == "Fortschritt: 18 Seiten gelesen")
    }

    @Test func coverAccessibilityUsesPlaceholderWhenStoredCoverIsMissing() {
        let (attributes, state) = makePayload()

        let presentation = ReadingSessionLiveActivityPresentation(attributes: attributes, state: state)

        #expect(!presentation.hasStoredCover)
        #expect(presentation.coverAccessibilityLabel == "Cover-Platzhalter für Testbuch")
    }

    @Test func coverAccessibilityUsesCoverLabelWhenStoredCoverIsAvailable() {
        let snapshot = ReadingSessionLiveActivitySnapshot(
            bookID: UUID(),
            bookTitle: "Cover Book",
            hasCover: true
        )
        let attributes = ReadingSessionActivityAttributes(snapshot: snapshot)
        let state = ReadingSessionActivityAttributes.ContentState(
            isPaused: false,
            effectiveStartDate: Date(timeIntervalSince1970: 3_200),
            pausedElapsedSeconds: 0,
            snapshot: snapshot
        )

        let presentation = ReadingSessionLiveActivityPresentation(attributes: attributes, state: state)

        #expect(presentation.hasStoredCover)
        #expect(presentation.coverAccessibilityLabel == "Cover von Cover Book")
    }

    @Test func presentationClampsInvalidProgressValuesForDefensiveRendering() {
        let snapshot = ReadingSessionLiveActivitySnapshot(
            bookID: UUID(),
            bookTitle: "Invalid Progress",
            pageCount: -20,
            pagesRead: -4,
            remainingPages: -12,
            progressFraction: 1.4,
            challengeProgressFraction: .nan,
            hasCover: false
        )
        let attributes = ReadingSessionActivityAttributes(snapshot: snapshot)
        let state = ReadingSessionActivityAttributes.ContentState(
            isPaused: false,
            effectiveStartDate: Date(timeIntervalSince1970: 3_400),
            pausedElapsedSeconds: 0,
            snapshot: snapshot
        )

        let presentation = ReadingSessionLiveActivityPresentation(attributes: attributes, state: state)

        #expect(presentation.progressFraction == 1.0)
        #expect(presentation.progressText == "100 % gelesen")
        #expect(presentation.challengeProgressFraction == nil)
    }

    @Test func percentageProgressUsesPercentWithoutPageDetail() {
        let snapshot = ReadingSessionLiveActivitySnapshot(
            bookID: UUID(),
            bookTitle: "Percent",
            progressFraction: 0.57,
            readingMedium: .ebook,
            readingProvider: .kindle,
            progressUnit: .percentage,
            origin: .timer,
            totalValue: 100,
            hasCover: false
        )
        let attributes = ReadingSessionActivityAttributes(snapshot: snapshot)
        let state = ReadingSessionActivityAttributes.ContentState(
            isPaused: false,
            effectiveStartDate: Date(timeIntervalSince1970: 4_000),
            pausedElapsedSeconds: 0,
            snapshot: snapshot
        )

        let presentation = ReadingSessionLiveActivityPresentation(attributes: attributes, state: state)

        #expect(presentation.sourceText == "Kindle")
        #expect(presentation.progressText == "57 % gelesen")
        #expect(presentation.compactProgressText == "57 %")
        #expect(presentation.progressDetailText == "Prozentstand")
        #expect(presentation.remainingPagesText == nil)
        #expect(abs((presentation.progressFraction ?? 0) - 0.57) < 0.0001)
    }

    @Test func locatorWithoutPercentShowsPositionWithoutArtificialProgress() {
        let snapshot = ReadingSessionLiveActivitySnapshot(
            bookID: UUID(),
            bookTitle: "Locator",
            locator: "Kapitel 4, Abschnitt 2",
            readingMedium: .ebook,
            readingProvider: .localFile,
            progressUnit: .locator,
            origin: .integratedReader,
            hasCover: false
        )
        let attributes = ReadingSessionActivityAttributes(snapshot: snapshot)
        let state = ReadingSessionActivityAttributes.ContentState(
            isPaused: false,
            effectiveStartDate: Date(timeIntervalSince1970: 4_100),
            pausedElapsedSeconds: 0,
            snapshot: snapshot
        )

        let presentation = ReadingSessionLiveActivityPresentation(attributes: attributes, state: state)

        #expect(presentation.sourceText == "Lokale Datei")
        #expect(presentation.progressText == nil)
        #expect(presentation.compactProgressText == nil)
        #expect(presentation.progressFraction == nil)
        #expect(presentation.progressDetailText == "Position: Kapitel 4, Abschnitt 2")
        #expect(presentation.progressAccessibilityLabel == "Fortschritt: Position: Kapitel 4, Abschnitt 2")
    }

    @Test func noProgressUnitSuppressesProgressPresentation() {
        let snapshot = ReadingSessionLiveActivitySnapshot(
            bookID: UUID(),
            bookTitle: "None",
            progressFraction: 0.9,
            readingMedium: .ebook,
            readingProvider: .other,
            progressUnit: .none,
            origin: .timer,
            hasCover: false
        )
        let attributes = ReadingSessionActivityAttributes(snapshot: snapshot)
        let state = ReadingSessionActivityAttributes.ContentState(
            isPaused: false,
            effectiveStartDate: Date(timeIntervalSince1970: 4_200),
            pausedElapsedSeconds: 0,
            snapshot: snapshot
        )

        let presentation = ReadingSessionLiveActivityPresentation(attributes: attributes, state: state)

        #expect(presentation.sourceText == "E-Book-App")
        #expect(!presentation.hasProgress)
        #expect(presentation.progressText == nil)
        #expect(presentation.compactProgressText == nil)
        #expect(presentation.progressFraction == nil)
        #expect(presentation.progressDetailText == nil)
    }

    private func makePayload(
        title: String = "Testbuch",
        author: String? = "Autorin",
        pageCount: Int? = 200,
        pagesRead: Int? = 80,
        remainingPages: Int? = 120,
        progressFraction: Double? = 0.4,
        isPaused: Bool = false
    ) -> (ReadingSessionActivityAttributes, ReadingSessionActivityAttributes.ContentState) {
        let snapshot = ReadingSessionLiveActivitySnapshot(
            bookID: UUID(),
            bookTitle: title,
            bookAuthor: author,
            pageCount: pageCount,
            pagesRead: pagesRead,
            remainingPages: remainingPages,
            progressFraction: progressFraction,
            stateLabel: isPaused ? ReadingSessionLiveActivitySnapshot.pausedStateLabel : ReadingSessionLiveActivitySnapshot.runningStateLabel,
            hasCover: false,
            accentHex: "#FF9500"
        )
        let attributes = ReadingSessionActivityAttributes(snapshot: snapshot)
        let state = ReadingSessionActivityAttributes.ContentState(
            isPaused: isPaused,
            effectiveStartDate: Date(timeIntervalSince1970: 3_000),
            pausedElapsedSeconds: isPaused ? 540 : 0,
            snapshot: snapshot
        )

        return (attributes, state)
    }
}
