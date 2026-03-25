//
//  EverbloomWidgetLiveActivity.swift
//  EverbloomWidget
//
//  Created by Burak Cakmakoglu  on 2026-03-19.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct EverbloomWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct EverbloomWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EverbloomWidgetAttributes.self) { context in
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

extension EverbloomWidgetAttributes {
    fileprivate static var preview: EverbloomWidgetAttributes {
        EverbloomWidgetAttributes(name: "World")
    }
}

extension EverbloomWidgetAttributes.ContentState {
    fileprivate static var smiley: EverbloomWidgetAttributes.ContentState {
        EverbloomWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: EverbloomWidgetAttributes.ContentState {
         EverbloomWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: EverbloomWidgetAttributes.preview) {
   EverbloomWidgetLiveActivity()
} contentStates: {
    EverbloomWidgetAttributes.ContentState.smiley
    EverbloomWidgetAttributes.ContentState.starEyes
}
