//
//  AppearanceSettingsView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 01.02.26.
//

import SwiftUI

/// Settings screen for basic UI customization.
///
/// v1: Custom text color (global foreground style) via ColorPicker.
/// v2: Typography + density + tint (accent) + presets.
/// v3: Better structure (scan-friendly) via grouped sections + disclosure groups.
struct AppearanceSettingsView: View {
    // Color scheme
    @AppStorage(AppearanceStorageKey.colorScheme) private var colorSchemeRaw: String = AppColorSchemeOption.system.rawValue

    // Existing: Text color
    @AppStorage(AppearanceStorageKey.useSystemTextColor) private var useSystemTextColor: Bool = true
    @AppStorage(AppearanceStorageKey.textColorHex) private var textColorHex: String = "#007AFF"

    // Typography / density
    @AppStorage(AppearanceStorageKey.fontDesign) private var fontDesignRaw: String = AppFontDesignOption.system.rawValue
    @AppStorage(AppearanceStorageKey.textSize) private var textSizeRaw: String = AppTextSizeOption.standard.rawValue
    @AppStorage(AppearanceStorageKey.density) private var densityRaw: String = AppDensityOption.standard.rawValue

    // Tint
    @AppStorage(AppearanceStorageKey.useSystemTint) private var useSystemTint: Bool = true
    @AppStorage(AppearanceStorageKey.tintColorHex) private var tintColorHex: String = "#007AFF"

    // Library (for summary only)
    @AppStorage(AppearanceStorageKey.libraryLayoutMode) private var libraryLayoutModeRaw: String = LibraryLayoutModeOption.list.rawValue
    @AppStorage(AppearanceStorageKey.libraryShowCovers) private var libraryShowCovers: Bool = true

    // Presets (UI state only)
    @State private var selectedPreset: AppAppearancePreset = .classic

    // Collapsible groups
    @State private var textColorExpanded: Bool = false
    @State private var tintExpanded: Bool = false
    @State private var typographyExpanded: Bool = false

    // MARK: - Resolved values

    private var effectiveTextColor: Color {
        guard !useSystemTextColor, let color = Color(hex: textColorHex) else {
            return .primary
        }
        return color
    }

    private var effectiveTintColor: Color {
        guard !useSystemTint, let color = Color(hex: tintColorHex) else {
            return .accentColor
        }
        return color
    }

    private var currentPresetMatch: AppAppearancePreset? {
        let currentDesign = AppFontDesignOption(rawValue: fontDesignRaw) ?? .system
        let currentSize = AppTextSizeOption(rawValue: textSizeRaw) ?? .standard
        let currentDensity = AppDensityOption(rawValue: densityRaw) ?? .standard

        return AppAppearancePreset.allCases.first(where: { preset in
            guard preset.fontDesign == currentDesign else { return false }
            guard preset.textSize == currentSize else { return false }
            guard preset.density == currentDensity else { return false }
            guard preset.useSystemTint == useSystemTint else { return false }
            if preset.useSystemTint { return true }
            return preset.tintHex.uppercased() == tintColorHex.uppercased()
        })
    }

    private var colorPickerBinding: Binding<Color> {
        Binding(
            get: {
                Color(hex: textColorHex) ?? .blue
            },
            set: { newColor in
                // Store as #RRGGBB (no alpha)
                if let hex = newColor.toHex(includeAlpha: false) {
                    textColorHex = hex
                }
            }
        )
    }

    private var tintPickerBinding: Binding<Color> {
        Binding(
            get: {
                Color(hex: tintColorHex) ?? .blue
            },
            set: { newColor in
                if let hex = newColor.toHex(includeAlpha: false) {
                    tintColorHex = hex
                }
            }
        )
    }

    private var fontDesignBinding: Binding<AppFontDesignOption> {
        Binding(
            get: { AppFontDesignOption(rawValue: fontDesignRaw) ?? .system },
            set: { fontDesignRaw = $0.rawValue }
        )
    }

    private var colorSchemeBinding: Binding<AppColorSchemeOption> {
        Binding(
            get: { AppColorSchemeOption(rawValue: colorSchemeRaw) ?? .system },
            set: { colorSchemeRaw = $0.rawValue }
        )
    }

    private var textSizeBinding: Binding<AppTextSizeOption> {
        Binding(
            get: { AppTextSizeOption(rawValue: textSizeRaw) ?? .standard },
            set: { textSizeRaw = $0.rawValue }
        )
    }

    private var densityBinding: Binding<AppDensityOption> {
        Binding(
            get: { AppDensityOption(rawValue: densityRaw) ?? .standard },
            set: { densityRaw = $0.rawValue }
        )
    }

    private var resolvedDesign: Font.Design {
        (AppFontDesignOption(rawValue: fontDesignRaw) ?? .system).fontDesign
    }

    private var resolvedTextSize: DynamicTypeSize {
        (AppTextSizeOption(rawValue: textSizeRaw) ?? .standard).dynamicTypeSize
    }

    private var resolvedDensity: AppDensityOption {
        AppDensityOption(rawValue: densityRaw) ?? .standard
    }

    private var typographySummaryText: String {
        let design = (AppFontDesignOption(rawValue: fontDesignRaw) ?? .system).title
        let size = (AppTextSizeOption(rawValue: textSizeRaw) ?? .standard).title
        let density = (AppDensityOption(rawValue: densityRaw) ?? .standard).title
        return "\(design) · \(size) · \(density)"
    }

    private var librarySummaryText: String {
        let mode = LibraryLayoutModeOption(rawValue: libraryLayoutModeRaw) ?? .list
        let covers = libraryShowCovers ? "Covers" : "Ohne Covers"
        return "\(mode.title) · \(covers)"
    }

    // MARK: - Body

    var body: some View {
        Form {
            presetsSection
            colorsSection
            typographySection
            librarySection
            previewSection
        }
        .navigationTitle("Darstellung")
        .onAppear {
            // Make the preset cards feel "right" when entering the screen.
            selectedPreset = currentPresetMatch ?? .classic
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var presetsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Aktuell")
                    Spacer()
                    Text(currentPresetMatch?.title ?? "Benutzerdefiniert")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                let columns = [GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(AppAppearancePreset.allCases) { preset in
                        Button {
                            selectedPreset = preset
                            applyPreset(preset)
                        } label: {
                            PresetCard(
                                preset: preset,
                                isSelected: selectedPreset == preset,
                                isActive: currentPresetMatch == preset
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text((currentPresetMatch ?? selectedPreset).subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        } header: {
            Text("Presets")
        } footer: {
            Text("Presets setzen Schriftart, Schriftgröße, Textdichte und Akzentfarbe. Deine Textfarbe bleibt bewusst unberührt.")
        }
    }

    @ViewBuilder
    private var colorsSection: some View {
        Section {
            Picker("Farbschema", selection: colorSchemeBinding) {
                ForEach(AppColorSchemeOption.allCases) { opt in
                    Text(opt.title).tag(opt)
                }
            }
            .pickerStyle(.segmented)

            Button {
                colorSchemeRaw = AppColorSchemeOption.system.rawValue
            } label: {
                Label("Farbschema zurücksetzen", systemImage: "arrow.uturn.backward")
            }

            DisclosureGroup(isExpanded: $textColorExpanded) {
                Toggle(isOn: $useSystemTextColor) {
                    Label("Systemfarbe verwenden", systemImage: "circle.lefthalf.filled")
                }

                ColorPicker("Textfarbe", selection: colorPickerBinding, supportsOpacity: false)
                    .disabled(useSystemTextColor)

                if !useSystemTextColor {
                    HStack {
                        Text("Aktuell")
                        Spacer()
                        Text(textColorHex)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospaced()
                    }
                }

                Button {
                    useSystemTextColor = true
                } label: {
                    Label("Textfarbe zurücksetzen", systemImage: "arrow.uturn.backward")
                }

                Text("Hinweis: Diese Einstellung setzt die Standard-Textfarbe über die App hinweg. Elemente, die bewusst .secondary oder eine explizite Farbe nutzen, bleiben unverändert. Im Dark Mode können sehr dunkle Farben schlecht lesbar sein – also nicht komplett eskalieren 😄")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } label: {
                disclosureLabel(
                    title: "Textfarbe",
                    systemImage: "textformat",
                    usesSystem: useSystemTextColor,
                    hex: textColorHex,
                    color: effectiveTextColor
                )
            }

            DisclosureGroup(isExpanded: $tintExpanded) {
                Toggle(isOn: $useSystemTint) {
                    Label("System-Akzent verwenden", systemImage: "paintbrush")
                }

                ColorPicker("Akzentfarbe", selection: tintPickerBinding, supportsOpacity: false)
                    .disabled(useSystemTint)

                if !useSystemTint {
                    HStack {
                        Text("Aktuell")
                        Spacer()
                        Text(tintColorHex)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospaced()
                    }
                }

                Button {
                    useSystemTint = true
                } label: {
                    Label("Akzent zurücksetzen", systemImage: "arrow.uturn.backward")
                }

                Text("Die Akzentfarbe (Tint) beeinflusst Buttons, Links, Toggles, Progress und Highlights – also quasi alles, was „klick mich“ schreit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } label: {
                disclosureLabel(
                    title: "Akzentfarbe",
                    systemImage: "paintpalette",
                    usesSystem: useSystemTint,
                    hex: tintColorHex,
                    color: effectiveTintColor
                )
            }
        } header: {
            Text("Farben & Theme")
        } footer: {
            Text("System ist die vernünftige Standardwahl – aber hey, wir sind hier nicht bei einer Steuererklärung 😄")
        }
    }

    @ViewBuilder
    private var typographySection: some View {
        Section {
            DisclosureGroup(isExpanded: $typographyExpanded) {
                Picker("Schriftgröße", selection: textSizeBinding) {
                    ForEach(AppTextSizeOption.allCases) { opt in
                        Text(opt.title).tag(opt)
                    }
                }
                .pickerStyle(.menu)

                Picker("Textdichte", selection: densityBinding) {
                    ForEach(AppDensityOption.allCases) { opt in
                        Text(opt.title).tag(opt)
                    }
                }
                .pickerStyle(.menu)

                Picker("Schriftart", selection: fontDesignBinding) {
                    ForEach(AppFontDesignOption.allCases) { opt in
                        Text(opt.title).tag(opt)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    textSizeRaw = AppTextSizeOption.standard.rawValue
                    densityRaw = AppDensityOption.standard.rawValue
                    fontDesignRaw = AppFontDesignOption.system.rawValue
                } label: {
                    Label("Schrift & Dichte zurücksetzen", systemImage: "arrow.uturn.backward")
                }

                Text("Diese Optionen wirken app-intern: Schriftgröße (über Dynamic Type), Schriftart (System/Serif/Rounded) und eine etwas kompaktere bzw. luftigere Darstellung in Listen & Formularen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } label: {
                HStack {
                    Label("Schrift & Layout", systemImage: "textformat.size")
                    Spacer()
                    Text(typographySummaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var librarySection: some View {
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
    private var previewSection: some View {
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

    @ViewBuilder
    private func disclosureLabel(
        title: String,
        systemImage: String,
        usesSystem: Bool,
        hex: String,
        color: Color
    ) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()

            if usesSystem {
                Text("System")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)

                Text(hex)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospaced()
            }
        }
    }

    // MARK: - Preset application

    private func applyPreset(_ preset: AppAppearancePreset) {
        fontDesignRaw = preset.fontDesign.rawValue
        textSizeRaw = preset.textSize.rawValue
        densityRaw = preset.density.rawValue

        useSystemTint = preset.useSystemTint
        if !preset.useSystemTint {
            tintColorHex = preset.tintHex
        }
    }
}

private struct PresetCard: View {
    let preset: AppAppearancePreset
    let isSelected: Bool
    let isActive: Bool

    private var accent: Color {
        if preset.useSystemTint {
            return .accentColor
        }
        return Color(hex: preset.tintHex) ?? .accentColor
    }

    private var detailLine: String {
        "\(preset.fontDesign.title) · \(preset.textSize.title) · \(preset.density.title)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(detailLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                if isActive {
                    Text("Aktiv")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(accent)
                }
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(accent)
                    .frame(width: 10, height: 10)

                Text(preset.useSystemTint ? "System-Akzent" : "Akzent")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isActive ? accent : (isSelected ? .secondary.opacity(0.6) : .secondary.opacity(0.25)), lineWidth: isActive ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preset \(preset.title)")
        .accessibilityHint("Tippen, um dieses Preset anzuwenden")
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
}
