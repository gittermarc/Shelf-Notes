import Foundation
import Testing
@testable import Shelf_Notes

struct ReadingIntegrationCoordinatorTests {
    @Test @MainActor func companionTimerStartsBeforeOpeningReadingDestination() throws {
        let source = ReadingTimerSessionSourceSnapshot(
            readingAttemptID: UUID(),
            readingMedium: .ebook,
            readingProvider: .appleBooks,
            progressUnit: .percentage,
            origin: .timer,
            totalValue: 100
        )
        var events: [String] = []

        let expectedURL = try #require(URL(string: "https://books.apple.com/de/book/demo/id123456789"))
        let result = ReadingIntegrationCoordinator.startTimerAndOpenReadingDestinationIfPossible(
            request: ReadingIntegrationStartRequest(
                sourceSnapshot: source,
                references: [
                    ReadingProviderLaunchReference(
                        provider: .appleBooks,
                        canonicalURL: "https://books.apple.com/de/book/demo/id123456789"
                    )
                ]
            ),
            startTimer: {
                events.append("start")
                return nil
            },
            openReadingURL: { url in
                events.append("open:" + (url.host ?? ""))
            }
        )

        #expect(result == .opened(expectedURL))
        #expect(events == ["start", "open:books.apple.com"])
    }

    @Test @MainActor func companionTimerWithoutReadingLinkShowsGuidanceAfterStartingTimer() {
        let source = ReadingTimerSessionSourceSnapshot(
            readingMedium: .ebook,
            readingProvider: .kindle,
            progressUnit: .percentage,
            origin: .timer,
            totalValue: 100
        )
        var events: [String] = []

        let result = ReadingIntegrationCoordinator.startTimerAndOpenReadingDestinationIfPossible(
            request: ReadingIntegrationStartRequest(
                sourceSnapshot: source,
                references: []
            ),
            startTimer: {
                events.append("start")
                return nil
            },
            openReadingURL: { url in
                events.append("open:" + url.absoluteString)
            }
        )

        if case .missingReadingLink(let guidance) = result {
            #expect(guidance.provider == .kindle)
            #expect(result.userMessage == guidance.message)
            #expect(!result.isError)
        } else {
            Issue.record("Missing Kindle link should keep timer running and return guidance.")
        }
        #expect(events == ["start"])
    }

    @Test @MainActor func physicalTimerKeepsExistingSessionUXAndDoesNotOpenExternalDestination() {
        let source = ReadingTimerSessionSourceSnapshot.legacyPhysical
        var events: [String] = []

        let result = ReadingIntegrationCoordinator.startTimerAndOpenReadingDestinationIfPossible(
            request: ReadingIntegrationStartRequest(
                sourceSnapshot: source,
                references: []
            ),
            startTimer: {
                events.append("start")
                return nil
            },
            openReadingURL: { url in
                events.append("open:" + url.absoluteString)
            }
        )

        #expect(result == .startedWithoutExternalDestination)
        #expect(events == ["start"])
        #expect(ReadingSourceSelection.physical.isAvailable)
        #expect(ReadingSourceSelection.physical.progressUnit == .pages)
        #expect(ReadingSourceSelection.physical.provider == .none)
    }

    @Test @MainActor func blockedReadingLinkDoesNotOpenAfterTimerStart() {
        let source = ReadingTimerSessionSourceSnapshot(
            readingMedium: .ebook,
            readingProvider: .appleBooks,
            progressUnit: .percentage,
            origin: .timer,
            totalValue: 100
        )
        var events: [String] = []

        let result = ReadingIntegrationCoordinator.startTimerAndOpenReadingDestinationIfPossible(
            request: ReadingIntegrationStartRequest(
                sourceSnapshot: source,
                references: [ReadingProviderLaunchReference(provider: .appleBooks, canonicalURL: "https://example.com/book")]
            ),
            startTimer: {
                events.append("start")
                return nil
            },
            openReadingURL: { url in
                events.append("open:" + url.absoluteString)
            }
        )

        #expect(result.isError)
        #expect(result.userMessage?.contains("Leselink") == true)
        #expect(events == ["start"])
    }
}