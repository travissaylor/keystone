import Foundation
import HabitCore
import OSLog
import UserNotifications

/// Keeps the pending queue equal to `NotificationPlanner.plan`: a date-keyed
/// set of single-shot requests, never a repeating trigger. Rebuilt from the
/// log on every foreground, declaration and workout import. Failures are
/// logged and the next rebuild retries.
@MainActor
final class NotificationService {
    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "com.travissaylor.keystone", category: "Notifications")

    /// True while a rebuild is running; `pending` holds the latest request made meanwhile.
    private var isRebuilding = false
    private var pending: (log: HabitLog, now: LocalMoment)?

    // MARK: Start

    /// Registers the action categories and asks for permission. The system
    /// prompt appears once; there is no onboarding.
    func start() {
        let categories = NotificationCategory.allCases.map { category in
            UNNotificationCategory(
                identifier: category.rawValue,
                actions: category.actions.map { action in
                    UNNotificationAction(
                        identifier: action.rawValue,
                        title: action.title,
                        options: action.opensApp ? [.foreground] : []
                    )
                },
                intentIdentifiers: [],
                options: []
            )
        }
        center.setNotificationCategories(Set(categories))
        Task { [center, logger] in
            do {
                _ = try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                logger.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: Rebuild

    /// Replaces the owned pending requests with the plan for `log`. Coalesces:
    /// at most one rebuild runs, and a request made meanwhile runs once more
    /// afterwards with the latest log.
    func rebuild(with log: HabitLog, now: LocalMoment) {
        pending = (log, now)
        guard !isRebuilding else { return }
        isRebuilding = true
        Task {
            while let next = pending {
                pending = nil
                await apply(NotificationPlanner.plan(log: next.log, now: next.now))
            }
            isRebuilding = false
        }
    }

    private func apply(_ plan: [PlannedNotification]) async {
        let plannedIDs = Set(plan.map(\.id))
        let stale = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { NotificationPlanner.isOwned(identifier: $0) && !plannedIDs.contains($0) }
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }
        // Re-adding an identifier atomically replaces the pending request.
        for planned in plan {
            do {
                try await center.add(Self.request(for: planned))
            } catch {
                logger.error("Scheduling \(planned.id, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private static func request(for planned: PlannedNotification) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = planned.title
        content.body = planned.body
        content.categoryIdentifier = planned.category.rawValue
        content.sound = .default
        content.interruptionLevel = planned.isTimeSensitive ? .timeSensitive : .active
        var userInfo: [String: String] = [NotificationPlanner.userInfoDayKey: planned.subjectDay.key]
        if let breakID = planned.breakID {
            userInfo[NotificationPlanner.userInfoBreakKey] = breakID.uuidString
        }
        content.userInfo = userInfo
        let trigger = UNCalendarNotificationTrigger(dateMatching: planned.fireAt.dateComponents, repeats: false)
        return UNNotificationRequest(identifier: planned.id, content: content, trigger: trigger)
    }
}
