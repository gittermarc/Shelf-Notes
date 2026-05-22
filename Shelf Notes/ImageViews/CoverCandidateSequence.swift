//
//  CoverCandidateSequence.swift
//  Shelf Notes
//

import Foundation

struct CoverCandidateSequence: Equatable {
    let candidates: [String]

    init(_ rawCandidates: [String]) {
        var cleaned: [String] = []
        for candidate in rawCandidates {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if !cleaned.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                cleaned.append(trimmed)
            }
        }
        self.candidates = cleaned
    }

    func url(at index: Int) -> URL? {
        guard index >= 0, index < candidates.count else { return nil }
        return URL(string: candidates[index])
    }

    func initialIndex(preferredURLString: String?) -> Int {
        guard let preferredURLString else { return 0 }
        let preferred = preferredURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !preferred.isEmpty else { return 0 }
        return candidates.firstIndex(where: { $0.caseInsensitiveCompare(preferred) == .orderedSame }) ?? 0
    }
}
