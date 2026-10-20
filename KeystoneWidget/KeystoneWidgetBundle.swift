import SwiftUI
import WidgetKit

/// The widget bundle entry point. A later unit fills in the status widget.
@main
struct KeystoneWidgetBundle: WidgetBundle {
    var body: some Widget {
        KeystoneStatusWidget()
    }
}

/// Placeholder status widget.
struct KeystoneStatusWidget: Widget {
    let kind = "KeystoneStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlaceholderProvider()) { _ in
            Text("Keystone")
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Keystone")
        .description("This week's gym visits.")
        .supportedFamilies([.systemSmall])
    }
}

nonisolated struct PlaceholderEntry: TimelineEntry {
    let date: Date
}

nonisolated struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry {
        PlaceholderEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) {
        completion(PlaceholderEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [PlaceholderEntry(date: .now)], policy: .never))
    }
}
