//
//  LibraryAppearanceSettingsView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 02.02.26.
//

import SwiftUI

/// Dedicated screen for library/list/grid appearance.
///
/// Keeps the main Appearance screen shorter and easier to scan,
/// while still exposing all options.
struct LibraryAppearanceSettingsView: View {
    var body: some View {
        Form {
            LibraryRowAppearanceSettingsSection()
        }
        .navigationTitle("Bibliothek")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        LibraryAppearanceSettingsView()
    }
}
