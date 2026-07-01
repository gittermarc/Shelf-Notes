import Foundation

nonisolated struct ReadingTimelineSourceSignature: Hashable, Sendable {
    let bookCount: Int
    let completionCount: Int
    let fingerprint: Int

    init(bookSnapshots: [ReadingTimelineBookSnapshot]) {
        bookCount = bookSnapshots.count
        completionCount = bookSnapshots.reduce(0) { $0 + $1.completions.count }

        var xorAgg = 0
        var sumAgg = 0
        for snapshot in bookSnapshots.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            var hasher = Hasher()
            hasher.combine(snapshot.id)
            hasher.combine(snapshot.title)
            hasher.combine(snapshot.author)
            hasher.combine(Self.dayStamp(snapshot.createdAt))
            hasher.combine(Self.dayStamp(snapshot.readFrom))
            hasher.combine(Self.dayStamp(snapshot.readTo))
            hasher.combine(snapshot.statusRawValue)
            hasher.combine(snapshot.pageCount ?? -1)
            hasher.combine(Self.ratingBucket(snapshot.userRatingAverage))
            for completion in snapshot.completions {
                hasher.combine(completion.id)
                hasher.combine(completion.attemptID)
                hasher.combine(completion.sequenceNumber)
                hasher.combine(Self.dayStamp(completion.startedAt))
                hasher.combine(Self.dayStamp(completion.finishedAt))
                hasher.combine(completion.pageCount ?? -1)
                hasher.combine(completion.isReread)
                hasher.combine(completion.isLegacyFallback)
            }
            let hash = hasher.finalize()
            xorAgg ^= hash
            sumAgg &+= hash
        }

        var finalHasher = Hasher()
        finalHasher.combine(bookCount)
        finalHasher.combine(completionCount)
        finalHasher.combine(xorAgg)
        finalHasher.combine(sumAgg)
        fingerprint = finalHasher.finalize()
    }

    private static func dayStamp(_ date: Date?) -> Int {
        guard let date else { return -1 }
        return dayStamp(date)
    }

    private static func dayStamp(_ date: Date) -> Int {
        Int(date.timeIntervalSince1970 / 86_400)
    }

    private static func ratingBucket(_ rating: Double?) -> Int {
        guard let rating else { return -1 }
        return Int((rating * 10).rounded())
    }
}
