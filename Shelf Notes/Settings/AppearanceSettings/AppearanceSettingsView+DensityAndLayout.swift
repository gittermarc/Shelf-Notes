//
//  AppearanceSettingsView+DensityAndLayout.swift
//  Shelf Notes
//

import SwiftUI

extension AppearanceSettingsView {
    var densityBinding: Binding<AppDensityOption> {
        Binding(
            get: { AppDensityOption(rawValue: densityRaw) ?? .standard },
            set: { densityRaw = $0.rawValue }
        )
    }

    var resolvedDensity: AppDensityOption {
        AppDensityOption(rawValue: densityRaw) ?? .standard
    }

    var librarySummaryText: String {
        let mode = LibraryLayoutModeOption(rawValue: libraryLayoutModeRaw) ?? .list
        let covers = libraryShowCovers ? "Covers" : "Ohne Covers"
        return "\(mode.title) · \(covers)"
    }

    @ViewBuilder
    var librarySection: some View {
        Section {
            NavigationLink {
                LibraryAppearanceSettingsView()
            } label: {
                HStack {
                    Label("Bibliothek", systemImage: "books.vertical")
                    Spacer()
                    Text(librarySummaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Cover-Darstellung, Zeilen-Details, Tags, Abstände – alles, was die Bibliothek hübsch (oder maximal effizient) macht.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Bibliothek")
        }
    }

    @ViewBuilder
    var previewSection: some View {
        Section("Vorschau") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Shelf Notes")
                    .font(.headline)
                    .foregroundStyle(effectiveTextColor)

                Text("Ein kurzer Beispieltext, um die Wirkung zu sehen. Sekundärtext bleibt weiterhin sekundär.")
                    .foregroundStyle(effectiveTextColor)

                Text("Sekundärtext (bleibt secondary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    // no-op
                } label: {
                    Label("Beispiel-Button", systemImage: "sparkles")
                }

                Toggle("Beispiel-Toggle", isOn: .constant(true))
            }
            .padding(.vertical, 4)
            .fontDesign(resolvedDesign)
            .dynamicTypeSize(resolvedTextSize)
            .environment(\.controlSize, resolvedDensity.controlSize)
            .environment(\.defaultMinListRowHeight, resolvedDensity.minListRowHeight)
            .tint(effectiveTintColor)
        }
    }
}
