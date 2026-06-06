//
//  StorageMode.swift
//  Shelf Notes
//
//  Describes the SwiftData storage mode used during app bootstrap.
//

import Foundation

nonisolated enum StorageMode: Equatable {
    case cloudKit
    case localOnly
    case inMemory

    /// Identifier used to run one-time data repairs per persistent store.
    ///
    /// CloudKit and Local-only stores intentionally use separate persistent stores,
    /// so repairs must run once for each persistent scope.
    var collectionRepairScope: String? {
        switch self {
        case .cloudKit:
            return "cloudKit"
        case .localOnly:
            return "localOnly"
        case .inMemory:
            return nil
        }
    }
}
