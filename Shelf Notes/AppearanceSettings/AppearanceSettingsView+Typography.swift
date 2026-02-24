//
//  AppearanceSettingsView+Typography.swift
//  Shelf Notes
//

import SwiftUI

extension AppearanceSettingsView {
    var fontDesignBinding: Binding<AppFontDesignOption> {
        Binding(
            get: { AppFontDesignOption(rawValue: fontDesignRaw) ?? .system },
            set: { fontDesignRaw = $0.rawValue }
        )
    }

    var textSizeBinding: Binding<AppTextSizeOption> {
        Binding(
            get: { AppTextSizeOption(rawValue: textSizeRaw) ?? .standard },
            set: { textSizeRaw = $0.rawValue }
        )
    }

    var resolvedDesign: Font.Design {
        (AppFontDesignOption(rawValue: fontDesignRaw) ?? .system).fontDesign
    }

    var resolvedTextSize: DynamicTypeSize {
        (AppTextSizeOption(rawValue: textSizeRaw) ?? .standard).dynamicTypeSize
    }

    var typographySummaryText: String {
        let design = (AppFontDesignOption(rawValue: fontDesignRaw) ?? .system).title
        let size = (AppTextSizeOption(rawValue: textSizeRaw) ?? .standard).title
        let density = (AppDensityOption(rawValue: densityRaw) ?? .standard).title
        return "\(design) · \(size) · \(density)"
    }

    @ViewBuilder
    var typographySection: some View {
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
}
