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

    private var isExpandedFamily: Bool {
        family == .systemExtraLarge
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LibraryOverviewWidgetTheme.glow
                .offset(x: 58, y: -78)

            VStack(alignment: .leading, spacing: isExpandedFamily ? 14 : 10) {
                header
                metricsRow
                currentBookSection
                lowerSection

                if isExpandedFamily || !presentation.shelfItems.isEmpty {
                    shelfSection
                }
            }
            .padding(isExpandedFamily ? 18 : 14)
        }
        .containerBackground(for: .widget) {
            LibraryOverviewWidgetTheme.background
        }
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Shelf Notes", systemImage: "books.vertical.fill")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(LibraryOverviewWidgetTheme.accent)
                    .labelStyle(.titleAndIcon)

                Text("Dein Regal")
                    .font(.system(size: isExpandedFamily ? 23 : 20, weight: .bold, design: .rounded))
                    .foregroundStyle(LibraryOverviewWidgetTheme.ink)
                    .lineLimit(1)

                Text(presentation.heroSubtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(LibraryOverviewWidgetTheme.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(presentation.snapshot.totalBooks)")
                    .font(.system(size: isExpandedFamily ? 38 : 31, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(LibraryOverviewWidgetTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(presentation.snapshot.totalBooks == 1 ? "Buch" : "Bücher")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(LibraryOverviewWidgetTheme.inkSubtle)
                    .lineLimit(1)
            }
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 8) {
            ForEach(presentation.metrics) { metric in
                LibraryOverviewMetricTile(metric: metric)
            }
        }
    }

    private var currentBookSection: some View {
        HStack(alignment: .center, spacing: 10) {
            if let currentBook = presentation.snapshot.currentBook, currentBook.hasCover {
                LibraryOverviewCoverView(book: currentBook, size: isExpandedFamily ? .large : .medium)
            } else {
                LibraryOverviewPlaceholderCover(
                    title: presentation.currentTitle,
                    size: isExpandedFamily ? .large : .medium
                )
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(currentCaption)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(0.35)
                    .foregroundStyle(LibraryOverviewWidgetTheme.accent)
                    .lineLimit(1)

                Text(presentation.currentTitle)
                    .font(.system(size: isExpandedFamily ? 15 : 13, weight: .bold, design: .rounded))
                    .foregroundStyle(LibraryOverviewWidgetTheme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.74)

                Text(presentation.currentDetail)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(LibraryOverviewWidgetTheme.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                if let progress = presentation.currentProgressFraction {
                    ProgressView(value: progress)
                        .tint(LibraryOverviewWidgetTheme.accent)
                        .scaleEffect(x: 1, y: 0.76, anchor: .center)
                        .accessibilityLabel("Lesefortschritt")
                }

                if let progressText = presentation.currentProgressText {
                    Text(progressText)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(LibraryOverviewWidgetTheme.inkSubtle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(LibraryOverviewWidgetTheme.tileFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(LibraryOverviewWidgetTheme.stroke, lineWidth: 1)
        }
    }

    private var lowerSection: some View {
        HStack(spacing: 8) {
            LibraryOverviewInfoCard(
                title: presentation.goalTitle,
                detail: presentation.goalDetail,
                symbolName: "target",
                progress: presentation.goalProgressFraction
            )

            LibraryOverviewInfoCard(
                title: "Letzte 7 Tage",
                detail: presentation.activityDetail,
                symbolName: "chart.line.uptrend.xyaxis",
                progress: nil
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

            if presentation.shelfItems.isEmpty {
                Text(shelfFallbackText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(LibraryOverviewWidgetTheme.inkSubtle)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
            } else {
                HStack(spacing: isExpandedFamily ? 8 : 6) {
                    ForEach(presentation.shelfItems) { item in
                        if item.hasCover {
                            LibraryOverviewCoverView(book: item, size: .small)
                        } else {
                            LibraryOverviewPlaceholderCover(title: item.title, size: .small)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var currentCaption: String {
        if presentation.isSnapshotUnavailable {
            return "Widget bereit"
        }

        if presentation.snapshot.currentBook == nil {
            return "Aktuell"
        }

        return "Gerade liest du"
    }

    private var shelfFallbackText: String {
        if presentation.isSnapshotUnavailable {
            return "Öffne die App einmal, damit Shelf Notes den Überblick vorbereitet."
        }

        return "Sobald du mehr Bücher hast, erscheinen hier deine letzten Highlights."
    }
}

private struct LibraryOverviewMetricTile: View {
    let metric: LibraryOverviewWidgetPresentation.Metric

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: metric.symbolName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(LibraryOverviewWidgetTheme.accent)

                Text(metric.title)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(LibraryOverviewWidgetTheme.inkSubtle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }

            Text(metric.value)
                .font(.system(size: 21, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(LibraryOverviewWidgetTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(LibraryOverviewWidgetTheme.tileFill, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(LibraryOverviewWidgetTheme.stroke, lineWidth: 1)
        }
    }
}

private struct LibraryOverviewInfoCard: View {
    let title: String
    let detail: String
    let symbolName: String
    let progress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: symbolName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(LibraryOverviewWidgetTheme.accent)

                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(LibraryOverviewWidgetTheme.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }

            Text(detail)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(LibraryOverviewWidgetTheme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.70)

            if let progress {
                ProgressView(value: progress)
                    .tint(LibraryOverviewWidgetTheme.accent)
                    .scaleEffect(x: 1, y: 0.72, anchor: .center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .topLeading)
        .padding(9)
        .background(LibraryOverviewWidgetTheme.tileFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
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
                .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 5)
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

            VStack(spacing: 4) {
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

private enum LibraryOverviewCoverSize {
    case small
    case medium
    case large

    var width: CGFloat {
        switch self {
        case .small: 38
        case .medium: 50
        case .large: 58
        }
    }

    var height: CGFloat {
        switch self {
        case .small: 54
        case .medium: 72
        case .large: 84
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .small: 8
        case .medium: 11
        case .large: 13
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .small: 10
        case .medium: 13
        case .large: 15
        }
    }

    var initialSize: CGFloat {
        switch self {
        case .small: 12
        case .medium: 16
        case .large: 18
        }
    }
}
