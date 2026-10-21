import Foundation
import HabitCore
import UserNotifications

/// Handles notification actions. Set as the center's delegate in the app's
/// `init()`, so it is live even when an action cold-launches the app in the
/// background. Store mutations fire `onLogChanged`, which rebuilds the queue.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let store: HabitStore

    init(store: HabitStore) {
        self.store = store
    }

    /// Show pushes even while the app is in the foreground.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    /// Maps the tapped action to its effect. The default tap only opens the app.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        guard let action = NotificationAction(rawValue: response.actionIdentifier),
              let dayKey = info[NotificationPlanner.userInfoDayKey] as? String,
              let day = LocalDate(dayKey) else { return }
        let breakID = (info[NotificationPlanner.userInfoBreakKey] as? String).flatMap { UUID(uuidString: $0) }
        guard let effect = NotificationPlanner.effect(of: action, subjectDay: day, breakID: breakID) else { return }
        await apply(effect)
    }

    // MARK: Effects

    @MainActor
    private func apply(_ effect: NotificationEffect) {
        switch effect {
        case .logVisit(let day):
            store.logVisit(on: day)
        case .markDidntGo(let day):
            store.markDidntGo(on: day)
        case .declareRest(let day):
            store.declareRest(on: day)
        case .laterToday(let day):
            store.markLaterToday(on: day)
        case .openHardDay(let day, let blocker):
            AppRouter.shared.hardDay = HardDayRequest(day: day, blocker: blocker)
        case .endRecoveryBreak:
            // The break already ends on its review date; nothing to change.
            break
        case .extendRecoveryBreak(let id):
            guard var recovery = store.log.breaks.first(where: { $0.id == id }) else { return }
            recovery.lastDay = recovery.lastDay.adding(days: Schedule.recoveryReviewExtensionDays)
            store.updateBreak(recovery)
        }
    }
}
