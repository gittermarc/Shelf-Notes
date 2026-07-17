import Testing
@testable import Shelf_Notes

struct ReadingSourceSelectionTests {
    @Test func sourceDraftsMapToStableDomainValues() {
        let physical = ReadingSourceDraft(selection: .physical)
        #expect(physical.medium == .physical)
        #expect(physical.provider == .none)
        #expect(physical.progressUnit == .pages)
        #expect(physical.totalValue(bookPageCount: 384) == 384)

        let kindle = ReadingSourceDraft(selection: .kindle)
        #expect(kindle.medium == .ebook)
        #expect(kindle.provider == .kindle)
        #expect(kindle.progressUnit == .percentage)
        #expect(kindle.totalValue(bookPageCount: 384) == 100)

        let local = ReadingSourceDraft(selection: .localFile)
        #expect(local.medium == .ebook)
        #expect(local.provider == .localFile)
        #expect(local.progressUnit == .locator)
        #expect(local.isAvailable == false)
        #expect(local.totalValue(bookPageCount: 384) == nil)
    }

    @Test func persistedSourcesResolveToExpectedSelections() {
        #expect(
            ReadingSourceSelection.resolved(
                medium: .physical,
                provider: .none,
                progressUnit: .pages
            ) == .physical
        )
        #expect(
            ReadingSourceSelection.resolved(
                medium: .ebook,
                provider: .appleBooks,
                progressUnit: .percentage
            ) == .appleBooks
        )
        #expect(
            ReadingSourceSelection.resolved(
                medium: .ebook,
                provider: .kindle,
                progressUnit: .percentage
            ) == .kindle
        )
        #expect(
            ReadingSourceSelection.resolved(
                medium: .ebook,
                provider: .googleBooks,
                progressUnit: .percentage
            ) == .googleBooks
        )
        #expect(
            ReadingSourceSelection.resolved(
                medium: .ebook,
                provider: .other,
                progressUnit: .percentage
            ) == .otherEbook
        )
        #expect(
            ReadingSourceSelection.resolved(
                medium: .ebook,
                provider: .localFile,
                progressUnit: .locator
            ) == .localFile
        )
    }
}
