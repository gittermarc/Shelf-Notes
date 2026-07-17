import Foundation
import Testing
@testable import Shelf_Notes

struct ReadingSourceRawValueTests {

    @Test func rawValuesRemainStableAndRoundTrip() throws {
        #expect(ReadingMedium.allCases.map(\.rawValue) == [
            "physical",
            "ebook"
        ])
        #expect(ReadingProvider.allCases.map(\.rawValue) == [
            "none",
            "appleBooks",
            "kindle",
            "googleBooks",
            "localFile",
            "other"
        ])
        #expect(ReadingProgressUnit.allCases.map(\.rawValue) == [
            "pages",
            "percentage",
            "locator",
            "none"
        ])
        #expect(ReadingSessionOrigin.allCases.map(\.rawValue) == [
            "legacy",
            "timer",
            "quickLog",
            "providerImport",
            "integratedReader",
            "shareExtension"
        ])
        #expect(ReadingAnnotationKind.allCases.map(\.rawValue) == [
            "highlight",
            "note",
            "bookmark"
        ])

        for value in ReadingMedium.allCases {
            let decoded = try roundTrip(value)
            #expect(ReadingMedium.fromPersisted(value.rawValue) == value)
            #expect(decoded == value)
        }
        for value in ReadingProvider.allCases {
            let decoded = try roundTrip(value)
            #expect(ReadingProvider.fromPersisted(value.rawValue) == value)
            #expect(decoded == value)
        }
        for value in ReadingProgressUnit.allCases {
            let decoded = try roundTrip(value)
            #expect(ReadingProgressUnit.fromPersisted(value.rawValue) == value)
            #expect(decoded == value)
        }
        for value in ReadingSessionOrigin.allCases {
            let decoded = try roundTrip(value)
            #expect(ReadingSessionOrigin.fromPersisted(value.rawValue) == value)
            #expect(decoded == value)
        }
        for value in ReadingAnnotationKind.allCases {
            let decoded = try roundTrip(value)
            #expect(ReadingAnnotationKind.fromPersisted(value.rawValue) == value)
            #expect(decoded == value)
        }
    }

    @Test func unknownPersistedValuesUseSafeFallbacks() throws {
        #expect(ReadingMedium.fromPersisted("futureMedium") == .physical)
        #expect(ReadingProvider.fromPersisted(" futureProvider ") == .none)
        #expect(ReadingProgressUnit.fromPersisted("chapters") == .none)
        #expect(ReadingSessionOrigin.fromPersisted("automaticSync") == .legacy)
        #expect(ReadingAnnotationKind.fromPersisted("drawing") == .note)

        let medium = try decodeUnknown(ReadingMedium.self, rawValue: "futureMedium")
        let provider = try decodeUnknown(ReadingProvider.self, rawValue: "futureProvider")
        let progressUnit = try decodeUnknown(ReadingProgressUnit.self, rawValue: "chapters")
        let origin = try decodeUnknown(ReadingSessionOrigin.self, rawValue: "automaticSync")
        let annotationKind = try decodeUnknown(ReadingAnnotationKind.self, rawValue: "drawing")

        #expect(medium == .physical)
        #expect(provider == .none)
        #expect(progressUnit == .none)
        #expect(origin == .legacy)
        #expect(annotationKind == .note)
    }

    private func roundTrip<Value: Codable>(_ value: Value) throws -> Value {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(Value.self, from: data)
    }

    private func decodeUnknown<Value: Decodable>(
        _ type: Value.Type,
        rawValue: String
    ) throws -> Value {
        let data = try JSONEncoder().encode(rawValue)
        return try JSONDecoder().decode(type, from: data)
    }
}
