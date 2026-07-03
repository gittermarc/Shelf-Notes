//
//  LibraryOverviewWidgetTheme.swift
//  ShelfNotesLiveActivity
//
//  Visual styling for the Library Overview Home Screen widget.
//

import SwiftUI

enum LibraryOverviewWidgetTheme {
    static let accent = Color(red: 0.96, green: 0.72, blue: 0.28)
    static let accentSoft = Color(red: 0.96, green: 0.72, blue: 0.28).opacity(0.18)
    static let warmSurface = Color(red: 0.11, green: 0.09, blue: 0.07)
    static let warmSurfaceSecondary = Color(red: 0.23, green: 0.17, blue: 0.11)
    static let ink = Color.white
    static let inkMuted = Color.white.opacity(0.70)
    static let inkSubtle = Color.white.opacity(0.52)
    static let stroke = Color.white.opacity(0.12)
    static let tileFill = Color.white.opacity(0.10)

    static var background: LinearGradient {
        LinearGradient(
            colors: [
                warmSurface,
                warmSurfaceSecondary,
                accent.opacity(0.22)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var glow: some View {
        Circle()
            .fill(accent.opacity(0.18))
            .frame(width: 180, height: 180)
            .blur(radius: 26)
    }
}
