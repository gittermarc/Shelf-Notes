import Foundation
import Testing
@testable import Shelf_Notes

struct ChallengeCelebrationConfigurationTests {
    @Test func reduceMotionDisablesStrongAnimationsButKeepsContentAndHaptics() {
        let preferences = ChallengePreferences(
            enabledKinds: [.daily, .weekly],
            celebrationsEnabled: true,
            hapticsEnabled: true
        )

        let configuration = ChallengeCelebrationConfiguration.make(
            preferences: preferences,
            reduceMotion: true
        )

        #expect(configuration.animationsEnabled == true)
        #expect(configuration.reduceMotion == true)
        #expect(configuration.allowsMotion == false)
        #expect(configuration.allowsBurst == false)
        #expect(configuration.allowsProgressAnimation == false)
        #expect(configuration.allowsTrophyScale == false)
        #expect(configuration.allowsHaptics == true)
    }

    @Test func disabledCelebrationsUseQuietRewardPresentation() {
        let preferences = ChallengePreferences(
            enabledKinds: [.weekly, .monthly],
            celebrationsEnabled: false,
            hapticsEnabled: true
        )

        let configuration = ChallengeCelebrationConfiguration.make(
            preferences: preferences,
            reduceMotion: false
        )

        #expect(configuration.animationsEnabled == false)
        #expect(configuration.allowsMotion == false)
        #expect(configuration.allowsBurst == false)
        #expect(configuration.allowsProgressAnimation == false)
        #expect(configuration.allowsTrophyScale == false)
        #expect(configuration.allowsHaptics == true)
    }

    @Test func disabledHapticsSuppressOnlyHapticFeedback() {
        let preferences = ChallengePreferences(
            enabledKinds: [.daily, .weekly, .monthly, .yearly],
            celebrationsEnabled: true,
            hapticsEnabled: false
        )

        let configuration = ChallengeCelebrationConfiguration.make(
            preferences: preferences,
            reduceMotion: false
        )

        #expect(configuration.allowsMotion == true)
        #expect(configuration.allowsBurst == true)
        #expect(configuration.allowsProgressAnimation == true)
        #expect(configuration.allowsTrophyScale == true)
        #expect(configuration.allowsHaptics == false)
    }
}
