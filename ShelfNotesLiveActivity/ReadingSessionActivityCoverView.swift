//
//  ReadingSessionActivityCoverView.swift
//  ShelfNotesLiveActivity
//

import SwiftUI

enum ReadingSessionActivityCoverSize: Equatable {
    case lockScreen
    case dynamicIsland
    case compact

    var dimensions: CGSize {
        switch self {
        case .lockScreen:
            return CGSize(width: 70, height: 104)
        case .dynamicIsland:
            return CGSize(width: 38, height: 56)
        case .compact:
            return CGSize(width: 24, height: 24)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .lockScreen:
            return 16
        case .dynamicIsland:
            return 10
        case .compact:
            return 8
        }
    }

    var iconFont: Font {
        switch self {
        case .lockScreen:
            return .title2
        case .dynamicIsland:
            return .headline
        case .compact:
            return .caption
        }
    }
}

struct ReadingSessionActivityCoverView: View {
    let bookID: String
    let presentation: ReadingSessionLiveActivityPresentation
    let size: ReadingSessionActivityCoverSize

    private var dimensions: CGSize {
        size.dimensions
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .fill(ReadingSessionActivityTheme.softHighlight(accentHex: presentation.accentHex))

            if let uiImage = LiveActivityCoverLoader.load(bookIDString: bookID) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                VStack(spacing: size == .lockScreen ? 5 : 0) {
                    Image(systemName: "book.closed.fill")
                        .font(size.iconFont)
                        .foregroundStyle(.white.opacity(0.92))

                    if size == .lockScreen {
                        Text("Shelf")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.70))
                    }
                }
            }
        }
        .frame(width: dimensions.width, height: dimensions.height)
        .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(size == .lockScreen ? 0.24 : 0.10), radius: size == .lockScreen ? 8 : 2, x: 0, y: size == .lockScreen ? 5 : 1)
        .accessibilityLabel(presentation.coverAccessibilityLabel)
    }
}
