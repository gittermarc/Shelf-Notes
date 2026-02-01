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
struct AppearanceSettingsView: View {
    @AppStorage("appearance_use_system_text_color_v1") private var useSystemTextColor: Bool = true
    @AppStorage("appearance_text_color_hex_v1") private var textColorHex: String = "#007AFF"

    private var effectiveTextColor: Color {
        guard !useSystemTextColor, let color = Color(hex: textColorHex) else {
            return .primary
        }
        return color
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

    var body: some View {
        List {
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
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Darstellung")
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
}
