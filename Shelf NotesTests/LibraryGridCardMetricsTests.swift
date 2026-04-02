import CoreGraphics
import Testing
@testable import Shelf_Notes

struct LibraryGridCardMetricsTests {
    @Test func contentWidthAndCoverSizeReactToGridCoverPreference() {
        let small = LibraryGridCardMetrics(
            itemWidth: 160,
            rowContentSpacing: 2,
            showsCover: true,
            coverSizeOption: .small
        )
        let standard = LibraryGridCardMetrics(
            itemWidth: 160,
            rowContentSpacing: 2,
            showsCover: true,
            coverSizeOption: .standard
        )
        let large = LibraryGridCardMetrics(
            itemWidth: 160,
            rowContentSpacing: 2,
            showsCover: true,
            coverSizeOption: .large
        )

        #expect(small.contentWidth == CGFloat(136))
        #expect(standard.contentWidth == CGFloat(140))
        #expect(large.contentWidth == CGFloat(144))

        #expect(abs(small.coverSize.width - CGFloat(119.68)) < CGFloat(0.001))
        #expect(abs(standard.coverSize.width - CGFloat(131.6)) < CGFloat(0.001))
        #expect(large.coverSize.width == CGFloat(144))
        #expect(small.coverSize.height < standard.coverSize.height)
        #expect(standard.coverSize.height < large.coverSize.height)
    }

    @Test func cardHeightUsesStableReservedSlotsForGridLayout() {
        let withCover = LibraryGridCardMetrics(
            itemWidth: 160,
            rowContentSpacing: 0,
            showsCover: true,
            coverSizeOption: .standard
        )
        let withoutCover = LibraryGridCardMetrics(
            itemWidth: 160,
            rowContentSpacing: 0,
            showsCover: false,
            coverSizeOption: .standard
        )

        #expect(withCover.contentSpacing == CGFloat(4))
        #expect(withCover.infoBlockHeight == CGFloat(98))
        #expect(abs(withCover.cardHeight - CGFloat(319.4)) < CGFloat(0.001))
        #expect(withoutCover.cardHeight == CGFloat(118))
    }

    @Test func largerGridCoverPreferenceUsesLargerMinimumTileWidth() {
        let compactWidth: CGFloat = 360
        let regularWidth: CGFloat = 800

        #expect(LibraryCoverSizeOption.small.gridMinimumTileWidth(for: compactWidth) == CGFloat(130))
        #expect(LibraryCoverSizeOption.standard.gridMinimumTileWidth(for: compactWidth) == CGFloat(150))
        #expect(LibraryCoverSizeOption.large.gridMinimumTileWidth(for: compactWidth) == CGFloat(180))

        #expect(LibraryCoverSizeOption.small.gridMinimumTileWidth(for: regularWidth) == CGFloat(170))
        #expect(LibraryCoverSizeOption.standard.gridMinimumTileWidth(for: regularWidth) == CGFloat(190))
        #expect(LibraryCoverSizeOption.large.gridMinimumTileWidth(for: regularWidth) == CGFloat(220))
    }
}
