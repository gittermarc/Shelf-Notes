//
//  Item.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 11.12.25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
