import Testing
@testable import Shelf_Notes

struct ReadingProgressPresentationTests {
    @Test func physicalProgressShowsPagesRemainingAndPercentage() {
        let presentation = ReadingProgressPresentationBuilder.make(
            snapshot: ReadingProgressSnapshot(
                unit: .pages,
                nativeValue: 154,
                totalValue: 384,
                pagesRead: 154,
                remainingPages: 230,
                normalizedProgress: 154.0 / 384.0,
                locator: nil,
                isCompleted: false
            ),
            medium: .physical,
            provider: .none,
            status: .reading
        )

        #expect(presentation.source.title == "Physisches Buch")
        #expect(presentation.percentText == "40%")
        #expect(presentation.detailText == "154 / 384 Seiten · noch 230")
        #expect(presentation.canEditPageCount)
    }

    @Test func kindleProgressShowsPercentageWithoutArtificialPages() {
        let presentation = ReadingProgressPresentationBuilder.make(
            snapshot: ReadingProgressSnapshot(
                unit: .percentage,
                nativeValue: 40,
                totalValue: 100,
                pagesRead: nil,
                remainingPages: nil,
                normalizedProgress: 0.4,
                locator: nil,
                isCompleted: false
            ),
            medium: .ebook,
            provider: .kindle,
            status: .reading
        )

        #expect(presentation.source.title == "Kindle")
        #expect(presentation.detailText == "Aktueller Lesestand 40%")
        #expect(presentation.detailText.contains("Seiten") == false)
        #expect(presentation.supportingText == "Fortschritt manuell gepflegt")
        #expect(presentation.canEditPageCount == false)
    }

    @Test func locatorWithoutPercentageKeepsProgressUnknown() {
        let presentation = ReadingProgressPresentationBuilder.make(
            snapshot: ReadingProgressSnapshot(
                unit: .locator,
                nativeValue: 0,
                totalValue: nil,
                pagesRead: nil,
                remainingPages: nil,
                normalizedProgress: nil,
                locator: "Kapitel 12",
                isCompleted: false
            ),
            medium: .ebook,
            provider: .other,
            status: .reading
        )

        #expect(presentation.percentText == "—")
        #expect(presentation.detailText == "Leseposition: Kapitel 12")
        #expect(presentation.supportingText == "Prozentwert nicht verfügbar")
        #expect(presentation.normalizedProgress == nil)
    }

    @Test func localFilePlaceholderDoesNotClaimReaderAvailability() {
        let presentation = ReadingProgressPresentationBuilder.make(
            snapshot: .unknown(unit: .locator),
            medium: .ebook,
            provider: .localFile,
            status: .reading
        )

        #expect(presentation.detailText == "Fortschritt noch nicht automatisch verfügbar")
        #expect(presentation.supportingText?.contains("folgt") == true)
        #expect(presentation.normalizedProgress == nil)
    }
}
