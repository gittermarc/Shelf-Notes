import SwiftUI

struct LibraryRowAppearanceSettingsSpacingSection: View {
    let rowVerticalInset: Binding<Double>
    let rowContentSpacing: Binding<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Zeilenabstand")
                Spacer()
                Text("\(Int(rowVerticalInset.wrappedValue.rounded()))")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(value: rowVerticalInset, in: 2...14, step: 1)
        }

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Inhalt-Abstand")
                Spacer()
                Text("\(Int(rowContentSpacing.wrappedValue.rounded()))")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(value: rowContentSpacing, in: 0...10, step: 1)

            Text("Steuert den vertikalen Abstand innerhalb einer Buchzeile (Titel/Autor/Info/Tags).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
