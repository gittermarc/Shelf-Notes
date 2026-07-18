//
//  ReadingShareTextNormalizer.swift
//  Shelf Notes
//

import Foundation

nonisolated enum ReadingShareTextNormalizer {
    static let maxBodyLength = 12_000

    static func normalizedOptional(_ value: String?, maxLength: Int) -> String? {
        guard let normalized = normalized(value, maxLength: maxLength), !normalized.isEmpty else {
            return nil
        }
        return normalized
    }

    static func normalized(_ value: String?, maxLength: Int) -> String? {
        guard let value else { return nil }
        let collapsed = value
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !collapsed.isEmpty else { return nil }
        guard collapsed.count > maxLength else { return collapsed }

        let endIndex = collapsed.index(collapsed.startIndex, offsetBy: max(0, maxLength))
        return String(collapsed[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
