import Foundation
import Testing
@testable import Shelf_Notes

struct ReadingSessionPresentationTests {
    @Test @MainActor func percentageSessionShowsProviderProgressAndManualOriginCompactly() {
        let session = ReadingSession(
            startedAt: Date(timeIntervalSince1970: 30_000),
            endedAt: Date(timeIntervalSince1970: 31_200),
            medium: .ebook,
            provider: .kindle,
            origin: .quickLog,
            progressUnit: .percentage,
            startValue: 25,
            endValue: 40,
            startNormalizedProgress: 0.25,
            endNormalizedProgress: 0.4
        )

        let presentation = ReadingSessionPresentationBuilder.make(session: session)

        #expect(presentation.primaryLine.contains("20 Min."))
        #expect(presentation.metadataLine == "Lesestand 40 % · Kindle · Quick-Log")
        #expect(presentation.note == nil)
    }

    @Test @MainActor func locatorSessionDoesNotInventPercentage() {
        let session = ReadingSession(
            startedAt: Date(timeIntervalSince1970: 32_000),
            endedAt: Date(timeIntervalSince1970: 32_600),
            note: "Spannendes Kapitel",
            medium: .ebook,
            provider: .other,
            origin: .timer,
            progressUnit: .locator,
            endLocator: "Kapitel 9"
        )

        let presentation = ReadingSessionPresentationBuilder.make(session: session)

        #expect(presentation.metadataLine == "Kapitel 9 · Andere E-Book-App")
        #expect(presentation.metadataLine.contains("%") == false)
        #expect(presentation.note == "Spannendes Kapitel")
    }
}
