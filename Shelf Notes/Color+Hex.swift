//
//  Color+Hex.swift
//  Shelf Notes
//
//  Lightweight persistence helpers for user-selected colors.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

extension Color {
    /// Creates a Color from a hex string.
    ///
    /// Supports:
    /// - #RRGGBB
    /// - #RRGGBBAA
    /// - with/without leading '#'
    init?(hex: String) {
        let cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard cleaned.count == 6 || cleaned.count == 8 else { return nil }

        var value: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&value) else { return nil }

        let r, g, b, a: Double
        if cleaned.count == 6 {
            r = Double((value & 0xFF0000) >> 16) / 255.0
            g = Double((value & 0x00FF00) >> 8) / 255.0
            b = Double(value & 0x0000FF) / 255.0
            a = 1.0
        } else {
            r = Double((value & 0xFF000000) >> 24) / 255.0
            g = Double((value & 0x00FF0000) >> 16) / 255.0
            b = Double((value & 0x0000FF00) >> 8) / 255.0
            a = Double(value & 0x000000FF) / 255.0
        }

        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// Returns a hex string representation of the color.
    ///
    /// - Parameter includeAlpha: If true, returns #RRGGBBAA; otherwise #RRGGBB.
    func toHex(includeAlpha: Bool = true) -> String? {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }

        let ri = Int(round(r * 255))
        let gi = Int(round(g * 255))
        let bi = Int(round(b * 255))
        let ai = Int(round(a * 255))

        if includeAlpha {
            return String(format: "#%02X%02X%02X%02X", ri, gi, bi, ai)
        } else {
            return String(format: "#%02X%02X%02X", ri, gi, bi)
        }
        #else
        return nil
        #endif
    }
}
