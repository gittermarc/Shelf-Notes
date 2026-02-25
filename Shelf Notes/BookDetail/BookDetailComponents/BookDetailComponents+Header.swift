import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Scroll / NavBar Helpers

struct HeaderMinYPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Header / Hero

struct BookHeroHeaderParallax: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var book: Book
    let hasUserRating: Bool
    let displayedOverallRating: Double?
    let displayedOverallText: String

    let baseHeight: CGFloat
    let coordinateSpaceName: String

    var body: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .named(coordinateSpaceName)).minY
            let stretch = max(minY, 0)
            let height = baseHeight + stretch

            ZStack(alignment: .bottomLeading) {
                // Background: big cover + blur + gradient
                LibraryRowCoverView(
                    book: book,
                    size: CGSize(width: geo.size.width, height: height),
                    cornerRadius: 0,
                    contentMode: .fill,
                    prefersHighResCover: true
                )
                .frame(width: geo.size.width, height: height)
                .clipped() // keep blur bounds predictable
                .blur(radius: 18)
                .scaleEffect(stretch > 0 ? (1.0 + (stretch / 700.0)) : 1.0)
                .overlay(
                    LinearGradient(
                        colors: [
                            .black.opacity(0.35),
                            .black.opacity(0.10),
                            .black.opacity(0.55)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .offset(y: stretch > 0 ? -stretch : 0) // keep top anchored while stretching

                // Foreground content
                HStack(alignment: .bottom, spacing: 14) {
                    LibraryRowCoverView(
                        book: book,
                        size: CGSize(width: 120, height: 180),
                        cornerRadius: 16,
                        contentMode: .fit,
                        prefersHighResCover: true
                    )
                    .shadow(radius: 12, y: 6)
                    .offset(y: stretch > 0 ? (-stretch * 0.15) : 0) // subtle parallax

                    VStack(alignment: .leading, spacing: 8) {
                        Text(book.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Ohne Titel" : book.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(3)

                        let a = book.author.trimmingCharacters(in: .whitespacesAndNewlines)
                        Text(a.isEmpty ? "—" : a)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(2)

                        if let overall = displayedOverallRating {
                            HStack(spacing: 10) {
                                StarsView(rating: overall)

                                Text(displayedOverallText)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.85))
                                    .monospacedDigit()

                                if hasUserRating {
                                    Text("deins")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.9))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.white.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(14)
                .offset(y: stretch > 0 ? (-stretch * 0.10) : (minY < 0 ? (minY * 0.08) : 0)) // gentle parallax
            }
        }
        .frame(height: baseHeight)
        .task(id: book.id) {
            #if canImport(UIKit)
            // Keep the synced thumbnail healthy (used across the app), but prefer high-res for display.
            if let data = book.userCoverData {
                if CoverThumbnailer.isLowResSyncedThumbnail(data) {
                    await CoverThumbnailer.refreshSyncedThumbnailIfNeeded(
                        for: book,
                        resolvedURLString: book.thumbnailURL,
                        modelContext: modelContext
                    )
                }
            } else {
                await CoverThumbnailer.backfillThumbnailIfNeeded(for: book, modelContext: modelContext)
            }
            #endif
        }
    }
}

// MARK: - Bottom Action Bar

struct BottomActionBar: View {
    @Binding var status: ReadingStatus
    let onNote: () -> Void
    let onCollections: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Menu {
                Picker("Status", selection: $status) {
                    ForEach(ReadingStatus.allCases) { s in
                        Text(s.displayName).tag(s)
                    }
                }
            } label: {
                Label("Status", systemImage: "bookmark")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button(action: onNote) {
                Label("Notiz", systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button(action: onCollections) {
                Label("Liste", systemImage: "text.badge.plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(.primary.opacity(0.06)),
            alignment: .top
        )
    }
}

// MARK: - Quick Chips

struct QuickChipsRow: View {
    let overallRating: Double?
    let overallText: String
    let showsUserBadge: Bool

    let pageCount: Int?
    let publishedDate: String?
    let language: String?

    var body: some View {
        HStack(spacing: 8) {
            if overallRating != nil {
                Chip(text: overallText, systemImage: "star.fill")
            }

            if let pc = pageCount {
                Chip(text: "\(pc) S.", systemImage: "doc.plaintext")
            }

            if let y = publishedYear(publishedDate) {
                Chip(text: y, systemImage: "calendar")
            }

            if let lang = language?.trimmingCharacters(in: .whitespacesAndNewlines), !lang.isEmpty {
                Chip(text: lang.uppercased(), systemImage: "globe")
            }

            Spacer()
        }
    }

    private func publishedYear(_ s: String?) -> String? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        // Accept "YYYY" or "YYYY-MM-DD"
        if s.count >= 4 {
            let y = String(s.prefix(4))
            if Int(y) != nil { return y }
        }
        return nil
    }
}
