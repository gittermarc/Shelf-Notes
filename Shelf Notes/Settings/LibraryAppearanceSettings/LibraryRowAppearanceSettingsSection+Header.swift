import SwiftUI

struct LibraryRowAppearanceSettingsHeaderSection: View {
    let headerStyle: Binding<LibraryHeaderStyleOption>
    let headerDefaultExpanded: Binding<Bool>
    let resolvedHeaderStyle: LibraryHeaderStyleOption

    var body: some View {
        Picker("Header", selection: headerStyle) {
            ForEach(LibraryHeaderStyleOption.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.menu)

        if resolvedHeaderStyle == .standard {
            Toggle(isOn: headerDefaultExpanded) {
                Label("Header standardmäßig ausgeklappt", systemImage: "chevron.down")
            }
        } else {
            Text("Im kompakten oder ausgeschalteten Header ist der Klappzustand irrelevant.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
