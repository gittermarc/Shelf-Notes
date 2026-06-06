//
//  ChallengeCadencePill.swift
//  Shelf Notes
//

import SwiftUI

struct ChallengeCadencePill: View {
    let kind: ChallengeKind
    var label: String? = nil
    var isProminent: Bool = false

    var body: some View {
        Label(label ?? kind.displayName, systemImage: kind.badgeSystemImage)
            .font(.caption.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(isProminent ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.12))
            .foregroundStyle(isProminent ? Color.accentColor : Color.secondary)
            .clipShape(Capsule())
            .accessibilityLabel(label ?? kind.displayName)
    }
}
