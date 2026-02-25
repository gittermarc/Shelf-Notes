//
//  ShelfNotesLiveActivityLiveActivity.swift
//  ShelfNotesLiveActivity
//
//  Created by Marc Fechner on 25.02.26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct ShelfNotesLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct ShelfNotesLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShelfNotesLiveActivityAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension ShelfNotesLiveActivityAttributes {
    fileprivate static var preview: ShelfNotesLiveActivityAttributes {
        ShelfNotesLiveActivityAttributes(name: "World")
    }
}

extension ShelfNotesLiveActivityAttributes.ContentState {
    fileprivate static var smiley: ShelfNotesLiveActivityAttributes.ContentState {
        ShelfNotesLiveActivityAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: ShelfNotesLiveActivityAttributes.ContentState {
         ShelfNotesLiveActivityAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: ShelfNotesLiveActivityAttributes.preview) {
   ShelfNotesLiveActivityLiveActivity()
} contentStates: {
    ShelfNotesLiveActivityAttributes.ContentState.smiley
    ShelfNotesLiveActivityAttributes.ContentState.starEyes
}
