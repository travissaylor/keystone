import Foundation
import Testing
@testable import HabitCore

// The week of Mon 2026-10-19: Mon 19, Tue 20, Wed 21, Thu 22, Fri 23, Sat 24, Sun 25.

private let monday = LocalDate("2026-10-19")!
private let friday = LocalDate("2026-10-23")!

private func day(_ key: String) -> LocalDate { LocalDate(key)! }

private func at(_ key: String, _ hour: Int, _ minute: Int = 0) -> LocalMoment {
    LocalMoment(date: day(key), time: TimeOfDay(hour: hour, minute: minute))
}

/// A manual "went" on each day.
private func went(_ keys: String...) -> [ManualEntry] {
    keys.map { ManualEntry(day: day($0), mark: .went, recordedAt: Date(timeIntervalSince1970: 0)) }
}

@Suite("Flex day")
struct FlexDayTests {
    @Test func aMissOnTuesdayActivatesFriday() {
        let log = HabitLog(firstDay: monday, manualEntries: went("2026-10-19"))
        let beforeRollover = at("2026-10-21", 3)
        #expect(!log.isFlexActive(inWeekOf: monday, at: beforeRollover))
        #expect(log.state(of: friday, at: beforeRollover) == .notPlanned)

        let wednesday = at("2026-10-21", 7)
        #expect(log.isFlexActive(inWeekOf: monday, at: wednesday))
        #expect(log.state(of: friday, at: wednesday) == .planned)
        #expect(log.flexDay(inWeekOf: monday, at: wednesday) == friday)
    }

    @Test func aRestOnTuesdayActivatesFriday() {
        let log = HabitLog(firstDay: monday, rests: [day("2026-10-20")])
        let now = at("2026-10-19", 7)
        #expect(log.state(of: day("2026-10-20"), at: now) == .rest)
        #expect(log.state(of: friday, at: now) == .planned)
        let week = log.week(containing: monday, at: now)
        #expect(week.isFlexActive)
        #expect(week.slots == 4)
    }

    @Test func fourVisitsByThursdayLeaveFridayUnplanned() {
        let log = HabitLog(firstDay: monday, manualEntries: went("2026-10-19", "2026-10-20", "2026-10-21", "2026-10-22"))
        let saturday = at("2026-10-24", 12)
        #expect(!log.isFlexActive(inWeekOf: monday, at: saturday))
        #expect(log.state(of: friday, at: saturday) == .notPlanned)
        #expect(log.flexDay(inWeekOf: monday, at: saturday) == nil)
    }

    @Test func aFridayVisitMakesTheWeekHit() {
        let log = HabitLog(firstDay: monday, manualEntries: went("2026-10-19", "2026-10-21", "2026-10-22", "2026-10-23"))
        let saturday = at("2026-10-24", 12)
        #expect(log.state(of: day("2026-10-20"), at: saturday) == .missed)
        #expect(log.state(of: friday, at: saturday) == .done)
        let week = log.week(containing: monday, at: saturday)
        #expect(week.counted == 4)
        #expect(week.slots == 4)
        #expect(week.isHit)
    }

    @Test func twoMissesWithFridayUsedLandAtThree() {
        let log = HabitLog(firstDay: monday, manualEntries: went("2026-10-19", "2026-10-22", "2026-10-23"))
        let sunday = at("2026-10-25", 12)
        let week = log.week(containing: monday, at: sunday)
        #expect(week.misses == 2)
        #expect(week.counted == 3)
        #expect(week.slots == 4)
        #expect(!week.isHit)
        #expect(log.state(of: day("2026-10-24"), at: sunday) == .notPlanned)
    }

    @Test func aBreakDayOnTuesdayDoesNotActivateFriday() {
        let log = HabitLog(
            firstDay: monday,
            manualEntries: went("2026-10-19", "2026-10-21", "2026-10-22"),
            breaks: [PlannedBreak(kind: .recovery, firstDay: day("2026-10-20"), lastDay: day("2026-10-20"))]
        )
        let saturday = at("2026-10-24", 12)
        #expect(!log.isFlexActive(inWeekOf: monday, at: saturday))
        #expect(log.state(of: friday, at: saturday) == .notPlanned)
        let week = log.week(containing: monday, at: saturday)
        #expect(week.slots == 3)
        #expect(week.isHit)
    }

    @Test func fridayInsideABreakIsNeverPlanned() {
        let log = HabitLog(
            firstDay: monday,
            manualEntries: went("2026-10-19"),
            breaks: [PlannedBreak(kind: .travel, firstDay: friday, lastDay: day("2026-10-25"))]
        )
        let thursday = at("2026-10-22", 12)
        #expect(!log.isPlannedSession(friday, at: thursday))
        #expect(log.state(of: friday, at: thursday) == .onBreak)
        #expect(log.flexDay(inWeekOf: monday, at: thursday) == nil)
        #expect(log.week(containing: monday, at: thursday).slots == 4)
    }

    @Test func aLoweredTargetMetByWednesdayLeavesThursdayAndFridayUnplanned() {
        let log = HabitLog(
            firstDay: monday,
            manualEntries: went("2026-10-19", "2026-10-20", "2026-10-21"),
            weekTargets: [monday: 3]
        )
        let now = at("2026-10-21", 12)
        #expect(log.state(of: day("2026-10-22"), at: now) == .notPlanned)
        #expect(log.state(of: friday, at: now) == .notPlanned)
        #expect(log.week(containing: monday, at: now).isHit)
    }
}
