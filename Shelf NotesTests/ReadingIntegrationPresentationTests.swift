import Testing
@testable import Shelf_Notes

struct ReadingIntegrationPresentationTests {
    @Test func settingsPresentationDoesNotShowMisleadingConnectedState() throws {
        let states = ReadingIntegrationPresentationBuilder.makeAll()
        let apple = try #require(states.first { $0.provider == .appleBooks })
        let google = try #require(states.first { $0.provider == .googleBooks })
        let local = try #require(states.first { $0.provider == .localFile })

        #expect(apple.availabilityTitle == "Begleitmodus")
        #expect(apple.progressModeTitle == "Manuell erfasst")
        #expect(apple.capabilityTitles == ["Leselink öffnen"])
        #expect(!apple.showsConnectedBadge)

        #expect(google.availabilityTitle == "Nicht verbunden")
        #expect(google.capabilityTitles.isEmpty)
        #expect(!google.showsConnectedBadge)

        #expect(local.availabilityTitle == "Folgt später")
        #expect(local.progressModeTitle == "Noch nicht verfügbar")
        #expect(local.capabilityTitles.isEmpty)
        #expect(!local.showsConnectedBadge)
    }

    @Test func attemptSourcePresentationAllowsChangeOnlyForMutableAttempts() {
        let mutable = ReadingAttemptSourcePresentationBuilder.make(
            hasActiveAttempt: true,
            medium: .ebook,
            provider: .kindle,
            progressUnit: .percentage,
            canChangeSource: true,
            isTimerActiveForBook: false
        )
        #expect(mutable.title == "Kindle")
        #expect(mutable.detail.contains("Prozent"))
        #expect(mutable.canChange)
        #expect(mutable.changeHint == nil)

        let running = ReadingAttemptSourcePresentationBuilder.make(
            hasActiveAttempt: true,
            medium: .ebook,
            provider: .kindle,
            progressUnit: .percentage,
            canChangeSource: true,
            isTimerActiveForBook: true
        )
        #expect(!running.canChange)
        #expect(running.changeHint == "Während der Timer läuft nicht änderbar")

        let locked = ReadingAttemptSourcePresentationBuilder.make(
            hasActiveAttempt: true,
            medium: .physical,
            provider: .none,
            progressUnit: .pages,
            canChangeSource: false,
            isTimerActiveForBook: false
        )
        #expect(!locked.canChange)
        #expect(locked.changeHint == "Nach Sessions oder Fortschritt gesperrt")

        let none = ReadingAttemptSourcePresentationBuilder.make(
            hasActiveAttempt: false,
            medium: .physical,
            provider: .none,
            progressUnit: .pages,
            canChangeSource: false,
            isTimerActiveForBook: false
        )
        #expect(none.title == "Lesequelle wählen")
        #expect(!none.canChange)
    }
}