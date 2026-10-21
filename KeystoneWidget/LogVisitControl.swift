import AppIntents
import SwiftUI
import WidgetKit

/// A Control Center control (also usable on the Action button and lock screen)
/// that logs today's gym visit in one tap.
struct LogVisitControl: ControlWidget {
    static let kind = "com.travissaylor.keystone.LogVisit"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: LogGymVisitIntent()) {
                Label("Log gym visit", systemImage: "figure.strengthtraining.traditional")
            }
        }
        .displayName("Log gym visit")
        .description("One tap to log today's gym visit.")
    }
}
