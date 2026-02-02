//
//  LibraryRowAppearanceSettingsSection.swift
//  Shelf Notes
//
//  Library row / cover style customization.
//

import SwiftUI

/// Appearance settings for list rows (covers + which details to show).
///
/// Stored via `@AppStorage` so changes apply immediately app-wide.
struct LibraryRowAppearanceSettingsSection: View {
    // Cover style
    @AppStorage(AppearanceStorageKey.libraryShowCovers) private var showCovers: Bool = true
    @AppStorage(AppearanceStorageKey.libraryCoverSize) private var coverSizeRaw: String = LibraryCoverSizeOption.standard.rawValue
    @AppStorage(AppearanceStorageKey.libraryCoverCornerRadius) private var coverCornerRadius: Double = 8
    @AppStorage(AppearanceStorageKey.libraryCoverContentMode) private var coverContentModeRaw: String = LibraryCoverContentModeOption.fit.rawValue
    @AppStorage(AppearanceStorageKey.libraryCoverShadowEnabled) private var coverShadowEnabled: Bool = false

    // Row details
    @AppStorage(AppearanceStorageKey.libraryRowShowAuthor) private var showAuthor: Bool = true
    @AppStorage(AppearanceStorageKey.libraryRowShowStatus) private var showStatus: Bool = true
    @AppStorage(AppearanceStorageKey.libraryRowShowReadDate) private var showReadDate: Bool = true
    @AppStorage(AppearanceStorageKey.libraryRowShowRating) private var showRating: Bool = true
    @AppStorage(AppearanceStorageKey.libraryRowShowTags) private var showTags: Bool = true
    @AppStorage(AppearanceStorageKey.libraryRowMaxTags) private var maxTags: Int = 2

    // Row spacing
    @AppStorage(AppearanceStorageKey.libraryRowVerticalInset) private var rowVerticalInset: Double = 8
    @AppStorage(AppearanceStorageKey.libraryRowContentSpacing) private var rowContentSpacing: Double = 2

    private var coverSizeBinding: Binding<LibraryCoverSizeOption> {
        Binding(
            get: { LibraryCoverSizeOption(rawValue: coverSizeRaw) ?? .standard },
            set: { coverSizeRaw = $0.rawValue }
        )
    }

    private var coverContentModeBinding: Binding<LibraryCoverContentModeOption> {
        Binding(
            get: { LibraryCoverContentModeOption(rawValue: coverContentModeRaw) ?? .fit },
            set: { coverContentModeRaw = $0.rawValue }
        )
    }

    private var resolvedCoverSize: CGSize {
        (LibraryCoverSizeOption(rawValue: coverSizeRaw) ?? .standard).size
    }

    private var resolvedContentMode: ContentMode {
        (LibraryCoverContentModeOption(rawValue: coverContentModeRaw) ?? .fit).contentMode
    }

    var body: some View {
        Section {
            // MARK: Cover style

            Toggle(isOn: $showCovers) {
                Label("Cover in Listen anzeigen", systemImage: "photo")
            }

            Picker("Cover-Größe", selection: coverSizeBinding) {
                ForEach(LibraryCoverSizeOption.allCases) { opt in
                    Text(opt.title).tag(opt)
                }
            }
            .pickerStyle(.menu)
            .disabled(!showCovers)

            Picker("Bildmodus", selection: coverContentModeBinding) {
                ForEach(LibraryCoverContentModeOption.allCases) { opt in
                    Text(opt.title).tag(opt)
                }
            }
            .pickerStyle(.menu)
            .disabled(!showCovers)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Ecken")
                    Spacer()
                    Text("\(Int(coverCornerRadius.rounded()))")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Slider(value: $coverCornerRadius, in: 0...16, step: 1)
                    .disabled(!showCovers)
            }

            Toggle(isOn: $coverShadowEnabled) {
                Label("Schatten (sanft)", systemImage: "square.on.circle")
            }
            .disabled(!showCovers)

            Divider()

            // MARK: Row layout

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Zeilenabstand")
                    Spacer()
                    Text("\(Int(rowVerticalInset.rounded()))")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Slider(value: $rowVerticalInset, in: 2...14, step: 1)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Inhalt-Abstand")
                    Spacer()
                    Text("\(Int(rowContentSpacing.rounded()))")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Slider(value: $rowContentSpacing, in: 0...10, step: 1)

                Text("Steuert den vertikalen Abstand innerhalb einer Buchzeile (Titel/Autor/Info/Tags).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // MARK: Row details

            Toggle(isOn: $showAuthor) {
                Label("Autor anzeigen", systemImage: "person")
            }

            Toggle(isOn: $showStatus) {
                Label("Status anzeigen", systemImage: "bookmark")
            }

            Toggle(isOn: $showReadDate) {
                Label("Monat/Jahr anzeigen", systemImage: "calendar")
            }

            Toggle(isOn: $showRating) {
                Label("Bewertung anzeigen", systemImage: "star")
            }

            Toggle(isOn: $showTags) {
                Label("Tags anzeigen", systemImage: "number")
            }

            Stepper(value: $maxTags, in: 1...4, step: 1) {
                HStack {
                    Text("Max. Tags")
                    Spacer()
                    Text("\(maxTags)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .disabled(!showTags)

            // MARK: Preview

            VStack(alignment: .leading, spacing: 10) {
                Text("Vorschau")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LibraryRowSettingsPreview(
                    showCovers: showCovers,
                    coverSize: resolvedCoverSize,
                    coverCornerRadius: CGFloat(coverCornerRadius),
                    contentMode: resolvedContentMode,
                    coverShadowEnabled: coverShadowEnabled,
                    showAuthor: showAuthor,
                    showStatus: showStatus,
                    showReadDate: showReadDate,
                    showRating: showRating,
                    showTags: showTags,
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

            Button {
                resetToDefaults()
            } label: {
                Label("Bibliothek-Darstellung zurücksetzen", systemImage: "arrow.uturn.backward")
            }
        } header: {
            Text("Bibliothek")
        } footer: {
            Text("Passe Cover-Darstellung und Zeilen-Details an. Standardwerte entsprechen dem bisherigen Look – du kannst also gefahrlos rumspielen.")
        }
    }

    private func resetToDefaults() {
        showCovers = true
        coverSizeRaw = LibraryCoverSizeOption.standard.rawValue
        coverCornerRadius = 8
        coverContentModeRaw = LibraryCoverContentModeOption.fit.rawValue
        coverShadowEnabled = false

        rowVerticalInset = 8
        rowContentSpacing = 2

        showAuthor = true
        showStatus = true
        showReadDate = true
        showRating = true
        showTags = true
        maxTags = 2
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
        let n = max(1, min(maxTags, tags.count))
        return tags.prefix(n).map { "#\($0)" }.joined(separator: " ")
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
                        ForEach(Array(metaParts.enumerated()), id: \.offset) { idx, part in
                            if idx > 0 {
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
                    Text(tagsText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
        .shadow(color: coverShadowEnabled ? .black.opacity(0.12) : .clear, radius: coverShadowEnabled ? 4 : 0, x: 0, y: coverShadowEnabled ? 2 : 0)
    }
}

#Preview {
    NavigationStack {
        List {
            LibraryRowAppearanceSettingsSection()
        }
        .navigationTitle("Darstellung")
    }
}
