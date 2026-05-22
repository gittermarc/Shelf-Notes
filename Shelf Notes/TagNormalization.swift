//
//  TagNormalization.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 11.12.25.
//  Extracted from ContentView.swift on 05.01.26.
//

import Foundation

/// Normalisiert Tags für alle Tag-Pfade der App.
///
/// Regeln:
/// - führende Hashtag-Zeichen werden entfernt
/// - innere Hashtag-Zeichen bleiben erhalten, damit Tags wie `C#` nicht kaputtgehen
/// - Whitespace am Rand wird entfernt
/// - mehrere Whitespace-Zeichen im Tag werden zu einem Leerzeichen verdichtet
/// - Note: bewusst **internal** (default), damit es in mehreren Views/Files genutzt werden kann.
func normalizeTagString(_ s: String) -> String {
    var value = s
        .trimmingCharacters(in: .whitespacesAndNewlines)

    while value.first == "#" {
        value.removeFirst()
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    return value
        .split(whereSeparator: { $0.isWhitespace })
        .joined(separator: " ")
}
