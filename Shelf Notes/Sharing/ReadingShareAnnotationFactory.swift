//
//  ReadingShareAnnotationFactory.swift
//  Shelf Notes
//

import Foundation

enum ReadingShareAnnotationFactory {
    static func makeAnnotation(
        item: ReadingShareInboxItem,
        book: Book,
        now: Date = Date()
    ) -> ReadingAnnotation {
        let kind = annotationKind(for: item.payload)
        return ReadingAnnotation(
            book: book,
            readingAttempt: book.activeReadingAttempt,
            kind: kind,
            provider: item.payload.provider,
            origin: .shareExtension,
            selectedText: selectedText(for: item.payload, kind: kind),
            note: note(for: item.payload, kind: kind),
            locator: nil,
            normalizedProgress: nil,
            externalIdentifier: item.id,
            deduplicationKey: deduplicationKey(for: item),
            importedAt: now,
            createdAt: now,
            updatedAt: now
        )
    }

    static func deduplicationKey(for item: ReadingShareInboxItem) -> String {
        "shareExtension:\(item.contentFingerprint)"
    }

    private static func annotationKind(for payload: ReadingSharePayload) -> ReadingAnnotationKind {
        switch payload.kind {
        case .bookLink:
            return .bookmark
        case .textWithURL:
            return payload.text == nil ? .bookmark : .highlight
        case .text:
            return .note
        }
    }

    private static func selectedText(
        for payload: ReadingSharePayload,
        kind: ReadingAnnotationKind
    ) -> String? {
        kind == .highlight ? payload.text : nil
    }

    private static func note(
        for payload: ReadingSharePayload,
        kind: ReadingAnnotationKind
    ) -> String? {
        switch kind {
        case .highlight:
            return payload.title
        case .note:
            return payload.text ?? payload.title
        case .bookmark:
            return payload.title
        }
    }
}
