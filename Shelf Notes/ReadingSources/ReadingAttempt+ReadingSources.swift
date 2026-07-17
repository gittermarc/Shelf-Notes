//
//  ReadingAttempt+ReadingSources.swift
//  Shelf Notes
//

import Foundation

extension ReadingAttempt {
    var progressEventsSafe: [ReadingProgressEvent] {
        get { progressEvents ?? [] }
        set { progressEvents = newValue }
    }

    var annotationsSafe: [ReadingAnnotation] {
        get { annotations ?? [] }
        set { annotations = newValue }
    }

    var readingMedium: ReadingMedium {
        get { ReadingMedium.fromPersisted(readingMediumRawValue) }
        set {
            readingMediumRawValue = newValue.rawValue
            updatedAt = Date()
        }
    }

    var defaultProvider: ReadingProvider {
        get { ReadingProvider.fromPersisted(defaultProviderRawValue) }
        set {
            defaultProviderRawValue = newValue.rawValue
            updatedAt = Date()
        }
    }

    var progressUnit: ReadingProgressUnit {
        get { ReadingProgressUnit.fromPersisted(progressUnitRawValue) }
        set {
            progressUnitRawValue = newValue.rawValue
            updatedAt = Date()
        }
    }
}
