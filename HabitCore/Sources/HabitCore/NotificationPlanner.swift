import Foundation

/// The four pushes the app ever sends.
public enum NotificationKind: String, Codable, Sendable {
    /// Night before a planned session.
    case prep
    /// The morning go alert, five minutes before the door.
    case go
    /// "Did you go?" at 10:00 when no evidence has arrived.
    case nudge
    /// A recovery break's review question, on the review date.
    case review
}

/// The buttons on a notification. Raw values are the action identifiers.
public enum NotificationAction: String, CaseIterable, Sendable {
    /// On prep.
    case restTomorrow = "REST_TOMORROW"
    /// On go: opens the app on the hard-day offer with the body card.
    case bodyOff = "BODY_OFF"
    /// On go: opens the app on the hard-day offer.
    case notToday = "NOT_TODAY"
    /// On nudge.
    case went = "WENT", laterToday = "LATER_TODAY", didntGo = "DIDNT_GO"
    /// On review.
    case back = "BACK", oneMoreWeek = "ONE_MORE_WEEK"

    public var title: String {
        switch self {
        case .restTomorrow: "Rest tomorrow"
        case .bodyOff: "Body feels off"
        case .notToday: "Not today"
        case .went: "Went"
        case .laterToday: "Later today"
        case .didntGo: "No"
        case .back: "Back"
        case .oneMoreWeek: "One more week"
        }
    }

    /// True when the action brings the app to the foreground. The rest are handled in the background.
    public var opensApp: Bool {
        switch self {
        case .bodyOff, .notToday: true
        default: false
        }
    }
}

/// One category per kind. Raw values are the category identifiers.
public enum NotificationCategory: String, CaseIterable, Sendable {
    case prep = "KEYSTONE_PREP"
    case go = "KEYSTONE_GO"
    case nudge = "KEYSTONE_NUDGE"
    case review = "KEYSTONE_REVIEW"

    /// The buttons, in display order.
    public var actions: [NotificationAction] {
        switch self {
        case .prep: [.restTomorrow]
        case .go: [.bodyOff, .notToday]
        case .nudge: [.went, .laterToday, .didntGo]
        case .review: [.back, .oneMoreWeek]
        }
    }
}

/// One single-shot, date-keyed request. Never a repeating trigger.
public struct PlannedNotification: Hashable, Sendable, Identifiable {
    /// "<kind>-<yyyy-MM-dd of fireAt.date>", such as "prep-2026-10-20".
    /// Re-adding the same id replaces the request.
    public let id: String
    public let kind: NotificationKind
    /// Floating local time. The app converts it with `fireAt.dateComponents`.
    public let fireAt: LocalMoment
    /// The session day it is about. Prep fires the evening before its subject day.
    public let subjectDay: LocalDate
    /// Set on review only.
    public let breakID: UUID?
    public let title: String
    public let body: String
    public let category: NotificationCategory
    /// Go only.
    public let isTimeSensitive: Bool

    public init(
        kind: NotificationKind,
        fireAt: LocalMoment,
        subjectDay: LocalDate,
        breakID: UUID? = nil,
        title: String,
        body: String,
        category: NotificationCategory,
        isTimeSensitive: Bool = false
    ) {
        self.id = NotificationPlanner.identifier(kind, fireAt.date)
        self.kind = kind
        self.fireAt = fireAt
        self.subjectDay = subjectDay
        self.breakID = breakID
        self.title = title
        self.body = body
        self.category = category
        self.isTimeSensitive = isTimeSensitive
    }
}

/// What to change in the pending queue to turn `current` into `next`.
public struct QueueDiff: Equatable, Sendable {
    /// Ids to remove, sorted.
    public let removeIDs: [String]
    /// Requests to add or replace, sorted by fireAt then id.
    public let upserts: [PlannedNotification]

    public var isEmpty: Bool { removeIDs.isEmpty && upserts.isEmpty }
}

/// What tapping an action should do. The app applies it to its store.
public enum NotificationEffect: Equatable, Sendable {
    case logVisit(LocalDate)
    case markDidntGo(LocalDate)
    case declareRest(LocalDate)
    case laterToday(LocalDate)
    /// Open the app on the hard-day offer, with this blocker's card when set.
    case openHardDay(LocalDate, Blocker?)
    case endRecoveryBreak(UUID)
    case extendRecoveryBreak(UUID)
}

/// The rolling queue: a pure plan from the log, and the diff against what is pending.
///
/// The app rebuilds the plan on every foreground, declaration and workout
/// import, removes ids that left the plan, and re-adds the rest.
public enum NotificationPlanner {
    /// Every id this planner makes starts with one of these.
    public static let identifierPrefixes: [String] = ["prep-", "go-", "nudge-", "review-"]

    /// True for ids this planner owns, so the app never removes anyone else's requests.
    public static func isOwned(identifier: String) -> Bool {
        identifierPrefixes.contains { identifier.hasPrefix($0) }
    }

    /// userInfo keys: the subject day's "yyyy-MM-dd" and the review's break UUID string.
    public static let userInfoDayKey = "day", userInfoBreakKey = "breakID"

    /// The full queue for the next `Schedule.queueHorizonDays` days, sorted by
    /// fireAt then id. Never two requests with one id. Requests at or before
    /// `now` are dropped.
    public static func plan(
        log: HabitLog,
        now: LocalMoment,
        inboundDriveMinutes: Int = Schedule.defaultInboundDriveMinutes,
        inboundOverrides: [LocalDate: Int] = [:]
    ) -> [PlannedNotification] {
        let horizon = (0..<Schedule.queueHorizonDays).map { now.date.adding(days: $0) }
        var requests: [PlannedNotification] = []

        for day in horizon where log.state(of: day, at: now) == .planned {
            let trip = Budget.plan(inboundDriveMinutes: inboundOverrides[day] ?? inboundDriveMinutes)
            let eve = day.adding(days: -1)

            if !log.isOnBreak(eve) {
                requests.append(PlannedNotification(
                    kind: .prep,
                    fireAt: LocalMoment(date: eve, time: Schedule.prepReminderTime),
                    subjectDay: day,
                    title: "Tomorrow \(Schedule.doorTime.display)",
                    body: "Bag packed, clothes out. \(Budget.exitLine(for: trip)).",
                    category: .prep
                ))
            }

            if let goTime = trip.goAlertTime {
                var body = Budget.goAlertBody(for: trip)
                if let reentry = reentryPlan(returningOn: day, log: log, now: now) {
                    body += " \u{201C}\(reentry)\u{201D}"
                }
                requests.append(PlannedNotification(
                    kind: .go,
                    fireAt: LocalMoment(date: day, time: goTime),
                    subjectDay: day,
                    title: "Out the door \(trip.doorTime.display)",
                    body: body,
                    category: .go,
                    isTimeSensitive: true
                ))
            }

            if !log.laterToday.contains(day) {
                requests.append(PlannedNotification(
                    kind: .nudge,
                    fireAt: LocalMoment(date: day, time: Schedule.nudgeTime),
                    subjectDay: day,
                    title: "Did you go?",
                    body: "Any visit counts in full.",
                    category: .nudge
                ))
            }
        }

        // One review per date: the first recovery break by id string.
        let window = Set(horizon)
        var reviewed: Set<LocalDate> = []
        let recoveries = log.breaks
            .filter { $0.kind == .recovery && window.contains($0.lastDay) }
            .sorted { $0.id.uuidString < $1.id.uuidString }
        for recovery in recoveries where reviewed.insert(recovery.lastDay).inserted {
            requests.append(PlannedNotification(
                kind: .review,
                fireAt: LocalMoment(date: recovery.lastDay, time: Schedule.reviewQuestionTime),
                subjectDay: recovery.lastDay,
                breakID: recovery.id,
                title: "Back tomorrow?",
                body: "Review date for your recovery break. Back tomorrow, or one more week?",
                category: .review
            ))
        }

        return sorted(requests.filter { $0.fireAt > now })
    }

    /// Remove what left the plan; add or replace what is new or changed.
    public static func diff(current: [PlannedNotification], next: [PlannedNotification]) -> QueueDiff {
        let currentByID = Dictionary(current.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let nextIDs = Set(next.map(\.id))
        let removals = currentByID.keys.filter { !nextIDs.contains($0) }.sorted()
        let upserts = next.filter { currentByID[$0.id] != $0 }
        return QueueDiff(removeIDs: removals, upserts: sorted(upserts))
    }

    /// The store change for a tapped action. Nil for a review action without a break id.
    public static func effect(of action: NotificationAction, subjectDay: LocalDate, breakID: UUID?) -> NotificationEffect? {
        switch action {
        case .restTomorrow: return .declareRest(subjectDay)
        case .bodyOff: return .openHardDay(subjectDay, .bodyOff)
        case .notToday: return .openHardDay(subjectDay, nil)
        case .went: return .logVisit(subjectDay)
        case .laterToday: return .laterToday(subjectDay)
        case .didntGo: return .markDidntGo(subjectDay)
        case .back: return breakID.map { .endRecoveryBreak($0) }
        case .oneMoreWeek: return breakID.map { .extendRecoveryBreak($0) }
        }
    }

    // MARK: Helpers

    static func identifier(_ kind: NotificationKind, _ day: LocalDate) -> String {
        "\(kind.rawValue)-\(day.key)"
    }

    /// The re-entry plan to quote when `day` is a break's return day. When
    /// several breaks return on it, the latest-ending one wins.
    private static func reentryPlan(returningOn day: LocalDate, log: HabitLog, now: LocalMoment) -> String? {
        log.breaks
            .filter { !($0.reentryPlan ?? "").isEmpty && $0.lastDay < day }
            .sorted { ($0.lastDay, $0.id.uuidString) > ($1.lastDay, $1.id.uuidString) }
            .first { log.returnDay(after: $0, at: now) == day }?
            .reentryPlan
    }

    private static func sorted(_ requests: [PlannedNotification]) -> [PlannedNotification] {
        requests.sorted { ($0.fireAt, $0.id) < ($1.fireAt, $1.id) }
    }
}
