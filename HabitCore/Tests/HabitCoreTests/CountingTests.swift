import Foundation
import Testing
@testable import HabitCore

// The week of Mon 2026-10-19: Mon 19, Tue 20, Wed 21, Thu 22, Fri 23, Sat 24, Sun 25.

private func day(_ key: String) -> LocalDate { LocalDate(key)! }

private func at(_ key: String, _ hour: Int, _ minute: Int = 0) -> LocalMoment {
    LocalMoment(date: day(key), time: TimeOfDay(hour: hour, minute: minute))
}

/// A manual "went" on each day.
private func went(_ keys: String...) -> [ManualEntry] {
    keys.map { ManualEntry(day: day($0), mark: .went, recordedAt: Date(timeIntervalSince1970: 0)) }
}

/// A 45-minute Watch workout on `key`.
private func workout(_ key: String) -> WorkoutSample {
    WorkoutSample(id: UUID().uuidString, day: day(key), durationMinutes: 45)
}

private func trip(_ first: String, _ last: String) -> PlannedBreak {
    PlannedBreak(kind: .travel, firstDay: day(first), lastDay: day(last))
}

@Suite("Counting")
struct CountingTests {
    @Test func weekendsAreNotPlannedAndThursdayToMondayIsNormalRest() {
        let log = HabitLog(firstDay: day("2026-10-19"), manualEntries: went("2026-10-19", "2026-10-20", "2026-10-21", "2026-10-22"))
        let monday = at("2026-10-26", 7)
        #expect(log.state(of: day("2026-10-24"), at: monday) == .notPlanned)
        #expect(log.state(of: day("2026-10-25"), at: monday) == .notPlanned)
        #expect(log.state(of: day("2026-10-23"), at: monday) == .notPlanned)
        #expect(log.missedInARow(at: monday) == 0)
        #expect(log.standing(at: monday) == .onPlan)
        #expect(log.week(containing: day("2026-10-19"), at: monday).isHit)
    }

    @Test func aDayIsMissedOnlyAtRolloverAndALateWorkoutRepairsIt() {
        var log = HabitLog(firstDay: day("2026-10-19"), manualEntries: went("2026-10-19"))
        let tuesday = day("2026-10-20")
        #expect(log.state(of: tuesday, at: at("2026-10-20", 7)) == .planned)
        #expect(log.state(of: tuesday, at: at("2026-10-20", 23, 59)) == .planned)
        #expect(log.state(of: tuesday, at: at("2026-10-21", 3, 59)) == .planned)
        #expect(log.state(of: tuesday, at: at("2026-10-21", 4)) == .missed)

        log.workouts.append(workout("2026-10-20"))
        #expect(log.state(of: tuesday, at: at("2026-10-21", 9)) == .done)
        #expect(log.week(containing: tuesday, at: at("2026-10-21", 9)).misses == 0)
    }

    @Test func aPartialFirstWindowStartsAtZeroOfZero() {
        let log = HabitLog(firstDay: day("2026-10-21"))
        let now = at("2026-10-21", 7)
        #expect(log.state(of: day("2026-10-19"), at: now) == .notPlanned)
        #expect(log.state(of: day("2026-10-20"), at: now) == .notPlanned)
        #expect(log.state(of: day("2026-10-21"), at: now) == .planned)
        #expect(log.week(containing: day("2026-10-21"), at: now).slots == 2)
        #expect(log.lastFourWeeks(at: now) == Tally(count: 0, of: 0))
    }

    @Test func aLoweredTargetStopsPlanningOnceMet() {
        let log = HabitLog(
            firstDay: day("2026-10-19"),
            manualEntries: went("2026-10-19", "2026-10-20"),
            weekTargets: [day("2026-10-19"): 2]
        )
        let now = at("2026-10-20", 10)
        #expect(log.state(of: day("2026-10-21"), at: now) == .notPlanned)
        #expect(log.state(of: day("2026-10-22"), at: now) == .notPlanned)
        let week = log.week(containing: day("2026-10-19"), at: now)
        #expect(week.slots == 2)
        #expect(week.isHit)
    }

    @Test func overlappingBreaksMerge() {
        let log = HabitLog(firstDay: day("2026-10-19"), breaks: [trip("2026-10-20", "2026-10-21"), trip("2026-10-21", "2026-10-22")])
        let now = at("2026-10-19", 7)
        for key in ["2026-10-20", "2026-10-21", "2026-10-22"] {
            #expect(log.state(of: day(key), at: now) == .onBreak)
        }
        #expect(log.week(containing: day("2026-10-19"), at: now).slots == 1)
    }

    @Test func aBreakWithoutAVisitCreatesNoMissesAndResetsTheRun() {
        // Thu 15 and flex Fri 16 missed, the whole week of the 19th on break, Mon 26 missed.
        let log = HabitLog(
            firstDay: day("2026-10-12"),
            manualEntries: went("2026-10-12", "2026-10-13", "2026-10-14"),
            breaks: [trip("2026-10-19", "2026-10-23")]
        )
        let now = at("2026-10-27", 7)
        #expect(log.week(containing: day("2026-10-12"), at: now).misses == 2)
        let away = log.week(containing: day("2026-10-19"), at: now)
        #expect(away.misses == 0)
        #expect(away.slots == 0)
        #expect(!away.isHit)
        #expect(log.missedInARow(at: now) == 1)
        #expect(log.standing(at: now) == .missed(inARow: 1))
    }

    @Test func aSaturdayVisitCountsAndAFifthIsCapped() {
        let log = HabitLog(
            firstDay: day("2026-10-19"),
            manualEntries: went("2026-10-19", "2026-10-20", "2026-10-21", "2026-10-24")
        )
        let saturday = at("2026-10-24", 12)
        let four = log.week(containing: day("2026-10-19"), at: saturday)
        #expect(four.visits == 4)
        #expect(four.counted == 4)
        #expect(four.isHit)

        var five = log
        five.manualEntries += went("2026-10-22")
        let sunday = at("2026-10-25", 12)
        let week = five.week(containing: day("2026-10-19"), at: sunday)
        #expect(week.visits == 5)
        #expect(week.counted == 4)
        let tally = five.lastFourWeeks(at: sunday)
        #expect(tally == Tally(count: 4, of: 4))
        #expect(tally.count <= tally.of)
    }

    @Test func twoWorkoutsOnOneDayAreOneVisit() {
        let log = HabitLog(firstDay: day("2026-10-19"), workouts: [workout("2026-10-19"), workout("2026-10-19")])
        #expect(log.week(containing: day("2026-10-19"), at: at("2026-10-19", 12)).visits == 1)
    }

    @Test func lastFourWeeksAcrossFullWeeks() {
        // Weeks of Sep 28, Oct 5, Oct 12 fully attended; Tue Oct 20 missed this week.
        let weekdays = ["2026-09-28", "2026-09-29", "2026-09-30", "2026-10-01",
                        "2026-10-05", "2026-10-06", "2026-10-07", "2026-10-08",
                        "2026-10-12", "2026-10-13", "2026-10-14", "2026-10-15"]
        var log = HabitLog(firstDay: day("2026-09-28"))
        log.manualEntries = weekdays.flatMap { went($0) } + went("2026-10-19", "2026-10-21", "2026-10-22")
        let thursday = at("2026-10-22", 12)
        #expect(log.lastFourWeeks(at: thursday) == Tally(count: 15, of: 16))

        // A full week on break leaves the denominator instead of showing misses.
        var withBreak = log
        withBreak.manualEntries.removeAll { (day("2026-10-05")...day("2026-10-11")).contains($0.day) }
        withBreak.breaks = [trip("2026-10-05", "2026-10-11")]
        #expect(withBreak.lastFourWeeks(at: thursday) == Tally(count: 11, of: 12))
        #expect(!withBreak.week(containing: day("2026-10-05"), at: thursday).isHit)
    }

    @Test func missesInARowThenAComeback() {
        var log = HabitLog(firstDay: day("2026-10-19"), manualEntries: went("2026-10-19"))
        let thursday = at("2026-10-22", 7)
        #expect(log.missedInARow(at: thursday) == 2)
        #expect(log.standing(at: thursday) == .missed(inARow: 2))

        log.manualEntries += went("2026-10-22")
        #expect(log.standing(at: at("2026-10-22", 9)) == .comeback)
        #expect(log.standing(at: at("2026-10-23", 9)) == .onPlan)
    }

    @Test func nextSession() {
        let log = HabitLog(firstDay: day("2026-10-19"), manualEntries: went("2026-10-19"))
        #expect(log.nextSession(at: at("2026-10-20", 8)) == day("2026-10-20"))
        #expect(log.nextSession(at: at("2026-10-20", 9, 45)) == day("2026-10-21"))

        var full = log
        full.manualEntries += went("2026-10-20", "2026-10-21", "2026-10-22")
        #expect(full.nextSession(at: at("2026-10-22", 9)) == day("2026-10-26"))

        var away = log
        away.breaks = [trip("2026-10-20", "2026-10-21")]
        #expect(away.nextSession(at: at("2026-10-20", 8)) == day("2026-10-22"))
    }

    @Test func returnDayAfterATravelBreak() {
        let log = HabitLog(firstDay: day("2026-10-19"), manualEntries: went("2026-10-19"))
        let now = at("2026-10-19", 12)
        #expect(log.returnDay(after: trip("2026-10-20", "2026-10-21"), at: now) == day("2026-10-22"))
        #expect(log.returnDay(after: trip("2026-10-20", "2026-10-22"), at: now) == day("2026-10-26"))

        var merged = log
        merged.breaks = [trip("2026-10-20", "2026-10-21"), trip("2026-10-21", "2026-10-27")]
        #expect(merged.returnDay(after: merged.breaks[0], at: now) == day("2026-10-28"))
    }

    @Test func aTimezoneChangeDoesNotMoveAnOldVisit() {
        // 23:30 Tuesday in New York is already Wednesday in Tokyo.
        let instant = ISO8601DateFormatter().date(from: "2026-10-21T03:30:00Z")!
        let recorded = LocalDate(instant, in: TimeZone(identifier: "America/New_York")!)
        let log = HabitLog(
            firstDay: day("2026-10-19"),
            manualEntries: [ManualEntry(day: recorded, mark: .went, recordedAt: instant)]
        )
        let later = LocalMoment(instant.addingTimeInterval(3600), in: TimeZone(identifier: "Asia/Tokyo")!)
        #expect(log.state(of: day("2026-10-20"), at: later) == .done)
        #expect(log.state(of: day("2026-10-21"), at: later) == .planned)
    }
}
