//
//  LibraryHomeDashboardVisibility.swift
//  Shelf Notes
//
//  Pure visibility rule for the Smart Shelf dashboard.
//

import Foundation

extension LibraryView {
    nonisolated enum LibraryHomeDashboardVisibility {
        static func shouldShow(
            isHomeState: Bool,
            isSelectionMode: Bool,
            bookCount: Int,
            headerStyle: LibraryHeaderStyleOption,
            homeMode: LibraryHomeModeOption
        ) -> Bool {
            isHomeState
            && !isSelectionMode
            && bookCount > 0
            && headerStyle != .hidden
            && homeMode != .hidden
        }
    }
}
