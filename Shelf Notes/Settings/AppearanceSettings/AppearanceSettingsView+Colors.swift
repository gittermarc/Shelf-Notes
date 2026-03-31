//
//  AppearanceSettingsView+Colors.swift
//  Shelf Notes
//

import SwiftUI

extension AppearanceSettingsView {
    var effectiveTextColor: Color {
        guard !useSystemTextColor, let color = Color(hex: textColorHex) else {
            return .primary
        }
        return color
    }

    var effectiveTintColor: Color {
        guard !useSystemTint, let color = Color(hex: tintColorHex) else {
            return .accentColor
        }
        return color
    }

    var colorPickerBinding: Binding<Color> {
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

    var tintPickerBinding: Binding<Color> {
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

    var colorSchemeBinding: Binding<AppColorSchemeOption> {
        Binding(
            get: { AppColorSchemeOption(rawValue: colorSchemeRaw) ?? .system },
            set: { colorSchemeRaw = $0.rawValue }
        )
    }

    @ViewBuilder
    var colorsSection: some View {
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
    func disclosureLabel(
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
}
