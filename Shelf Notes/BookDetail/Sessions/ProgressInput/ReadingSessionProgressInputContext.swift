//
//  ReadingSessionProgressInputContext.swift
//  Shelf Notes
//

import Foundation

@MainActor
struct ReadingSessionProgressInputContext {
    let source: ReadingSessionSource
    let currentProgress: ReadingProgressSnapshot
    let configuration: ReadingProgressInputConfiguration
}
