import AppIntents
import Foundation
import HabitCore
import SwiftData
import UserNotifications
import WidgetKit

/// The one-tap log behind the Control Center control, Action button,
/// lock-screen slots and the Home Screen widget.
///
/// It runs in the widget extension process, so it opens the store local-only;
/// only the main app syncs with CloudKit and picks the write up on its next
/// foreground reload.
struct LogGymVisitIntent: AppIntent {
    static let title: LocalizedStringResource = "Log gym visit"
    static let openAppWhenRun = false
    static let isDiscoverable = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let container = try KeystoneStore.makeContainer(syncWithCloudKit: false)
        let store = HabitStore(context: ModelContext(container))
        let today = store.today()
        if !store.log.isVisit(today) {
            store.logVisit(on: today)
        }
        // Best effort: today's nudge no longer applies.
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["nudge-\(today.key)"])
        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadAllControls()
        return .result()
    }
}
