//
//  ChallengeCelebrationConfiguration.swift
//  Shelf Notes
//
//  Pure configuration for challenge celebration motion and feedback.
//

import Foundation

nonisolated struct ChallengeCelebrationConfiguration: Equatable, Sendable {
    let animationsEnabled: Bool
    let hapticsEnabled: Bool
    let reduceMotion: Bool

    init(
        animationsEnabled: Bool = ChallengePreferences.defaultCelebrationsEnabled,
        hapticsEnabled: Bool = ChallengePreferences.defaultHapticsEnabled,
        reduceMotion: Bool = false
    ) {
        self.animationsEnabled = animationsEnabled
        self.hapticsEnabled = hapticsEnabled
        self.reduceMotion = reduceMotion
    }

    var allowsMotion: Bool {
        animationsEnabled && !reduceMotion
    }

    var allowsBurst: Bool {
        allowsMotion
    }

    var allowsProgressAnimation: Bool {
        allowsMotion
    }

    var allowsTrophyScale: Bool {
        allowsMotion
    }

    var allowsHaptics: Bool {
        hapticsEnabled
    }

    static func make(preferences: ChallengePreferences, reduceMotion: Bool) -> ChallengeCelebrationConfiguration {
        ChallengeCelebrationConfiguration(
            animationsEnabled: preferences.celebrationsEnabled,
            hapticsEnabled: preferences.hapticsEnabled,
            reduceMotion: reduceMotion
        )
    }
}

nonisolated enum ChallengeCelebrationState: Equatable, Sendable {
    case none
    case readyToClaim
    case claimed

    var isHighlighted: Bool {
        self != .none
    }

    var title: String {
        switch self {
        case .none:
            return ""
        case .readyToClaim:
            return "Belohnung bereit"
        case .claimed:
            return "Gesichert"
        }
    }

    var systemImage: String {
        switch self {
        case .none:
            return "circle"
        case .readyToClaim:
            return "sparkles"
        case .claimed:
            return "checkmark.seal.fill"
        }
    }
}
