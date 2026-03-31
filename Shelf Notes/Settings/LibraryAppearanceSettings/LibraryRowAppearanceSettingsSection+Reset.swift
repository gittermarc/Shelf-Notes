import SwiftUI

struct LibraryRowAppearanceSettingsResetSection: View {
    let resetToDefaults: () -> Void

    var body: some View {
        Button(action: resetToDefaults) {
            Label("Bibliothek-Darstellung zurücksetzen", systemImage: "arrow.uturn.backward")
        }
    }
}
