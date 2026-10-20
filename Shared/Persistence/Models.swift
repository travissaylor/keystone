import Foundation
import SwiftData

// SwiftData records behind `HabitLog`. They are CloudKit-compatible: every
// property has a default, nothing is `@Attribute(.unique)`, and there are no
// relationships. Identity lives in stable string or UUID fields instead, so
// duplicates that a CloudKit merge produces collapse on read (see
// `HabitStore.reload()`).
//
// Day keys are `LocalDate.key` ("yyyy-MM-dd"), captured in local time when the
// thing happened, so a later timezone change never moves an old record.

/// An imported Watch workout. `workoutID` is the HKWorkout UUID string.
@Model
final class WorkoutRecord {
    var workoutID: String = ""
    var dayKey: String = ""
    var durationMinutes: Int = 0
    var importedAt: Date = Date.distantPast

    init(workoutID: String, dayKey: String, durationMinutes: Int, importedAt: Date) {
        self.workoutID = workoutID
        self.dayKey = dayKey
        self.durationMinutes = durationMinutes
        self.importedAt = importedAt
    }
}

/// A manual "went" or "didn't go". `mark` is a `ManualMark` raw value.
@Model
final class ManualEntryRecord {
    var entryID: UUID = UUID()
    var dayKey: String = ""
    var mark: String = ""
    var recordedAt: Date = Date.distantPast

    init(entryID: UUID, dayKey: String, mark: String, recordedAt: Date) {
        self.entryID = entryID
        self.dayKey = dayKey
        self.mark = mark
        self.recordedAt = recordedAt
    }
}

/// Per-day declarations: rest, later today, and the optional miss reason
/// (a `MissReason` raw value).
@Model
final class DayRecord {
    var dayKey: String = ""
    var isRest: Bool = false
    var isLaterToday: Bool = false
    var missReason: String?
    var updatedAt: Date = Date.distantPast

    init(dayKey: String, isRest: Bool = false, isLaterToday: Bool = false, missReason: String? = nil, updatedAt: Date) {
        self.dayKey = dayKey
        self.isRest = isRest
        self.isLaterToday = isLaterToday
        self.missReason = missReason
        self.updatedAt = updatedAt
    }
}

/// A declared break. `kind` is a `PlannedBreak.Kind` raw value; both day keys
/// are inclusive.
@Model
final class BreakRecord {
    var breakID: UUID = UUID()
    var kind: String = ""
    var firstDayKey: String = ""
    var lastDayKey: String = ""
    var reentryPlan: String?

    init(breakID: UUID, kind: String, firstDayKey: String, lastDayKey: String, reentryPlan: String?) {
        self.breakID = breakID
        self.kind = kind
        self.firstDayKey = firstDayKey
        self.lastDayKey = lastDayKey
        self.reentryPlan = reentryPlan
    }
}

/// A lowered target for one week, keyed by the week's Monday.
@Model
final class WeekTargetRecord {
    var weekStartKey: String = ""
    var target: Int = 0

    init(weekStartKey: String, target: Int) {
        self.weekStartKey = weekStartKey
        self.target = target
    }
}

/// The first day of the first window, set to today on first launch.
@Model
final class MetaRecord {
    var firstDayKey: String = ""

    init(firstDayKey: String) {
        self.firstDayKey = firstDayKey
    }
}
