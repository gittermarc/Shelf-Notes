//
//  ChallengeRefreshRequest.swift
//  Shelf Notes
//
//  Small value types for coalescing challenge refreshes after reading-session mutations.
//

import Foundation

struct ChallengeSessionMutationPayload: Equatable, Sendable {
    enum Kind: String, Equatable, Sendable {
        case saved
        case deleted
        case changed
    }

    let kind: Kind
    let sessionSnapshot: SavedReadingSessionSnapshot?
    let didMarkBookFinished: Bool

    var bookID: UUID? {
        sessionSnapshot?.bookID
    }

    var deduplicationKey: String {
        switch kind {
        case .saved:
            if let sessionSnapshot {
                return "saved:\(sessionSnapshot.id.uuidString)"
            }
            return "saved:unknown"
        case .deleted:
            if let sessionSnapshot {
                return "deleted:\(sessionSnapshot.id.uuidString)"
            }
            return "deleted:unknown"
        case .changed:
            return "changed:reading-sessions"
        }
    }

    static func saved(
        sessionSnapshot: SavedReadingSessionSnapshot,
        didMarkBookFinished: Bool
    ) -> ChallengeSessionMutationPayload {
        ChallengeSessionMutationPayload(
            kind: .saved,
            sessionSnapshot: sessionSnapshot,
            didMarkBookFinished: didMarkBookFinished
        )
    }

    static func changed() -> ChallengeSessionMutationPayload {
        ChallengeSessionMutationPayload(
            kind: .changed,
            sessionSnapshot: nil,
            didMarkBookFinished: false
        )
    }

    static func deleted(sessionSnapshot: SavedReadingSessionSnapshot) -> ChallengeSessionMutationPayload {
        ChallengeSessionMutationPayload(
            kind: .deleted,
            sessionSnapshot: sessionSnapshot,
            didMarkBookFinished: false
        )
    }
}

struct ChallengeRefreshRequest: Equatable, Sendable {
    let payload: ChallengeSessionMutationPayload
    let requiresChallengePreparation: Bool
    let postsReadingSessionChange: Bool

    var deduplicationKey: String {
        payload.deduplicationKey
    }

    static func readingSessionSaved(
        sessionSnapshot: SavedReadingSessionSnapshot,
        didMarkBookFinished: Bool
    ) -> ChallengeRefreshRequest {
        ChallengeRefreshRequest(
            payload: .saved(
                sessionSnapshot: sessionSnapshot,
                didMarkBookFinished: didMarkBookFinished
            ),
            requiresChallengePreparation: true,
            postsReadingSessionChange: true
        )
    }

    static func readingSessionChanged() -> ChallengeRefreshRequest {
        ChallengeRefreshRequest(
            payload: .changed(),
            requiresChallengePreparation: true,
            postsReadingSessionChange: true
        )
    }

    static func readingSessionDeleted(sessionSnapshot: SavedReadingSessionSnapshot) -> ChallengeRefreshRequest {
        ChallengeRefreshRequest(
            payload: .deleted(sessionSnapshot: sessionSnapshot),
            requiresChallengePreparation: true,
            postsReadingSessionChange: true
        )
    }
}

struct ChallengeRefreshBatch: Equatable, Sendable {
    private(set) var requests: [ChallengeRefreshRequest]

    init(requests: [ChallengeRefreshRequest] = []) {
        self.requests = []
        append(contentsOf: requests)
    }

    var isEmpty: Bool {
        requests.isEmpty
    }

    var requiresChallengePreparation: Bool {
        requests.contains(where: \.requiresChallengePreparation)
    }

    var postsReadingSessionChange: Bool {
        requests.contains(where: \.postsReadingSessionChange)
    }

    var readingSessionChangeNotificationCount: Int {
        postsReadingSessionChange ? 1 : 0
    }

    var savedSessionPayloads: [ChallengeSessionMutationPayload] {
        requests
            .map(\.payload)
            .filter { $0.kind == .saved && $0.sessionSnapshot != nil }
    }

    var mutationPayloads: [ChallengeSessionMutationPayload] {
        requests.map(\.payload)
    }

    mutating func append(_ request: ChallengeRefreshRequest) {
        guard !requests.contains(where: { $0.deduplicationKey == request.deduplicationKey }) else { return }
        requests.append(request)
    }

    mutating func append(contentsOf newRequests: [ChallengeRefreshRequest]) {
        for request in newRequests {
            append(request)
        }
    }
}
