//
//  BookImportViewModel+Filtering.swift
//  Shelf Notes
//
//  Local quality filtering + mapping of fetched volumes into UI results.
//

import Foundation

@MainActor
extension BookImportViewModel {

    func applyLocalFilters() {
        let input = BookImportFilterEngine.Input(
            volumes: fetchedVolumes,
            selectedCategory: category,
            onlyWithCover: onlyWithCover,
            onlyWithISBN: onlyWithISBN,
            onlyWithDescription: onlyWithDescription,
            hideAlreadyInLibrary: hideAlreadyInLibrary,
            collapseDuplicates: collapseDuplicates,
            sortOption: sortOption
        )

        let output = filterEngine.apply(input: input, isAlreadyAdded: { [weak self] in
            guard let self else { return false }
            return self.isAlreadyAdded($0)
        })

        availableCategories = output.availableCategories
        results = output.results
    }

}
