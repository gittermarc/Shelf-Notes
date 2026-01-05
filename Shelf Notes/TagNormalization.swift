//
//  TagNormalization.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 11.12.25.
//  Extracted from ContentView.swift on 05.01.26.
//

import Foundation

/// Normalisiert Tags (Trim, entfernt #).
/// - Note: bewusst **internal** (default), damit es in mehreren Views/Files genutzt werden kann.
func normalizeTagString(_ s: String) -> String {
    s
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "#", with: "")
}
