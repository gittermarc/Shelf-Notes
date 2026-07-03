//
//  LibraryDisplayStore.swift
//  Shelf Notes
//
//  Keeps the last stable library display state out of SwiftUI render helpers.
//

import Foundation

extension LibraryView {
    struct LibraryDisplayStore {
        private var derivedCoordinator = LibraryDerivedStateCoordinator()

        private(set) var resolvedSearchText: String = ""
        private(set) var state: LibraryDisplayState = .empty

        var hasStableState: Bool {
            derivedCoordinator.hasStableState
        }

        func makeInput(
            selectedStatus: ReadingStatus?,
            selectedTag: String?,
            selectedCollectionName: String? = nil,
            onlyWithNotes: Bool,
            smartFilter: LibrarySmartFilter? = nil,
            longInactiveCutoff: Date? = nil,
            sortField: SortField,
            sortAscending: Bool,
            buildsAlphaSections: Bool
        ) -> LibraryDerivedInput {
            LibraryDerivedStateBuilder.makeInput(
                searchText: resolvedSearchText,
                selectedStatus: selectedStatus,
                selectedTag: selectedTag,
                selectedCollectionName: selectedCollectionName,
                onlyWithNotes: onlyWithNotes,
                smartFilter: smartFilter,
                longInactiveCutoff: longInactiveCutoff,
                sortField: sortField,
                sortAscending: sortAscending,
                buildsAlphaSections: buildsAlphaSections
            )
        }

        func displayState(for activeToken: LibraryDerivedInputToken) -> LibraryDisplayState {
            state
        }

        mutating func setResolvedSearchText(_ searchText: String) {
            resolvedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        mutating func invalidate(for token: LibraryDerivedInputToken) {
            derivedCoordinator.invalidate(for: token)
        }

        @MainActor mutating func resolveIfNeeded(
            for token: LibraryDerivedInputToken,
            index: LibraryBooksIndex,
            input: LibraryDerivedInput,
            build: (LibrarySourceSnapshot, LibraryDerivedInput) -> LibraryDerivedState = LibraryDerivedStateBuilder.makeDerivedState(source:input:)
        ) {
            derivedCoordinator.resolveIfNeeded(
                for: token,
                source: index.source,
                input: input,
                build: build
            )

            let derivedState = derivedCoordinator.displayState(for: token)
            guard derivedState.token == token else {
                return
            }

            guard state.token != token else {
                return
            }

            state = LibraryDisplayState(derivedState: derivedState, index: index)
        }
    }
}
