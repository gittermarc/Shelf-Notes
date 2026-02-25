//
//  ShelfNotesLiveActivityLiveActivity.swift
//  ShelfNotesLiveActivity
//
//  Live Activity (Phase 1: display-only)
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

struct ShelfNotesLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReadingSessionActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    DynamicIslandCoverOrIcon(bookID: context.attributes.bookID, isPaused: context.state.isPaused)
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
                    LiveActivityControlsRow(context: context, size: .compact)
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
        HStack(alignment: .top, spacing: 12) {
            LiveActivityCoverView(bookID: context.attributes.bookID)

            VStack(alignment: .leading, spacing: 10) {
                Text(context.attributes.bookTitle)
                    .font(.headline)
                    .lineLimit(2)

                LiveActivityTimerLine(context: context)

                LiveActivityControlsRow(context: context, size: .regular)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct LiveActivityTimerLine: View {
    let context: ActivityViewContext<ReadingSessionActivityAttributes>

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if context.state.isPaused {
                Text(ReadingSessionDurationFormatter.format(context.state.pausedElapsedSeconds))
                    .font(.system(size: 30, weight: .semibold))
                    .monospacedDigit()

                Text("Pausiert")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(context.state.effectiveStartDate, style: .timer)
                    .font(.system(size: 30, weight: .semibold))
                    .monospacedDigit()

                Text("Liest…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private enum LiveActivityControlsSize {
    case regular
    case compact
}

private struct LiveActivityControlsRow: View {
    let context: ActivityViewContext<ReadingSessionActivityAttributes>
    let size: LiveActivityControlsSize

    var body: some View {
        if #available(iOS 17.0, *) {
            HStack(spacing: 10) {
                Button(intent: ReadingSessionTogglePauseIntent(bookID: context.attributes.bookID)) {
                    Label(context.state.isPaused ? "Weiter" : "Pause", systemImage: context.state.isPaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(.bordered)

                Button(intent: ReadingSessionStopIntent(bookID: context.attributes.bookID)) {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
            }
            .controlSize(size == .compact ? .mini : .small)
        } else {
            Text(context.state.isPaused ? "Session pausiert" : "Session läuft")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct LiveActivityCoverView: View {
    let bookID: String

    var body: some View {
        Group {
            if let uiImage = LiveActivityCoverLoader.load(bookIDString: bookID) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                    Image(systemName: "book.closed")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 56, height: 84)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct DynamicIslandCoverOrIcon: View {
    let bookID: String
    let isPaused: Bool

    var body: some View {
        if let uiImage = LiveActivityCoverLoader.load(bookIDString: bookID) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 32, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Image(systemName: isPaused ? "pause.fill" : "timer")
                .accessibilityLabel(isPaused ? "Pausiert" : "Läuft")
        }
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
