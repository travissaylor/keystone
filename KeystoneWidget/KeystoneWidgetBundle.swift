import SwiftUI
import WidgetKit

/// The widget bundle entry point.
@main
struct KeystoneWidgetBundle: WidgetBundle {
    var body: some Widget {
        KeystoneStatusWidget()
        LogVisitControl()
    }
}
