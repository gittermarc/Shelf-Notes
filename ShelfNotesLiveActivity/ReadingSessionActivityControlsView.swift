//
//  ReadingSessionActivityControlsView.swift
//  ShelfNotesLiveActivity
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

enum ReadingSessionActivityControlsMode: Equatable {
    case lockScreen
    case dynamicIsland

    var controlSize: ControlSize {
        switch self {
        case .lockScreen:
            return .mini
        case .dynamicIsland:
            return .mini
        }
    }

    var showsText: Bool {
        switch self {
        case .lockScreen:
            return true
        case .dynamicIsland:
            return false
        }
    }

    var spacing: CGFloat {
        switch self {
        case .lockScreen:
            return 6
        case .dynamicIsland:
            return 7
        }
    }
}

struct ReadingSessionActivityControlsView: View {
    let context: ActivityViewContext<ReadingSessionActivityAttributes>
    let presentation: ReadingSessionLiveActivityPresentation
    let mode: ReadingSessionActivityControlsMode

    private var accent: Color {
        ReadingSessionActivityTheme.accentColor(from: presentation.accentHex)
    }

    var body: some View {
        HStack(spacing: mode.spacing) {
            Button(intent: ReadingSessionTogglePauseIntent(bookID: context.attributes.bookID)) {
                controlLabel(
                    title: presentation.toggleTitle,
                    systemImage: presentation.toggleSystemImage
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .foregroundStyle(.black)
            .accessibilityLabel(presentation.toggleAccessibilityLabel)

            Button(intent: ReadingSessionStopIntent(bookID: context.attributes.bookID)) {
                controlLabel(title: "Stop", systemImage: "stop.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .accessibilityLabel(presentation.stopAccessibilityLabel)
        }
        .controlSize(mode.controlSize)
        .labelStyle(.titleAndIcon)
    }

    @ViewBuilder
    private func controlLabel(title: String, systemImage: String) -> some View {
        if mode.showsText {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        } else {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
        }
    }
}
