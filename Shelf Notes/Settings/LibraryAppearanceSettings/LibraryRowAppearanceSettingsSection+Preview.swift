import SwiftUI

struct LibraryRowAppearanceSettingsPreviewSection: View {
    let showCovers: Bool
    let coverSize: CGSize
    let coverCornerRadius: CGFloat
    let contentMode: ContentMode
    let coverShadowEnabled: Bool
    let showAuthor: Bool
    let showStatus: Bool
    let showReadDate: Bool
    let showRating: Bool
    let showTags: Bool
    let tagStyle: LibraryTagStyleOption
    let maxTags: Int
    let rowContentSpacing: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Vorschau")
                .font(.caption)
                .foregroundStyle(.secondary)

            LibraryRowSettingsPreview(
                showCovers: showCovers,
                coverSize: coverSize,
                coverCornerRadius: coverCornerRadius,
                contentMode: contentMode,
                coverShadowEnabled: coverShadowEnabled,
                showAuthor: showAuthor,
                showStatus: showStatus,
                showReadDate: showReadDate,
                showRating: showRating,
                showTags: showTags,
                tagStyle: tagStyle,
                maxTags: maxTags,
                rowContentSpacing: rowContentSpacing
            )
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.thinMaterial)
            )
        }
        .padding(.top, 4)
    }
}

private struct LibraryRowSettingsPreview: View {
    let showCovers: Bool
    let coverSize: CGSize
    let coverCornerRadius: CGFloat
    let contentMode: ContentMode
    let coverShadowEnabled: Bool
    let showAuthor: Bool
    let showStatus: Bool
    let showReadDate: Bool
    let showRating: Bool
    let showTags: Bool
    let tagStyle: LibraryTagStyleOption
    let maxTags: Int
    let rowContentSpacing: Double

    private enum MetaPart {
        case status(String)
        case readDate(String)
        case rating(Double)
    }

    private var metaParts: [MetaPart] {
        var parts: [MetaPart] = []
        if showStatus { parts.append(.status("Gelesen")) }
        if showReadDate { parts.append(.readDate("Jan 2026")) }
        if showRating { parts.append(.rating(4.2)) }
        return parts
    }

    private var tagsText: String {
        let tags = ["thriller", "nyc", "crime", "biografie"]
        let count = max(1, min(maxTags, tags.count))
        return tags.prefix(count).map { "#\($0)" }.joined(separator: " ")
    }

    private var tagsList: [String] {
        let tags = ["thriller", "nyc", "crime", "biografie"]
        let count = max(1, min(maxTags, tags.count))
        return Array(tags.prefix(count))
    }

    private var tagsRemainingCount: Int {
        max(0, ["thriller", "nyc", "crime", "biografie"].count - tagsList.count)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if showCovers {
                cover
            }

            VStack(alignment: .leading, spacing: CGFloat(rowContentSpacing)) {
                Text("Beispielbuch")
                    .font(.headline)

                if showAuthor {
                    Text("Max Mustermann")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !metaParts.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(metaParts.enumerated()), id: \.offset) { index, part in
                            if index > 0 {
                                Text("•")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            switch part {
                            case .status(let text):
                                Text(text)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            case .readDate(let text):
                                Text(text)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            case .rating(let value):
                                HStack(spacing: 4) {
                                    StarsView(rating: value)
                                    Text(String(format: "%.1f", value))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                }

                if showTags {
                    switch tagStyle {
                    case .hashtags:
                        Text(tagsText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .chips:
                        TagPillsRow(tags: tagsList, remainingCount: tagsRemainingCount)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var cover: some View {
        ZStack {
            RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous)
                .fill(.secondary.opacity(0.18))

            Image(systemName: "book.closed")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(width: coverSize.width, height: coverSize.height)
        .clipShape(RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous))
        .aspectRatio(contentMode: contentMode)
        .shadow(
            color: coverShadowEnabled ? .black.opacity(0.12) : .clear,
            radius: coverShadowEnabled ? 4 : 0,
            x: 0,
            y: coverShadowEnabled ? 2 : 0
        )
    }
}
