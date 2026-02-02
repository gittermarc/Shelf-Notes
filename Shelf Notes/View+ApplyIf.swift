//
//  View+ApplyIf.swift
//  Shelf Notes
//
//  Tiny helper for conditional view modifiers.
//

import SwiftUI

extension View {
    @ViewBuilder
    func applyIf<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
