import Foundation

/// An ended Watch workout, as HealthKit delivered it.
public struct WorkoutSample: Hashable, Codable, Sendable, Identifiable {
    /// The HKWorkout UUID string. Stable across re-delivery, so duplicates collapse.
    public var id: String
    /// The local day of the workout's start, captured when it was imported.
    public var day: LocalDate
    public var durationMinutes: Int

    public init(id: String, day: LocalDate, durationMinutes: Int) {
        self.id = id
        self.day = day
        self.durationMinutes = durationMinutes
    }
}

public enum ManualMark: String, Codable, Sendable {
    case went
    case didntGo
}

/// A one-tap "went" or a confirmed "didn't go". Manual beats sensor.
public struct ManualEntry: Hashable, Codable, Sendable, Identifiable {
    public var id: UUID
    public var day: LocalDate
    public var mark: ManualMark
    public var recordedAt: Date

    public init(id: UUID = UUID(), day: LocalDate, mark: ManualMark, recordedAt: Date) {
        self.id = id
        self.day = day
        self.mark = mark
        self.recordedAt = recordedAt
    }
}

/// A declared stretch of days off. Its days leave every denominator.
public struct PlannedBreak: Hashable, Codable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        /// Travel or life. Ends on a chosen last day; the return is the next planned session.
        case travel
        /// Injury or illness. `lastDay` is the review date.
        case recovery
    }

    public var id: UUID
    public var kind: Kind
    public var firstDay: LocalDate
    /// Inclusive. For a recovery break this is the review date.
    public var lastDay: LocalDate
    /// Written when the break starts and quoted on the return morning.
    public var reentryPlan: String?

    public init(id: UUID = UUID(), kind: Kind, firstDay: LocalDate, lastDay: LocalDate, reentryPlan: String? = nil) {
        self.id = id
        self.kind = kind
        self.firstDay = firstDay
        self.lastDay = lastDay
        self.reentryPlan = reentryPlan
    }

    public func contains(_ day: LocalDate) -> Bool {
        firstDay <= day && day <= lastDay
    }
}

/// The optional one-tap reason on the morning after a miss.
public enum MissReason: String, Codable, Sendable, CaseIterable {
    case travel
    case body
    case sick
    case work
    case justDidnt

    public var label: String {
        switch self {
        case .travel: "Travel"
        case .body: "Body"
        case .sick: "Sick"
        case .work: "Work"
        case .justDidnt: "Just didn't"
        }
    }
}

/// Everything the user and the sensors have recorded. HabitCore derives every
/// number from this; nothing derived is stored.
public struct HabitLog: Hashable, Codable, Sendable {
    /// The first day of the first window. Nothing before it is planned.
    public var firstDay: LocalDate
    public var workouts: [WorkoutSample]
    public var manualEntries: [ManualEntry]
    /// Days declared "rest". A rest is not a miss.
    public var rests: Set<LocalDate>
    /// Days marked "later today": still open, no 10:00 nudge.
    public var laterToday: Set<LocalDate>
    public var breaks: [PlannedBreak]
    /// Lowered weekly targets, keyed by the week's Monday.
    public var weekTargets: [LocalDate: Int]
    public var missReasons: [LocalDate: MissReason]

    public init(
        firstDay: LocalDate,
        workouts: [WorkoutSample] = [],
        manualEntries: [ManualEntry] = [],
        rests: Set<LocalDate> = [],
        laterToday: Set<LocalDate> = [],
        breaks: [PlannedBreak] = [],
        weekTargets: [LocalDate: Int] = [:],
        missReasons: [LocalDate: MissReason] = [:]
    ) {
        self.firstDay = firstDay
        self.workouts = workouts
        self.manualEntries = manualEntries
        self.rests = rests
        self.laterToday = laterToday
        self.breaks = breaks
        self.weekTargets = weekTargets
        self.missReasons = missReasons
    }

    /// The target for the week containing `day`.
    public func weekTarget(for day: LocalDate) -> Int {
        weekTargets[day.weekStart] ?? Schedule.defaultWeekTarget
    }

    /// True when any declared break covers `day`. Overlapping breaks behave as their union.
    public func isOnBreak(_ day: LocalDate) -> Bool {
        breaks.contains { $0.contains(day) }
    }

    /// The breaks covering `day`, latest-ending first.
    public func breaks(containing day: LocalDate) -> [PlannedBreak] {
        breaks.filter { $0.contains(day) }.sorted { $0.lastDay > $1.lastDay }
    }
}
