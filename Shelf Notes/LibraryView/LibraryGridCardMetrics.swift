import CoreGraphics
import SwiftUI

struct LibraryGridCardMetrics {
    let itemWidth: CGFloat
    let rowContentSpacing: Double
    let showsCover: Bool
    let coverSizeOption: LibraryCoverSizeOption

    private let verticalPadding: CGFloat = 10
    private let minimumContentSpacing: CGFloat = 4
    private let titleSlotHeight: CGFloat = 38
    private let detailSlotHeight: CGFloat = 16

    var cardCornerRadius: CGFloat {
        16
    }

    var horizontalPadding: CGFloat {
        coverSizeOption.gridCardHorizontalPadding
    }

    var contentSpacing: CGFloat {
        max(minimumContentSpacing, CGFloat(rowContentSpacing))
    }

    var contentWidth: CGFloat {
        max(0, itemWidth - (horizontalPadding * 2))
    }

    var coverWidth: CGFloat {
        max(0, contentWidth * coverSizeOption.gridCoverWidthScale)
    }

    var coverSize: CGSize {
        CGSize(width: coverWidth, height: coverWidth * 1.5)
    }

    var infoBlockHeight: CGFloat {
        titleSlotHeight + (detailSlotHeight * 3) + (contentSpacing * 3)
    }

    var cardHeight: CGFloat {
        let coverBlockHeight = showsCover ? (coverSize.height + contentSpacing) : 0
        return (verticalPadding * 2) + coverBlockHeight + infoBlockHeight
    }

    var padding: EdgeInsets {
        EdgeInsets(
            top: verticalPadding,
            leading: horizontalPadding,
            bottom: verticalPadding,
            trailing: horizontalPadding
        )
    }

    var reservedTitleHeight: CGFloat {
        titleSlotHeight
    }

    var reservedDetailHeight: CGFloat {
        detailSlotHeight
    }
}
