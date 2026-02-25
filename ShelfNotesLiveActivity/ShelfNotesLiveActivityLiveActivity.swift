//
//  ShelfNotesLiveActivityLiveActivity.swift
//  ShelfNotesLiveActivity
//
//  Live Activity (Phase 1: display-only)
//

import ActivityKit
import WidgetKit
import SwiftUI

struct ShelfNotesLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReadingSessionActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.isPaused ? "pause.fill" : "timer")
                        .accessibilityLabel(context.state.isPaused ? "Pausiert" : "Läuft")
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.bookTitle)
                        .font(.subheadline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isPaused {
                        Text(ReadingSessionDurationFormatter.format(context.state.pausedElapsedSeconds))
                            .monospacedDigit()
                    } else {
                        Text(context.state.effectiveStartDate, style: .timer)
                            .monospacedDigit()
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.isPaused ? "Session pausiert" : "Session läuft")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                if context.state.isPaused {
                    Text(ReadingSessionDurationFormatter.format(context.state.pausedElapsedSeconds))
                        .monospacedDigit()
                } else {
                    Text(context.state.effectiveStartDate, style: .timer)
                        .monospacedDigit()
                }
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "timer")
            }
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<ReadingSessionActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(context.attributes.bookTitle)
                .font(.headline)
                .lineLimit(2)

            HStack(spacing: 10) {
                Image(systemName: context.state.isPaused ? "pause.fill" : "timer")
                    .font(.subheadline)

                if context.state.isPaused {
                    Text(ReadingSessionDurationFormatter.format(context.state.pausedElapsedSeconds))
                        .font(.title3)
                        .monospacedDigit()

                    Text("Pausiert")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(context.state.effectiveStartDate, style: .timer)
                        .font(.title3)
                        .monospacedDigit()

                    Text("Liest…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview("Notification", as: .content, using: ReadingSessionActivityAttributes(bookID: UUID().uuidString, bookTitle: "Der Graf von Monte Christo")) {
    ShelfNotesLiveActivityLiveActivity()
} contentStates: {
    ReadingSessionActivityAttributes.ContentState(
        isPaused: false,
        effectiveStartDate: Date().addingTimeInterval(-125),
        pausedElapsedSeconds: 125
    )
    ReadingSessionActivityAttributes.ContentState(
        isPaused: true,
        effectiveStartDate: Date().addingTimeInterval(-8720),
        pausedElapsedSeconds: 8720
    )
}
