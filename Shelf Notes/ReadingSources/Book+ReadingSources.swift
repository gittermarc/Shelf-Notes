//
//  Book+ReadingSources.swift
//  Shelf Notes
//

extension Book {
    var readingProgressEventsSafe: [ReadingProgressEvent] {
        get { readingProgressEvents ?? [] }
        set { readingProgressEvents = newValue }
    }

    var externalReferencesSafe: [BookExternalReference] {
        get { externalReferences ?? [] }
        set { externalReferences = newValue }
    }

    var readingAnnotationsSafe: [ReadingAnnotation] {
        get { readingAnnotations ?? [] }
        set { readingAnnotations = newValue }
    }
}
