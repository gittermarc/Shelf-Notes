import Foundation
import Testing
@testable import Shelf_Notes

struct ChallengePreferencesTests {
    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "ChallengePreferencesTests-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    @Test func defaultContainsWeeklyAndMonthly() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = ChallengePreferencesStore.load(userDefaults: defaults)

        #expect(preferences.enabledKinds == [.weekly, .monthly])
        #expect(preferences.preset == .custom)
    }

    @Test func allMissionsPresetEnablesAllKinds() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        ChallengePreferencesStore.savePreset(.allMissions, userDefaults: defaults)
        let preferences = ChallengePreferencesStore.load(userDefaults: defaults)

        #expect(preferences.enabledKinds == [.daily, .weekly, .monthly, .yearly])
        #expect(preferences.preset == .allMissions)
    }

    @Test func pausedPresetDisablesAllKinds() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        ChallengePreferencesStore.savePreset(.paused, userDefaults: defaults)
        let preferences = ChallengePreferencesStore.load(userDefaults: defaults)

        #expect(preferences.enabledKinds.isEmpty)
        #expect(preferences.preset == .paused)
        #expect(defaults.string(forKey: ChallengePreferencesStorageKey.enabledKinds) == "")
    }

    @Test func customSelectionStaysSerializableAndOrdered() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        ChallengePreferencesStore.saveEnabledKinds([.yearly, .daily, .daily], userDefaults: defaults)
        let preferences = ChallengePreferencesStore.load(userDefaults: defaults)

        #expect(defaults.string(forKey: ChallengePreferencesStorageKey.enabledKinds) == "daily,yearly")
        #expect(preferences.enabledKinds == [.daily, .yearly])
        #expect(preferences.preset == .custom)
    }

    @Test func invalidStoredValuesFallbackWithoutCrash() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("future,wat", forKey: ChallengePreferencesStorageKey.enabledKinds)
        defaults.set("not-a-preset", forKey: ChallengePreferencesStorageKey.preset)
        let preferences = ChallengePreferencesStore.load(userDefaults: defaults)

        #expect(preferences.enabledKinds == [.weekly, .monthly])
        #expect(preferences.preset == .custom)
    }

    @Test func storedPresetMismatchResolvesToActualSelection() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("monthly", forKey: ChallengePreferencesStorageKey.enabledKinds)
        defaults.set(ChallengePreferencesPreset.allMissions.rawValue, forKey: ChallengePreferencesStorageKey.preset)
        let preferences = ChallengePreferencesStore.load(userDefaults: defaults)

        #expect(preferences.enabledKinds == [.monthly])
        #expect(preferences.preset == .monthlyOnly)
    }
}
