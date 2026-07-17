import Foundation
import SwiftData

nonisolated struct ProgressHubSessionMetricsSnapshot: Equatable, Sendable {
    let recentActivity: ReadingAnalyticsRecentActivity
    let aggregates: ReadingSessionAggregateSnapshot
    let signature: UInt64

    static let empty = ProgressHubSessionMetricsSnapshot(
        recentActivity: .empty,
        aggregates: .empty,
        signature: 0x7F4A_7C15_1D3D_0A2C
    )
}

@MainActor
enum ProgressHubSessionMetricsProvider {
    private static let batchSize = 256

    static func makeSnapshot(
        modelContext: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ProgressHubSessionMetricsSnapshot {
        PerformanceSignposter.measure("ProgressHub Session Snapshot") {
            makeSnapshotWithoutSignpost(
                modelContext: modelContext,
                now: now,
                calendar: calendar
            )
        }
    }

    private static func makeSnapshotWithoutSignpost(
        modelContext: ModelContext,
        now: Date,
        calendar: Calendar
    ) -> ProgressHubSessionMetricsSnapshot {
        var accumulator = ReadingAnalyticsRecentActivityBuilder.Accumulator(
            now: now,
            calendar: calendar
        )
        var aggregateRecords: [ReadingSessionAggregateRecord] = []
        aggregateRecords.reserveCapacity(batchSize)
        var signature = ProgressHubSessionMetricsSnapshot.empty.signature
        var consumedCount = 0
        var offset = 0

        while accumulator.shouldStop == false {
            let batch = fetchSessionBatch(
                modelContext: modelContext,
                limit: batchSize,
                offset: offset
            )

            if batch.isEmpty {
                break
            }

            for session in batch {
                let record = ReadingAnalyticsSessionRecord(session: session)
                consumedCount += 1
                combine(record: record, into: &signature)
                accumulator.consume(record)
                aggregateRecords.append(ReadingSessionAggregateRecord(session: session))

                if accumulator.shouldStop {
                    break
                }
            }

            if accumulator.shouldStop || batch.count < batchSize {
                break
            }

            offset += batch.count
        }

        signature &+= UInt64(consumedCount) &* 0xBF58_476D_1CE4_E5B9
        let aggregates = ReadingSessionAggregateBuilder.make(
            records: aggregateRecords,
            now: now,
            calendar: calendar
        )

        return ProgressHubSessionMetricsSnapshot(
            recentActivity: accumulator.makeRecentActivity(),
            aggregates: aggregates,
            signature: signature
        )
    }

    private static func fetchSessionBatch(
        modelContext: ModelContext,
        limit: Int,
        offset: Int
    ) -> [ReadingSession] {
        var descriptor = FetchDescriptor<ReadingSession>(
            sortBy: [
                SortDescriptor(\ReadingSession.startedAt, order: .reverse),
                SortDescriptor(\ReadingSession.createdAt, order: .reverse)
            ]
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private static func combine(
        record: ReadingAnalyticsSessionRecord,
        into aggregate: inout UInt64
    ) {
        var hasher = Hasher()
        hasher.combine(record.id)
        hasher.combine(record.startedAt.timeIntervalSinceReferenceDate)
        hasher.combine(record.durationSeconds)
        hasher.combine(record.createdAt.timeIntervalSinceReferenceDate)
        hasher.combine(record.progressUnitRawValue)
        hasher.combine(record.originRawValue)
        let hash = UInt64(bitPattern: Int64(hasher.finalize()))
        aggregate ^= hash &+ 0x9E37_79B9_7F4A_7C15 &+ (aggregate << 6) &+ (aggregate >> 2)
    }
}
