//
//  LocalOnlyBanner.swift
//  Shelf Notes
//
//  Compact banner shown when the app runs without CloudKit sync.
//

import SwiftUI

struct LocalOnlyBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "icloud.slash")
            Text("Offline-Modus: iCloud-Sync deaktiviert")
                .font(.footnote)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.top, 10)
        .padding(.horizontal, 12)
        .shadow(radius: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Offline-Modus. iCloud-Synchronisation deaktiviert")
    }
}
