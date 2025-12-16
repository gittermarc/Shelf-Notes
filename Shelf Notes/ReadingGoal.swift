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
    @Attribute(.unique) var year: Int
    var targetCount: Int
    var updatedAt: Date

    init(year: Int, targetCount: Int) {
        self.year = year
        self.targetCount = targetCount
        self.updatedAt = Date()
    }
}
