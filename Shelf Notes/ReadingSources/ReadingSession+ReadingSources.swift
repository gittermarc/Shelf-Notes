//
//  ReadingSession+ReadingSources.swift
//  Shelf Notes
//

extension ReadingSession {
    var medium: ReadingMedium {
        get { ReadingMedium.fromPersisted(mediumRawValue) }
        set { mediumRawValue = newValue.rawValue }
    }

    var provider: ReadingProvider {
        get { ReadingProvider.fromPersisted(providerRawValue) }
        set { providerRawValue = newValue.rawValue }
    }

    var origin: ReadingSessionOrigin {
        get { ReadingSessionOrigin.fromPersisted(originRawValue) }
        set { originRawValue = newValue.rawValue }
    }

    var progressUnit: ReadingProgressUnit {
        get { ReadingProgressUnit.fromPersisted(progressUnitRawValue) }
        set { progressUnitRawValue = newValue.rawValue }
    }
}
