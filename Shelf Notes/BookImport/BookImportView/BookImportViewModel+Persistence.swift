//
//  BookImportViewModel+Persistence.swift
//  Shelf Notes
//
//  Quick-add persistence for imported volumes.
//

import Foundation
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

@MainActor
extension BookImportViewModel {

    func quickAdd(_ volume: GoogleBookVolume, status: ReadingStatus, modelContext: ModelContext) async {
        guard !isAlreadyAdded(volume) else { return }

        let newBook = volumeMapper.makeBook(from: volume, status: status)

        modelContext.insert(newBook)
        modelContext.saveWithDiagnostics()

        Task { @MainActor in
            await CoverThumbnailer.backfillThumbnailIfNeeded(for: newBook, modelContext: modelContext)
        }

        addedVolumeIDs.insert(volume.id)

        sessionQuickAddCount += 1
        onQuickAddActiveChanged?(sessionQuickAddCount > 0)

        if !didTriggerQuickAddCallback {
            didTriggerQuickAddCallback = true
            onQuickAddHappened?()
        }

        showUndo(for: newBook, volumeID: volume.id, status: status)

        #if canImport(UIKit)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        #endif
    }
}
