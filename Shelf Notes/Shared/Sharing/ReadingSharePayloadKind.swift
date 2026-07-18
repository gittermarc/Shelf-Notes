//
//  ReadingSharePayloadKind.swift
//  Shelf Notes
//

import Foundation

nonisolated enum ReadingSharePayloadKind: String, Codable, CaseIterable, Hashable, Sendable {
    case bookLink = "bookLink"
    case text = "text"
    case textWithURL = "textWithURL"
}
