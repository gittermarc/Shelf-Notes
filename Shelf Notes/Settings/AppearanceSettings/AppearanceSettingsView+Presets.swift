//
//  AppearanceSettingsView+Presets.swift
//  Shelf Notes
//

import SwiftUI

extension AppearanceSettingsView {
    var currentPresetMatch: AppAppearancePreset? {
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

    @ViewBuilder
    var presetsSection: some View {
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

    func applyPreset(_ preset: AppAppearancePreset) {
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
