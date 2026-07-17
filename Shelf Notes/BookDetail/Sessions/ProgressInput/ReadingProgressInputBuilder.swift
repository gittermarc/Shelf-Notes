//
//  ReadingProgressInputBuilder.swift
//  Shelf Notes
//

import Foundation

nonisolated enum ReadingProgressInputBuilder {
    static func makeSubmission(
        state: ReadingProgressInputState,
        configuration: ReadingProgressInputConfiguration,
        occurredAt: Date
    ) -> Result<ReadingProgressInputSubmission, ReadingProgressInputError> {
        let updateResult = makeUpdate(
            state: state,
            unit: configuration.unit,
            occurredAt: occurredAt
        )

        let update: ReadingProgressUpdate?
        switch updateResult {
        case .success(let value):
            update = value
        case .failure(let error):
            return .failure(error)
        }

        let mutationMode: ReadingProgressMutationMode = state.confirmsCorrection ? .correction : .standard

        if state.confirmsCorrection == false,
           let proposed = proposedNormalizedProgress(update),
           let current = configuration.currentProgress.normalizedProgress,
           proposed + 0.000_000_1 < current {
            return .failure(
                .correctionConfirmationRequired(
                    current: Int((current * 100).rounded()),
                    proposed: Int((proposed * 100).rounded())
                )
            )
        }

        switch ReadingProgressMutationPlanner.makePlan(
            current: configuration.currentProgress,
            update: update,
            mode: mutationMode,
            allowsPageOverflow: configuration.allowsPageOverflow
        ) {
        case .success:
            return .success(
                ReadingProgressInputSubmission(
                    progressUpdate: update,
                    mutationMode: mutationMode
                )
            )
        case .failure(let error):
            return .failure(.mutation(error))
        }
    }

    static func requiresCorrectionConfirmation(
        state: ReadingProgressInputState,
        configuration: ReadingProgressInputConfiguration
    ) -> Bool {
        guard state.marksBookFinished == false,
              let update = try? makeUpdate(
                state: state,
                unit: configuration.unit,
                occurredAt: .distantPast
              ).get(),
              let proposed = proposedNormalizedProgress(update),
              let current = configuration.currentProgress.normalizedProgress else {
            return false
        }
        return proposed + 0.000_000_1 < current
    }

    private static func makeUpdate(
        state: ReadingProgressInputState,
        unit: ReadingProgressUnit,
        occurredAt: Date
    ) -> Result<ReadingProgressUpdate?, ReadingProgressInputError> {
        if state.marksBookFinished {
            return .success(
                ReadingProgressUpdate.completed(
                    occurredAt: occurredAt,
                    unit: unit
                )
            )
        }

        switch unit {
        case .pages:
            let value = normalizedText(state.pagesText)
            guard value.isEmpty == false else { return .success(nil) }
            guard let pages = Int(value), pages > 0 else {
                return .failure(.invalidPages)
            }
            return .success(.pageDelta(pages, occurredAt: occurredAt))

        case .percentage:
            let value = normalizedText(state.percentageText)
            guard value.isEmpty == false else { return .success(nil) }
            guard let percent = percentValue(value) else {
                return .failure(.invalidPercentage)
            }
            return .success(
                .percentage(
                    nativeValue: percent,
                    totalValue: 100,
                    normalizedProgress: percent / 100,
                    occurredAt: occurredAt
                )
            )

        case .locator:
            let locator = normalizedText(state.locatorText)
            let percentage = normalizedText(state.locatorPercentageText)
            guard locator.isEmpty == false || percentage.isEmpty == false else {
                return .success(nil)
            }
            guard locator.isEmpty == false else {
                return .failure(.missingLocator)
            }

            let normalizedProgress: Double?
            if percentage.isEmpty {
                normalizedProgress = nil
            } else {
                guard let percent = percentValue(percentage) else {
                    return .failure(.invalidPercentage)
                }
                normalizedProgress = percent / 100
            }

            return .success(
                .locator(
                    locator,
                    normalizedProgress: normalizedProgress,
                    occurredAt: occurredAt
                )
            )

        case .none:
            return .success(nil)
        }
    }

    private static func proposedNormalizedProgress(_ update: ReadingProgressUpdate?) -> Double? {
        guard let update else { return nil }
        if update.semantics == .completion { return 1 }
        if let normalized = update.normalizedProgress, normalized.isFinite {
            return min(1, max(0, normalized))
        }
        if update.unit == .percentage,
           let native = update.nativeValue,
           native.isFinite {
            let total = update.totalValue.flatMap { $0.isFinite && $0 > 0 ? $0 : nil } ?? 100
            return min(1, max(0, native / total))
        }
        return nil
    }

    private static func percentValue(_ value: String) -> Double? {
        let decimalNormalized = value.replacingOccurrences(of: ",", with: ".")
        guard let percent = Double(decimalNormalized),
              percent.isFinite,
              percent >= 0,
              percent <= 100 else {
            return nil
        }
        return percent
    }

    private static func normalizedText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
