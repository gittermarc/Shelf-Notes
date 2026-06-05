import Foundation
import Testing
@testable import Shelf_Notes

struct TagSuggestionEngineTests {

    @Test func categoriesBecomeUsefulTagCandidates() {
        let target = makeSnapshot(
            1,
            categories: [
                "Fiction / Mystery & Detective / General",
                "Science Fiction",
                "Business & Economics"
            ],
            mainCategory: nil
        )

        let candidates = TagSuggestionEngine.categoryCandidates(for: target)

        #expect(candidates == ["Mystery", "Detective", "Sci-Fi", "Business", "Economics"])
    }

    @Test func suggestionsExcludeAlreadySelectedTagsAndKeepInnerHash() {
        let target = makeSnapshot(
            1,
            tags: [" #C# ", "Crime"],
            categories: ["C#", "Fiction / Mystery & Detective"]
        )
        let library = [
            target,
            makeSnapshot(2, tags: ["C#", "Noir"]),
            makeSnapshot(3, tags: ["Crime", "NYC"])
        ]

        let suggestions = TagSuggestionEngine.suggestions(for: target, in: library, limit: 20)
        let tags = suggestions.map(\.tag)

        #expect(!tags.contains("C#"))
        #expect(!tags.contains("Crime"))
        #expect(tags.contains("Noir"))
        #expect(tags.contains("NYC"))
    }

    @Test func duplicateAndBlankCandidatesAreIgnored() {
        let target = makeSnapshot(
            1,
            categories: ["  ", "#", "C#", "#C#", "General", "Fiction"]
        )

        let candidates = TagSuggestionEngine.categoryCandidates(for: target)

        #expect(candidates == ["C#"])
    }

    @Test func frequentTagsAreWeightedAndSortedAheadOfRareTags() {
        let target = makeSnapshot(1)
        let library = [
            target,
            makeSnapshot(2, tags: ["Fantasy"]),
            makeSnapshot(3, tags: ["fantasy"]),
            makeSnapshot(4, tags: ["Fantasy"]),
            makeSnapshot(5, tags: ["Essay"])
        ]

        let suggestions = TagSuggestionEngine.suggestions(for: target, in: library, limit: 10)

        #expect(suggestions.map(\.tag).prefix(2) == ["Fantasy", "Essay"])
        #expect(suggestions.first?.reasons.contains(.frequent) == true)
        #expect(suggestions.first?.existingTagCount == 3)
    }

    @Test func coTagSuggestionsUseTagsThatOftenAppearTogether() {
        let target = makeSnapshot(1, tags: ["Crime"])
        let library = [
            target,
            makeSnapshot(2, tags: ["Crime", "Noir"]),
            makeSnapshot(3, tags: ["crime", "NYC"]),
            makeSnapshot(4, tags: ["History", "Memoir"])
        ]

        let suggestions = TagSuggestionEngine.suggestions(for: target, in: library, limit: 10)
        let noir = suggestions.first { $0.tag == "Noir" }
        let nyc = suggestions.first { $0.tag == "NYC" }
        let history = suggestions.first { $0.tag == "History" }

        #expect(noir?.reasons.contains(.coTag) == true)
        #expect(nyc?.reasons.contains(.coTag) == true)
        #expect(history?.reasons.contains(.coTag) != true)
    }

    @Test func similarBooksContributeTheirTags() {
        let target = makeSnapshot(
            1,
            title: "Target",
            author: "Megan Example",
            categories: ["Fiction / Mystery & Detective"]
        )
        let library = [
            target,
            makeSnapshot(
                2,
                title: "Similar by Author",
                author: "Megan Example",
                tags: ["Noir"],
                categories: ["Fiction / Mystery & Detective"]
            ),
            makeSnapshot(
                3,
                title: "Unrelated",
                author: "Other Author",
                tags: ["Space"],
                categories: ["Science Fiction"]
            )
        ]

        let suggestions = TagSuggestionEngine.suggestions(for: target, in: library, limit: 10)
        let noir = suggestions.first { $0.tag == "Noir" }
        let space = suggestions.first { $0.tag == "Space" }

        #expect(noir?.reasons.contains(.similarBook) == true)
        #expect(noir?.relatedBookCount == 1)
        #expect(space?.reasons.contains(.similarBook) != true)
    }

    @Test func categorySuggestionsHaveUnderstandableReasons() {
        let target = makeSnapshot(
            1,
            categories: ["Biography und Autobiografie"]
        )

        let suggestions = TagSuggestionEngine.suggestions(for: target, in: [target], limit: 10)
        let biography = suggestions.first { $0.tag == "Biografien" }
        let autobiography = suggestions.first { $0.tag == "Autobiografien" }

        #expect(biography?.reasons == [.category])
        #expect(autobiography?.reasons == [.category])
        #expect(biography?.reasonLabel == "Aus Kategorie")
    }

    @Test func limitIsRespected() {
        let target = makeSnapshot(1)
        let library = [
            target,
            makeSnapshot(2, tags: ["A"]),
            makeSnapshot(3, tags: ["B"]),
            makeSnapshot(4, tags: ["C"])
        ]

        let suggestions = TagSuggestionEngine.suggestions(for: target, in: library, limit: 2)

        #expect(suggestions.count == 2)
    }

    @Test func explicitDomainIndexSuggestionsMatchLibraryEntryPoint() {
        let target = makeSnapshot(
            1,
            author: "Megan Example",
            tags: ["Crime"],
            categories: ["Fiction / Mystery & Detective"]
        )
        let library = [
            target,
            makeSnapshot(
                2,
                author: "Megan Example",
                tags: ["Crime", "Noir"],
                categories: ["Fiction / Mystery & Detective"]
            ),
            makeSnapshot(3, tags: ["History"]),
            makeSnapshot(4, tags: ["Sci-Fi"], categories: ["Science Fiction"])
        ]
        let index = TagsDomainIndex(suggestionSnapshots: library)

        let viaLibrary = TagSuggestionEngine.suggestions(for: target, in: library, limit: 10)
        let viaIndex = TagSuggestionEngine.suggestions(for: target, in: index, limit: 10)

        #expect(viaIndex.map(\.tag) == viaLibrary.map(\.tag))
        #expect(viaIndex.map(\.score) == viaLibrary.map(\.score))
        #expect(viaIndex.map(\.reasonLabel) == viaLibrary.map(\.reasonLabel))
        #expect(viaIndex.map(\.existingTagCount) == viaLibrary.map(\.existingTagCount))
        #expect(viaIndex.map(\.relatedBookCount) == viaLibrary.map(\.relatedBookCount))
    }

    @Test func domainIndexSuggestionsKeepCategoryContextAndExcludeSelectedTags() {
        let target = makeSnapshot(
            1,
            tags: ["Crime"],
            categories: ["Fiction / Mystery & Detective"]
        )
        let library = [
            target,
            makeSnapshot(2, tags: ["Crime", "Noir"]),
            makeSnapshot(3, tags: ["NYC"])
        ]
        let suggestions = TagSuggestionEngine.suggestions(
            for: target,
            in: TagsDomainIndex(suggestionSnapshots: library),
            limit: 10
        )
        let tags = suggestions.map(\.tag)
        let mystery = suggestions.first { $0.tag == "Mystery" }
        let noir = suggestions.first { $0.tag == "Noir" }

        #expect(!tags.contains("Crime"))
        #expect(mystery?.reasons == [.category])
        #expect(noir?.reasons.contains(.coTag) == true)
    }

    private func makeSnapshot(
        _ value: Int,
        title: String = "Test Book",
        author: String = "",
        tags: [String] = [],
        categories: [String] = [],
        mainCategory: String? = nil,
        status: ReadingStatus = .toRead
    ) -> TagSuggestionBookSnapshot {
        TagSuggestionBookSnapshot(
            id: fixedID(value),
            title: title,
            author: author,
            tags: tags,
            categories: categories,
            mainCategory: mainCategory,
            statusRawValue: status.rawValue
        )
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}
