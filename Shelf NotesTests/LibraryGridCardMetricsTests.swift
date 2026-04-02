import CoreGraphics
import Testing
@testable import Shelf_Notes

struct LibraryGridCardMetricsTests {
    @Test func contentWidthSubtractsCardPaddingFromGridItemWidth() {
        let metrics = LibraryGridCardMetrics(
            itemWidth: 160,
            rowContentSpacing: 2,
            showsCover: true
        )

        #expect(metrics.contentWidth == CGFloat(140))
        #expect(metrics.coverSize.width == CGFloat(140))
        #expect(metrics.coverSize.height == CGFloat(210))
    }

    @Test func cardHeightUsesStableReservedSlotsForGridLayout() {
        let withCover = LibraryGridCardMetrics(
            itemWidth: 160,
            rowContentSpacing: 0,
            showsCover: true
        )
        let withoutCover = LibraryGridCardMetrics(
            itemWidth: 160,
            rowContentSpacing: 0,
            showsCover: false
        )

        #expect(withCover.contentSpacing == CGFloat(4))
        #expect(withCover.infoBlockHeight == CGFloat(98))
        #expect(withCover.cardHeight == CGFloat(332))
        #expect(withoutCover.cardHeight == CGFloat(118))
    }
}
