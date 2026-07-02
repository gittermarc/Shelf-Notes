//
//  ShelfNotesLiveActivityLiveActivity.swift
//  ShelfNotesLiveActivity
//
//  Reading Session Live Activity widget.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct ShelfNotesLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReadingSessionActivityAttributes.self) { context in
            let presentation = ReadingSessionLiveActivityPresentation(
                attributes: context.attributes,
                state: context.state
            )

            ReadingSessionLockScreenView(context: context)
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(ReadingSessionActivityTheme.accentColor(from: presentation.accentHex))
        } dynamicIsland: { context -> DynamicIsland in
            let presentation = ReadingSessionLiveActivityPresentation(
                attributes: context.attributes,
                state: context.state
            )

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ReadingSessionDynamicIslandLeadingView(context: context)
                }

                DynamicIslandExpandedRegion(.center) {
                    ReadingSessionDynamicIslandCenterView(context: context)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    ReadingSessionDynamicIslandTrailingView(context: context)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    ReadingSessionDynamicIslandBottomView(context: context)
                }
            } compactLeading: {
                ReadingSessionDynamicIslandCompactLeadingView(context: context)
            } compactTrailing: {
                ReadingSessionDynamicIslandCompactTrailingView(context: context)
            } minimal: {
                ReadingSessionDynamicIslandMinimalView(context: context)
            }
            .keylineTint(ReadingSessionActivityTheme.accentColor(from: presentation.accentHex))
        }
    }
}

#Preview("Notification", as: .content, using: ReadingSessionActivityAttributes(
    bookID: UUID().uuidString,
    bookTitle: "Der Graf von Monte Christo",
    bookAuthor: "Alexandre Dumas",
    attemptName: "2. Durchgang",
    hasCover: false,
    coverRevision: nil,
    accentHex: "#F5B642"
)) {
    ShelfNotesLiveActivityLiveActivity()
} contentStates: {
    ReadingSessionActivityAttributes.ContentState(
        isPaused: false,
        effectiveStartDate: Date().addingTimeInterval(-125),
        pausedElapsedSeconds: 125,
        snapshot: ReadingSessionLiveActivitySnapshot(
            bookID: UUID(),
            bookTitle: "Der Graf von Monte Christo",
            bookAuthor: "Alexandre Dumas",
            attemptName: "2. Durchgang",
            pageCount: 1_280,
            pagesRead: 420,
            remainingPages: 860,
            progressFraction: 0.33,
            challengeTitle: "Tagesmission",
            challengeDetail: "Noch 12 Minuten",
            challengeProgressFraction: 0.6,
            hasCover: false,
            accentHex: "#F5B642"
        )
    )

    ReadingSessionActivityAttributes.ContentState(
        isPaused: true,
        effectiveStartDate: Date().addingTimeInterval(-8_720),
        pausedElapsedSeconds: 8_720,
        snapshot: ReadingSessionLiveActivitySnapshot(
            bookID: UUID(),
            bookTitle: "Der Graf von Monte Christo",
            bookAuthor: "Alexandre Dumas",
            pageCount: 1_280,
            pagesRead: 420,
            remainingPages: 860,
            progressFraction: 0.33,
            stateLabel: ReadingSessionLiveActivitySnapshot.pausedStateLabel,
            hasCover: false,
            accentHex: "#F5B642"
        )
    )
}
