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
struct AppearanceSettingsView: View {
    // Existing: Text color
    @AppStorage(AppearanceStorageKey.useSystemTextColor) private var useSystemTextColor: Bool = true
    @AppStorage(AppearanceStorageKey.textColorHex) private var textColorHex: String = "#007AFF"

    // New: Typography / density
    @AppStorage(AppearanceStorageKey.fontDesign) private var fontDesignRaw: String = AppFontDesignOption.system.rawValue
    @AppStorage(AppearanceStorageKey.textSize) private var textSizeRaw: String = AppTextSizeOption.standard.rawValue
    @AppStorage(AppearanceStorageKey.density) private var densityRaw: String = AppDensityOption.standard.rawValue

    // New: Tint
    @AppStorage(AppearanceStorageKey.useSystemTint) private var useSystemTint: Bool = true
    @AppStorage(AppearanceStorageKey.tintColorHex) private var tintColorHex: String = "#007AFF"

    // Presets (UI state only)
    @State private var selectedPreset: AppAppearancePreset = .classic

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

    // MARK: - Body

    var body: some View {
        List {
            Section {
                Picker("Preset", selection: $selectedPreset) {
                    ForEach(AppAppearancePreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .pickerStyle(.menu)

                Text(selectedPreset.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("Aktuell")
                    Spacer()
                    Text(currentPresetMatch?.title ?? "Benutzerdefiniert")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    applyPreset(selectedPreset)
                } label: {
                    Label("Preset anwenden", systemImage: "sparkles")
                }
            } header: {
                Text("Presets")
            } footer: {
                Text("Presets setzen Schriftart, Schriftgröße, Textdichte und Akzentfarbe. Deine Textfarbe bleibt bewusst unberührt.")
            }

            Section {
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
                    Label("Auf Systemfarbe zurücksetzen", systemImage: "arrow.uturn.backward")
                }
            } header: {
                Text("Text")
            } footer: {
                Text("Hinweis: Diese Einstellung setzt die Standard-Textfarbe über die App hinweg. Elemente, die bewusst .secondary oder eine explizite Farbe nutzen, bleiben unverändert. Im Dark Mode können sehr dunkle Farben schlecht lesbar sein – also nicht komplett eskalieren 😄")
            }

            Section {
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
            } header: {
                Text("Schrift & Layout")
            } footer: {
                Text("Diese Optionen wirken app-intern: Schriftgröße (über Dynamic Type), Schriftart (System/Serif/Rounded) und eine etwas kompaktere bzw. luftigere Darstellung in Listen & Formularen.")
            }

            Section {
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
                    Label("Auf System-Akzent zurücksetzen", systemImage: "arrow.uturn.backward")
                }
            } header: {
                Text("Akzent")
            } footer: {
                Text("Die Akzentfarbe (Tint) beeinflusst Buttons, Links, Toggles, Progress und Highlights – also quasi alles, was „klick mich“ schreit.")
            }

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
        .navigationTitle("Darstellung")
        .onAppear {
            // Make the picker feel "right" when entering the screen.
            selectedPreset = currentPresetMatch ?? .classic
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

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
}
