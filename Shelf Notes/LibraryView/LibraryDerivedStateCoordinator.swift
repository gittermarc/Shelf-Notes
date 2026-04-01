//
//  LibraryDerivedStateCoordinator.swift
//  Shelf Notes
//
//  Keeps the last stable derived state out of the direct render path.
//

import Foundation

extension LibraryView {
    struct LibraryDerivedStateCoordinator: Equatable {
        private(set) var requestedToken: LibraryDerivedInputToken?
        private(set) var lastStableState: LibraryDerivedState

        init(
            requestedToken: LibraryDerivedInputToken? = nil,
            lastStableState: LibraryDerivedState = .empty
        ) {
            self.requestedToken = requestedToken
            self.lastStableState = lastStableState
        }

        var hasStableState: Bool {
            lastStableState != .empty
        }

        func displayState(for activeToken: LibraryDerivedInputToken) -> LibraryDerivedState {
            lastStableState
        }

        func isResolved(for activeToken: LibraryDerivedInputToken) -> Bool {
            lastStableState.token == activeToken
        }

        mutating func invalidate(for token: LibraryDerivedInputToken) {
            requestedToken = token
        }

        mutating func resolveIfNeeded(
            for token: LibraryDerivedInputToken,
            source: LibrarySourceSnapshot,
            input: LibraryDerivedInput,
            build: (LibrarySourceSnapshot, LibraryDerivedInput) -> LibraryDerivedState = LibraryDerivedStateBuilder.makeDerivedState(source:input:)
        ) {
            requestedToken = token

            guard lastStableState.token != token else {
                return
            }

            guard requestedToken == token else {
                return
            }

            let rebuiltState = build(source, input)

            guard requestedToken == token else {
                return
            }

            guard rebuiltState.token == token else {
                return
            }

            lastStableState = rebuiltState
        }
    }
}
