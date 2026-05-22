//
//  SyncedThumbnailCacheKey.swift
//  Shelf Notes
//

import Foundation

enum SyncedThumbnailCacheKey {
    static func make(bookID: UUID, data: Data) -> String {
        "\(bookID.uuidString)-\(fingerprint(data))"
    }

    static func fingerprint(_ data: Data) -> String {
        func readUInt64(_ slice: Data) -> UInt64 {
            var value: UInt64 = 0
            withUnsafeMutableBytes(of: &value) { buffer in
                _ = slice.copyBytes(to: buffer)
            }
            return value
        }

        let first: UInt64
        let last: UInt64

        if data.count >= 8 {
            first = readUInt64(data.prefix(8))
            last = readUInt64(data.suffix(8))
        } else if !data.isEmpty {
            first = UInt64(data.first ?? 0)
            last = UInt64(data.last ?? 0)
        } else {
            first = 0
            last = 0
        }

        return "\(data.count)-\(first)-\(last)"
    }
}
