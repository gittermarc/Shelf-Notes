import Foundation
import Testing
@testable import Shelf_Notes

struct ReadingProgressInputBuilderTests {
    private let timestamp = Date(timeIntervalSince1970: 10_000)

    @Test func emptyPageInputCreatesSessionWithoutProgress() throws {
        let submission = try ReadingProgressInputBuilder.makeSubmission(
            state: ReadingProgressInputState(),
            configuration: pageConfiguration(),
            occurredAt: timestamp
        ).get()

        #expect(submission.progressUpdate == nil)
        #expect(submission.mutationMode == .standard)
        #expect(submission.pagesDelta == nil)
    }

    @Test func positivePagesCreateDeltaUpdate() throws {
        var state = ReadingProgressInputState()
        state.pagesText = "25"

        let submission = try ReadingProgressInputBuilder.makeSubmission(
            state: state,
            configuration: pageConfiguration(),
            occurredAt: timestamp
        ).get()

        #expect(submission.pagesDelta == 25)
        #expect(submission.progressUpdate?.unit == .pages)
        #expect(submission.progressUpdate?.semantics == .delta)
    }

    @Test func percentageUsesAbsoluteZeroToHundredValue() throws {
        var state = ReadingProgressInputState()
        state.percentageText = "40"

        let submission = try ReadingProgressInputBuilder.makeSubmission(
            state: state,
            configuration: percentageConfiguration(current: 0.2),
            occurredAt: timestamp
        ).get()

        #expect(submission.progressUpdate?.nativeValue == 40)
        #expect(submission.progressUpdate?.totalValue == 100)
        #expect(submission.progressUpdate?.normalizedProgress == 0.4)
    }

    @Test func lowerPercentageRequiresExplicitCorrectionConfirmation() throws {
        var state = ReadingProgressInputState()
        state.percentageText = "40"
        let configuration = percentageConfiguration(current: 0.8)

        #expect(
            ReadingProgressInputBuilder.requiresCorrectionConfirmation(
                state: state,
                configuration: configuration
            )
        )

        switch ReadingProgressInputBuilder.makeSubmission(
            state: state,
            configuration: configuration,
            occurredAt: timestamp
        ) {
        case .success:
            Issue.record("A lower absolute progress must require confirmation.")
        case .failure(let error):
            #expect(error == .correctionConfirmationRequired(current: 80, proposed: 40))
        }

        state.confirmsCorrection = true
        let corrected = try ReadingProgressInputBuilder.makeSubmission(
            state: state,
            configuration: configuration,
            occurredAt: timestamp
        ).get()
        #expect(corrected.mutationMode == .correction)
        #expect(corrected.progressUpdate?.normalizedProgress == 0.4)
    }

    @Test func locatorPreservesNativeTextWithoutInventingPercentage() throws {
        var state = ReadingProgressInputState()
        state.locatorText = "Kapitel 7 · Abschnitt 3"

        let submission = try ReadingProgressInputBuilder.makeSubmission(
            state: state,
            configuration: locatorConfiguration(),
            occurredAt: timestamp
        ).get()

        #expect(submission.progressUpdate?.locator == "Kapitel 7 · Abschnitt 3")
        #expect(submission.progressUpdate?.normalizedProgress == nil)
    }

    @Test func locatorPercentageCorrectionRequiresConfirmation() throws {
        var state = ReadingProgressInputState()
        state.locatorText = "Kapitel 4"
        state.locatorPercentageText = "30"
        let configuration = ReadingProgressInputConfiguration(
            unit: .locator,
            currentProgress: ReadingProgressSnapshot(
                unit: .locator,
                nativeValue: 0,
                totalValue: nil,
                pagesRead: nil,
                remainingPages: nil,
                normalizedProgress: 0.6,
                locator: "Kapitel 8",
                isCompleted: false
            ),
            sourceTitle: "Andere E-Book-App",
            isManuallyTracked: true
        )

        #expect(
            ReadingProgressInputBuilder.requiresCorrectionConfirmation(
                state: state,
                configuration: configuration
            )
        )

        state.confirmsCorrection = true
        let submission = try ReadingProgressInputBuilder.makeSubmission(
            state: state,
            configuration: configuration,
            occurredAt: timestamp
        ).get()

        #expect(submission.mutationMode == .correction)
        #expect(submission.progressUpdate?.locator == "Kapitel 4")
        #expect(submission.progressUpdate?.normalizedProgress == 0.3)
    }

    @Test func noneUnitAllowsDurationAndNoteOnly() throws {
        let configuration = ReadingProgressInputConfiguration(
            unit: .none,
            currentProgress: .unknown(unit: .none),
            sourceTitle: "Quelle ohne Messwert",
            isManuallyTracked: true
        )

        let submission = try ReadingProgressInputBuilder.makeSubmission(
            state: ReadingProgressInputState(),
            configuration: configuration,
            occurredAt: timestamp
        ).get()

        #expect(submission.progressUpdate == nil)
        #expect(submission.mutationMode == .standard)
    }

    @Test func explicitFinishCreatesCompletionUpdateForEveryUnit() throws {
        for unit in ReadingProgressUnit.allCases {
            var state = ReadingProgressInputState()
            state.marksBookFinished = true
            let snapshot = ReadingProgressSnapshot.unknown(unit: unit)
            let configuration = ReadingProgressInputConfiguration(
                unit: unit,
                currentProgress: snapshot,
                sourceTitle: "Quelle",
                isManuallyTracked: true
            )

            let submission = try ReadingProgressInputBuilder.makeSubmission(
                state: state,
                configuration: configuration,
                occurredAt: timestamp
            ).get()

            #expect(submission.progressUpdate?.semantics == .completion)
            #expect(submission.progressUpdate?.normalizedProgress == 1)
        }
    }

    private func pageConfiguration() -> ReadingProgressInputConfiguration {
        ReadingProgressInputConfiguration(
            unit: .pages,
            currentProgress: ReadingProgressSnapshot(
                unit: .pages,
                nativeValue: 20,
                totalValue: 100,
                pagesRead: 20,
                remainingPages: 80,
                normalizedProgress: 0.2,
                locator: nil,
                isCompleted: false
            ),
            remainingPages: 80,
            sourceTitle: "Physisches Buch",
            isManuallyTracked: true
        )
    }

    private func percentageConfiguration(current: Double) -> ReadingProgressInputConfiguration {
        ReadingProgressInputConfiguration(
            unit: .percentage,
            currentProgress: ReadingProgressSnapshot(
                unit: .percentage,
                nativeValue: current * 100,
                totalValue: 100,
                pagesRead: nil,
                remainingPages: nil,
                normalizedProgress: current,
                locator: nil,
                isCompleted: false
            ),
            sourceTitle: "Kindle",
            isManuallyTracked: true
        )
    }

    private func locatorConfiguration() -> ReadingProgressInputConfiguration {
        ReadingProgressInputConfiguration(
            unit: .locator,
            currentProgress: .unknown(unit: .locator),
            sourceTitle: "EPUB",
            isManuallyTracked: true
        )
    }
}
