//
//  ChallengeHaptics.swift
//  Shelf Notes
//
//  Tiny wrapper so haptics remain optional and test-friendly.
//

import Foundation

#if canImport(UIKit)
import UIKit
#endif

@MainActor
enum ChallengeHaptics {
    static func success(enabled: Bool) {
        guard enabled else { return }

        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        #endif
    }
}
