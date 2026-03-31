import SwiftUI

struct LibraryRowAppearanceSettingsRowDetailsSection: View {
    let showAuthor: Binding<Bool>
    let showStatus: Binding<Bool>
    let showReadDate: Binding<Bool>
    let showRating: Binding<Bool>
    let showTags: Binding<Bool>
    let tagStyle: Binding<LibraryTagStyleOption>
    let maxTags: Binding<Int>

    var body: some View {
        Toggle(isOn: showAuthor) {
            Label("Autor anzeigen", systemImage: "person")
        }

        Toggle(isOn: showStatus) {
            Label("Status anzeigen", systemImage: "bookmark")
        }

        Toggle(isOn: showReadDate) {
            Label("Monat/Jahr anzeigen", systemImage: "calendar")
        }

        Toggle(isOn: showRating) {
            Label("Bewertung anzeigen", systemImage: "star")
        }

        Toggle(isOn: showTags) {
            Label("Tags anzeigen", systemImage: "number")
        }

        Picker("Tag-Stil", selection: tagStyle) {
            ForEach(LibraryTagStyleOption.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.menu)
        .disabled(!showTags.wrappedValue)

        Stepper(value: maxTags, in: 1...4, step: 1) {
            HStack {
                Text("Max. Tags")
                Spacer()
                Text("\(maxTags.wrappedValue)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .disabled(!showTags.wrappedValue)
    }
}
