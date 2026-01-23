//
//  ModelContext+Diagnostics.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 23.01.26.
//

import Foundation
import SwiftData

extension ModelContext {
    /// Save and record a small diagnostic breadcrumb.
    ///
    /// - Returns: The error if saving failed, otherwise nil.
    @discardableResult
    func saveWithDiagnostics(
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> Error? {
        let source = String(describing: file) + ":" + String(line)

        do {
            try save()
            Task { @MainActor in
                SyncDiagnostics.shared.recordLocalSave(success: true, error: nil, source: source)
            }
            return nil
        } catch {
            Task { @MainActor in
                SyncDiagnostics.shared.recordLocalSave(success: false, error: error, source: source)
            }
            return error
        }
    }
}
