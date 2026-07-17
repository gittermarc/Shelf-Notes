//
//  ReadingProgressAttemptSnapshot.swift
//  Shelf Notes
//

import Foundation

/// Value-only input for computing the progress of one reading attempt.
nonisolated struct ReadingProgressAttemptSnapshot: Equatable, Sendable {
    let attemptID: UUID
    let status: ReadingAttemptStatus
    let unit: ReadingProgressUnit
    let pageCountSnapshot: Int?
    let totalValueSnapshot: Double?
    let sessionPageValues: [Int]
    let updates: [ReadingProgressUpdate]

    init(
        attemptID: UUID,
        status: ReadingAttemptStatus,
        unit: ReadingProgressUnit,
        pageCountSnapshot: Int? = nil,
        totalValueSnapshot: Double? = nil,
        sessionPageValues: [Int] = [],
        updates: [ReadingProgressUpdate] = []
    ) {
        self.attemptID = attemptID
        self.status = status
        self.unit = unit
        self.pageCountSnapshot = pageCountSnapshot
        self.totalValueSnapshot = totalValueSnapshot
        self.sessionPageValues = sessionPageValues
        self.updates = updates
    }
}