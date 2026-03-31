import SwiftUI

struct LibraryRowAppearanceSettingsCoverSection: View {
    let showCovers: Binding<Bool>
    let coverSize: Binding<LibraryCoverSizeOption>
    let coverContentMode: Binding<LibraryCoverContentModeOption>
    let coverCornerRadius: Binding<Double>
    let coverShadowEnabled: Binding<Bool>

    var body: some View {
        Toggle(isOn: showCovers) {
            Label("Cover anzeigen", systemImage: "photo")
        }

        Picker("Cover-Größe", selection: coverSize) {
            ForEach(LibraryCoverSizeOption.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.menu)
        .disabled(!showCovers.wrappedValue)

        Picker("Bildmodus", selection: coverContentMode) {
            ForEach(LibraryCoverContentModeOption.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.menu)
        .disabled(!showCovers.wrappedValue)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Ecken")
                Spacer()
                Text("\(Int(coverCornerRadius.wrappedValue.rounded()))")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(value: coverCornerRadius, in: 0...16, step: 1)
                .disabled(!showCovers.wrappedValue)
        }

        Toggle(isOn: coverShadowEnabled) {
            Label("Schatten (sanft)", systemImage: "square.on.circle")
        }
        .disabled(!showCovers.wrappedValue)
    }
}
