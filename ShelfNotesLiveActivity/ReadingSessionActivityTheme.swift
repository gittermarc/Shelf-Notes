//
//  ReadingSessionActivityTheme.swift
//  ShelfNotesLiveActivity
//
//  Lightweight visual theme helpers for the Reading Session Live Activity.
//

import Foundation
import SwiftUI

enum ReadingSessionActivityTheme {
    static let fallbackAccent = Color(red: 0.96, green: 0.72, blue: 0.28)
    static let warmSurface = Color(red: 0.11, green: 0.09, blue: 0.07)
    static let warmSurfaceSecondary = Color(red: 0.22, green: 0.17, blue: 0.12)

    static func accentColor(from hex: String?) -> Color {
        guard let hex, let color = color(from: hex) else { return fallbackAccent }
        return color
    }

    static func cardBackground(accentHex: String?) -> LinearGradient {
        let accent = accentColor(from: accentHex)
        return LinearGradient(
            colors: [
                warmSurface,
                warmSurfaceSecondary,
                accent.opacity(0.28)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func softHighlight(accentHex: String?) -> LinearGradient {
        let accent = accentColor(from: accentHex)
        return LinearGradient(
            colors: [
                accent.opacity(0.34),
                accent.opacity(0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func color(from hex: String) -> Color? {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard raw.count == 6 || raw.count == 8 else { return nil }

        var value: UInt64 = 0
        guard Scanner(string: raw).scanHexInt64(&value) else { return nil }

        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        if raw.count == 8 {
            red = Double((value & 0xFF00_0000) >> 24) / 255.0
            green = Double((value & 0x00FF_0000) >> 16) / 255.0
            blue = Double((value & 0x0000_FF00) >> 8) / 255.0
            alpha = Double(value & 0x0000_00FF) / 255.0
        } else {
            red = Double((value & 0xFF0000) >> 16) / 255.0
            green = Double((value & 0x00FF00) >> 8) / 255.0
            blue = Double(value & 0x0000FF) / 255.0
            alpha = 1.0
        }

        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}
