import SwiftUI
import SwiftData

#if canImport(PhotosUI)
import PhotosUI
#endif

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

#if canImport(PhotosUI)
struct PhotoPickerPresenter: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var selection: PhotosPickerItem?

    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .photosPicker(isPresented: $isPresented, selection: $selection, matching: .images)
        } else {
            // Fallback: PhotosPicker in a sheet for older iOS versions
            content
                .sheet(isPresented: $isPresented) {
                    PhotosPicker(selection: $selection, matching: .images) {
                        VStack(spacing: 12) {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                            Text("Fotos auswählen")
                                .font(.headline)
                        }
                        .padding(24)
                    }
                    .padding()
                }
        }
    }
}
#endif

// MARK: - Online Cover Picker Sheet

struct OnlineCoverPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let candidates: [String]
    let selectedURLString: String?
    let onSelect: (String) -> Void

    private var selectedNormalized: String {
        (selectedURLString ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Tippe ein Cover an, um es zu setzen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.top, 10)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 80), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(candidates, id: \.self) { s in
                            Button {
                                onSelect(s)
                                dismiss()
                            } label: {
                                CoverThumb(
                                    urlString: s,
                                    isSelected: selectedNormalized == s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 18)
                }
            }
            .navigationTitle("Online-Cover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Apple-Books-ish UI Components

struct BookHeroHeaderParallax: View {
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
                BookCoverThumbnailView(
                    book: book,
                    size: CGSize(width: geo.size.width, height: height),
                    cornerRadius: 22
                )
                .scaledToFill()
                .frame(width: geo.size.width, height: height)
                .clipped()
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
                    BookCoverThumbnailView(
                        book: book,
                        size: CGSize(width: 120, height: 180),
                        cornerRadius: 16
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
    }
}

struct BookDetailCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            content
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

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

struct Chip: View {
    let text: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial)
        .clipShape(Capsule())
    }
}

struct WrapChipsView: View {
    let chips: [String]
    var maxVisible: Int = 6

    var body: some View {
        let visible = Array(chips.prefix(maxVisible))
        let remaining = max(0, chips.count - visible.count)

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
            ForEach(visible, id: \.self) { c in
                Text(c)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
            }

            if remaining > 0 {
                Text("+\(remaining)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Sheets

struct NotesEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var notes: String
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextEditor(text: $notes)
                    .padding(12)
            }
            .navigationTitle("Notiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct CollectionsPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let allCollections: [BookCollection]
    let membershipBinding: (BookCollection) -> Binding<Bool>
    let onCreateNew: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if allCollections.isEmpty {
                    Text("Noch keine Listen.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(allCollections) { col in
                        Toggle(isOn: membershipBinding(col)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(col.name.isEmpty ? "Ohne Namen" : col.name)
                                Text("\(col.booksSafe.count) Bücher")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }

                Section {
                    Button {
                        onCreateNew()
                    } label: {
                        Label("Neue Liste …", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Listen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Small UI Components

struct PrettyLinkRow: View {
    let title: String
    let url: URL
    let systemImage: String

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)

                    Text(prettyHost(url))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func prettyHost(_ url: URL) -> String {
        if let host = url.host, !host.isEmpty { return host }
        return url.absoluteString
    }
}

struct CoverThumb: View {
    let urlString: String
    let isSelected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .opacity(0.12)

            if let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    BookCoverPlaceholder(cornerRadius: 10)
                }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Image(systemName: "book")
                    .opacity(0.45)
            }

            if isSelected {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(lineWidth: 2)
                    .foregroundStyle(.primary.opacity(0.35))
            }
        }
        .frame(width: 56, height: 84)
        .clipped()
    }
}

#if canImport(UIKit)
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
#endif
