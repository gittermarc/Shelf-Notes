//
//  ReadingGoal.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 16.12.25.
//

import Foundation
import SwiftData

@Model
final class ReadingGoal {
    // IMPORTANT for CloudKit sync:
    // - no @Attribute(.unique)
    // - provide defaults for non-optional properties
    var year: Int = Calendar.current.component(.year, from: Date())
    var targetCount: Int = 0
    var updatedAt: Date = Date()

    init(year: Int, targetCount: Int) {
        self.year = year
        self.targetCount = targetCount
        self.updatedAt = Date()
    }
}
