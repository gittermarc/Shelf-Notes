//
//  LibraryOverviewWidgetView.swift
//  ShelfNotesLiveActivity
//
//  SwiftUI dashboard UI for the Library Overview widget.
//

import SwiftUI
import UIKit
import WidgetKit

struct LibraryOverviewWidgetView: View {
    let entry: LibraryOverviewWidgetEntry

    @Environment(\.widgetFamily) private var family

    private var presentation: LibraryOverviewWidgetPresentation {
        entry.presentation
    }

    private var layout: LibraryOverviewWidgetLayout {
        family == .systemExtraLarge ? .expanded : .large
    }

    private var isExpandedFamily: Bool {
        layout == .expanded
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LibraryOverviewWidgetTheme.glow
                .offset(x: isExpandedFamily ? 58 : 46, y: isExpandedFamily ? -78 : -86)

            VStack(alignment: .leading, spacing: layout.sectionSpacing) {
                header
                metricsRow
                currentBookSection
                lowerSection

                if isExpandedFamily, !presentation.shelfItems.isEmpty {
                    shelfSection
                }
            }
            .padding(layout.outerPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .containerBackground(for: .widget) {
            LibraryOverviewWidgetTheme.background
        }
        .widgetURL(LibraryOverviewWidgetDeepLinkURL.library)
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Label("Shelf Notes", systemImage: "books.vertical.fill")
                    .font(.system(size: layout.eyebrowFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(LibraryOverviewWidgetTheme.accent)
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)

                Text("Dein Regal")
                    .font(.system(size: layout.titleFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(LibraryOverviewWidgetTheme.ink)
                    .lineLimit(1)

                Text(presentation.heroSubtitle)
                    .font(.system(size: layout.captionFontSize, weight: .medium, design: .rounded))
                    .foregroundStyle(LibraryOverviewWidgetTheme.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(presentation.snapshot.totalBooks)")
                    .font(.system(size: layout.heroNumberFontSize, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(LibraryOverviewWidgetTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.66)

                Text(presentation.snapshot.totalBooks == 1 ? "Buch" : "Bücher")
                    .font(.system(size: layout.captionFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(LibraryOverviewWidgetTheme.inkSubtle)
                    .lineLimit(1)
            }
        }
    }

    private var metricsRow: some View {
        HStack(spacing: layout.tileSpacing) {
            ForEach(presentation.metrics) { metric in
                LibraryOverviewMetricTile(metric: metric, layout: layout)
            }
        }
    }

    private var currentBookSection: some View {
        Group {
            if let destination = currentBookDestination {
                Link(destination: destination) {
                    currentBookCard
                }
                .buttonStyle(.plain)
            } else {
                currentBookCard
            }
        }
    }

    private var currentBookCard: some View {
        HStack(alignment: .center, spacing: layout.currentCardSpacing) {
            currentCover

            VStack(alignment: .leading, spacing: layout.currentTextSpacing) {
                Text(currentCaption)
                    .font(.system(size: layout.microFontSize, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(0.28)
                    .foregroundStyle(LibraryOverviewWidgetTheme.accent)
                    .lineLimit(1)

                Text(presentation.currentTitle)
                    .font(.system(size: layout.currentTitleFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(LibraryOverviewWidgetTheme.ink)
                    .lineLimit(isExpandedFamily ? 2 : 1)
                    .minimumScaleFactor(0.72)

                Text(presentation.currentDetail)
                    .font(.system(size: layout.captionFontSize, weight: .medium, design: .rounded))
                    .foregroundStyle(LibraryOverviewWidgetTheme.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                if let progress = presentation.currentProgressFraction {
                    ProgressView(value: progress)
                        .tint(LibraryOverviewWidgetTheme.accent)
                        .scaleEffect(x: 1, y: 0.70, anchor: .center)
                        .accessibilityLabel("Lesefortschritt")
                }

                if let progressText = presentation.currentProgressText {
                    Text(progressText)
                        .font(.system(size: layout.microFontSize, weight: .medium, design: .rounded))
                        .foregroundStyle(LibraryOverviewWidgetTheme.inkSubtle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(layout.cardPadding)
        .background(LibraryOverviewWidgetTheme.tileFill, in: RoundedRectangle(cornerRadius: layout.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: layout.cardCornerRadius, style: .continuous)
                .stroke(LibraryOverviewWidgetTheme.stroke, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var currentCover: some View {
        if let currentBook = presentation.snapshot.currentBook,
           currentBook.hasCover,
           presentation.showsCovers {
            LibraryOverviewCoverView(book: currentBook, size: layout.currentCoverSize)
        } else {
            LibraryOverviewPlaceholderCover(
                title: presentation.currentTitle,
                size: layout.currentCoverSize
            )
        }
    }

    private var lowerSection: some View {
        HStack(spacing: layout.tileSpacing) {
            if let progressURL = LibraryOverviewWidgetDeepLinkURL.progress {
                Link(destination: progressURL) {
                    LibraryOverviewInfoCard(
                        title: presentation.goalTitle,
                        detail: presentation.goalDetail,
                        symbolName: "target",
                        progress: presentation.goalProgressFraction,
                        layout: layout
                    )
                }
                .buttonStyle(.plain)
            } else {
                LibraryOverviewInfoCard(
                    title: presentation.goalTitle,
                    detail: presentation.goalDetail,
                    symbolName: "target",
                    progress: presentation.goalProgressFraction,
                    layout: layout
                )
            }

            LibraryOverviewInfoCard(
                title: "Letzte 7 Tage",
                detail: presentation.activityDetail,
                symbolName: "chart.line.uptrend.xyaxis",
                progress: nil,
                layout: layout
            )
        }
    }

    private var shelfSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 11, weight: .bold))
                Text("Kleiner Blick ins Regal")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                Spacer(minLength: 0)
                if presentation.isStale {
                    Text("älter")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(LibraryOverviewWidgetTheme.accentSoft, in: Capsule())
                }
            }
            .foregroundStyle(LibraryOverviewWidgetTheme.inkMuted)

            HStack(spacing: 8) {
                ForEach(presentation.shelfItems) { item in
                    if item.hasCover, presentation.showsCovers {
                        LibraryOverviewCoverView(book: item, size: .small)
                    } else {
                        LibraryOverviewPlaceholderCover(title: item.title, size: .small)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var currentDestination: URL? {
        guard !presentation.usesReducedMode else { return LibraryOverviewWidgetDeepLinkURL.library }
        guard let currentBook = presentation.snapshot.currentBook else { return LibraryOverviewWidgetDeepLinkURL.library }
        return LibraryOverviewWidgetDeepLinkURL.book(id: currentBook.id) ?? LibraryOverviewWidgetDeepLinkURL.library
    }

    private var currentBookDestination: URL? {
        currentDestination
    }

    private var currentCaption: String {
        if presentation.isSnapshotUnavailable {
            return "Widget bereit"
        }

        if presentation.usesReducedMode {
            return "Privat"
        }

        if presentation.snapshot.currentBook == nil {
            return "Aktuell"
        }

        return "Gerade liest du"
    }
}

private struct LibraryOverviewMetricTile: View {
    let metric: LibraryOverviewWidgetPresentation.Metric
    let layout: LibraryOverviewWidgetLayout

    var body: some View {
        VStack(alignment: .leading, spacing: layout.metricSpacing) {
            HStack(spacing: 4) {
                Image(systemName: metric.symbolName)
                    .font(.system(size: layout.metricIconFontSize, weight: .bold))
                    .foregroundStyle(LibraryOverviewWidgetTheme.accent)

                Text(metric.title)
                    .font(.system(size: layout.microFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(LibraryOverviewWidgetTheme.inkSubtle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.66)
            }

            Text(metric.value)
                .font(.system(size: layout.metricValueFontSize, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(LibraryOverviewWidgetTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, layout.metricHorizontalPadding)
        .padding(.vertical, layout.metricVerticalPadding)
        .background(LibraryOverviewWidgetTheme.tileFill, in: RoundedRectangle(cornerRadius: layout.tileCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: layout.tileCornerRadius, style: .continuous)
                .stroke(LibraryOverviewWidgetTheme.stroke, lineWidth: 1)
        }
    }
}

private struct LibraryOverviewInfoCard: View {
    let title: String
    let detail: String
    let symbolName: String
    let progress: Double?
    let layout: LibraryOverviewWidgetLayout

    var body: some View {
        VStack(alignment: .leading, spacing: layout.infoCardSpacing) {
            HStack(spacing: 5) {
                Image(systemName: symbolName)
                    .font(.system(size: layout.infoIconFontSize, weight: .bold))
                    .foregroundStyle(LibraryOverviewWidgetTheme.accent)

                Text(title)
                    .font(.system(size: layout.microFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(LibraryOverviewWidgetTheme.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.66)
            }

            Text(detail)
                .font(.system(size: layout.infoDetailFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(LibraryOverviewWidgetTheme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.68)

            if let progress {
                ProgressView(value: progress)
                    .tint(LibraryOverviewWidgetTheme.accent)
                    .scaleEffect(x: 1, y: 0.68, anchor: .center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: layout.infoCardMinHeight, alignment: .topLeading)
        .padding(layout.infoCardPadding)
        .background(LibraryOverviewWidgetTheme.tileFill, in: RoundedRectangle(cornerRadius: layout.tileCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: layout.tileCornerRadius, style: .continuous)
                .stroke(LibraryOverviewWidgetTheme.stroke, lineWidth: 1)
        }
    }
}

private struct LibraryOverviewCoverView: View {
    let book: LibraryOverviewBookSnapshot
    let size: LibraryOverviewCoverSize

    var body: some View {
        if let image = LibraryOverviewWidgetCoverLoader.load(bookID: book.id) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.22), radius: 7, x: 0, y: 4)
        } else {
            LibraryOverviewPlaceholderCover(title: book.title, size: size)
        }
    }
}

private struct LibraryOverviewPlaceholderCover: View {
    let title: String
    let size: LibraryOverviewCoverSize

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            LibraryOverviewWidgetTheme.accent.opacity(0.32),
                            Color.white.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 3) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: size.iconSize, weight: .bold))
                Text(initial)
                    .font(.system(size: size.initialSize, weight: .black, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(LibraryOverviewWidgetTheme.ink)
        }
        .frame(width: size.width, height: size.height)
        .overlay {
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .stroke(LibraryOverviewWidgetTheme.stroke, lineWidth: 1)
        }
    }

    private var initial: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "B" }
        return String(first).uppercased()
    }
}

private enum LibraryOverviewWidgetLayout: Equatable {
    case large
    case expanded

    var outerPadding: CGFloat {
        switch self {
        case .large: 12
        case .expanded: 18
        }
    }

    var sectionSpacing: CGFloat {
        switch self {
        case .large: 7
        case .expanded: 13
        }
    }

    var tileSpacing: CGFloat {
        switch self {
        case .large: 7
        case .expanded: 8
        }
    }

    var eyebrowFontSize: CGFloat {
        switch self {
        case .large: 11
        case .expanded: 12
        }
    }

    var titleFontSize: CGFloat {
        switch self {
        case .large: 18
        case .expanded: 23
        }
    }

    var captionFontSize: CGFloat {
        switch self {
        case .large: 10
        case .expanded: 11
        }
    }

    var microFontSize: CGFloat {
        switch self {
        case .large: 9
        case .expanded: 10
        }
    }

    var heroNumberFontSize: CGFloat {
        switch self {
        case .large: 28
        case .expanded: 38
        }
    }

    var metricSpacing: CGFloat {
        switch self {
        case .large: 3
        case .expanded: 5
        }
    }

    var metricIconFontSize: CGFloat {
        switch self {
        case .large: 9
        case .expanded: 10
        }
    }

    var metricValueFontSize: CGFloat {
        switch self {
        case .large: 18
        case .expanded: 21
        }
    }

    var metricHorizontalPadding: CGFloat {
        switch self {
        case .large: 8
        case .expanded: 9
        }
    }

    var metricVerticalPadding: CGFloat {
        switch self {
        case .large: 6
        case .expanded: 8
        }
    }

    var currentCardSpacing: CGFloat {
        switch self {
        case .large: 8
        case .expanded: 10
        }
    }

    var currentTextSpacing: CGFloat {
        switch self {
        case .large: 3
        case .expanded: 5
        }
    }

    var currentTitleFontSize: CGFloat {
        switch self {
        case .large: 12
        case .expanded: 15
        }
    }

    var cardPadding: CGFloat {
        switch self {
        case .large: 8
        case .expanded: 10
        }
    }

    var cardCornerRadius: CGFloat {
        switch self {
        case .large: 16
        case .expanded: 18
        }
    }

    var tileCornerRadius: CGFloat {
        switch self {
        case .large: 14
        case .expanded: 16
        }
    }

    var infoCardSpacing: CGFloat {
        switch self {
        case .large: 4
        case .expanded: 6
        }
    }

    var infoIconFontSize: CGFloat {
        switch self {
        case .large: 10
        case .expanded: 11
        }
    }

    var infoDetailFontSize: CGFloat {
        switch self {
        case .large: 10
        case .expanded: 11
        }
    }

    var infoCardPadding: CGFloat {
        switch self {
        case .large: 7
        case .expanded: 9
        }
    }

    var infoCardMinHeight: CGFloat {
        switch self {
        case .large: 54
        case .expanded: 62
        }
    }

    var currentCoverSize: LibraryOverviewCoverSize {
        switch self {
        case .large: .medium
        case .expanded: .large
        }
    }
}

private enum LibraryOverviewCoverSize {
    case small
    case medium
    case large

    var width: CGFloat {
        switch self {
        case .small: 36
        case .medium: 44
        case .large: 58
        }
    }

    var height: CGFloat {
        switch self {
        case .small: 51
        case .medium: 62
        case .large: 84
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .small: 8
        case .medium: 10
        case .large: 13
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .small: 10
        case .medium: 12
        case .large: 15
        }
    }

    var initialSize: CGFloat {
        switch self {
        case .small: 12
        case .medium: 15
        case .large: 18
        }
    }
}
