import Foundation
import Testing
@testable import HabitCore

// The week of Mon 2026-10-19: Sun 18, Mon 19, Tue 20, Wed 21, Thu 22, Fri 23, Sat 24, Sun 25.

private let sunday = LocalDate("2026-10-18")!

private func day(_ key: String) -> LocalDate { LocalDate(key)! }

private func at(_ key: String, _ hour: Int, _ minute: Int = 0) -> LocalMoment {
    LocalMoment(date: day(key), time: TimeOfDay(hour: hour, minute: minute))
}

/// A manual "went" on each day.
private func went(_ keys: String...) -> [ManualEntry] {
    keys.map { ManualEntry(day: day($0), mark: .went, recordedAt: Date(timeIntervalSince1970: 0)) }
}

private func plan(_ log: HabitLog, _ now: LocalMoment, overrides: [LocalDate: Int] = [:]) -> [PlannedNotification] {
    NotificationPlanner.plan(log: log, now: now, inboundOverrides: overrides)
}

private func ids(_ requests: [PlannedNotification]) -> Set<String> {
    Set(requests.map(\.id))
}

private func request(_ id: String, in requests: [PlannedNotification]) -> PlannedNotification? {
    requests.first { $0.id == id }
}

private let normalGoBody = "Out the door 7:45. Drive 32, gym 8:23. Leave the gym by 9:05. Full session."

@Suite("Notification queue")
struct QueueTests {
    @Test func aNormalWeekGetsGoAndNudgeOnEachSessionAndPrepTheNightBefore() {
        let queue = plan(HabitLog(firstDay: sunday), at("2026-10-18", 12))
        let week = queue.filter { $0.fireAt.date < day("2026-10-25") }

        for key in ["2026-10-19", "2026-10-20", "2026-10-21", "2026-10-22"] {
            let go = request("go-\(key)", in: week)
            #expect(go?.fireAt == at(key, 7, 40))
            #expect(go?.subjectDay == day(key))
            #expect(go?.title == "Out the door 7:45")
            #expect(go?.body == normalGoBody)
            #expect(go?.category == .go)
            #expect(request("nudge-\(key)", in: week)?.fireAt == at(key, 10))
            #expect(request("nudge-\(key)", in: week)?.title == "Did you go?")
        }
        for (eve, session) in [("2026-10-18", "2026-10-19"), ("2026-10-19", "2026-10-20"),
                               ("2026-10-20", "2026-10-21"), ("2026-10-21", "2026-10-22")] {
            let prep = request("prep-\(eve)", in: week)
            #expect(prep?.fireAt == at(eve, 20))
            #expect(prep?.subjectDay == day(session))
            #expect(prep?.title == "Tomorrow 7:45")
            #expect(prep?.body == "Bag packed, clothes out. Leave the gym by 9:05.")
        }
        #expect(week.count == 12)
        #expect(!week.contains { $0.fireAt.date == day("2026-10-23") || $0.fireAt.date == day("2026-10-24") })
        #expect(!week.contains { $0.subjectDay == day("2026-10-23") })

        #expect(queue.filter(\.isTimeSensitive).allSatisfy { $0.kind == .go })
        #expect(queue.filter { $0.kind == .go }.allSatisfy { $0.isTimeSensitive })
        let ordered = queue.sorted { ($0.fireAt, $0.id) < ($1.fireAt, $1.id) }
        #expect(queue == ordered)
    }

    @Test func idsAreUniqueAndTheQueueStaysUnderTheSystemLimit() {
        let logs = [
            HabitLog(firstDay: sunday),
            HabitLog(firstDay: sunday, rests: [day("2026-10-20"), day("2026-10-27")]),
            HabitLog(firstDay: sunday, breaks: [PlannedBreak(kind: .recovery, firstDay: day("2026-10-21"), lastDay: day("2026-10-26"))]),
        ]
        for log in logs {
            let queue = plan(log, at("2026-10-18", 12))
            #expect(ids(queue).count == queue.count)
            #expect(queue.count < 64)
            #expect(queue.allSatisfy { NotificationPlanner.isOwned(identifier: $0.id) })
            #expect(queue.allSatisfy { $0.id == "\($0.kind.rawValue)-\($0.fireAt.date.key)" })
        }
    }

    @Test func aDeclaredRestSwapsWednesdayForFridayWithoutDuplicates() {
        let now = at("2026-10-19", 12)
        let before = plan(HabitLog(firstDay: sunday), now)
        let after = plan(HabitLog(firstDay: sunday, rests: [day("2026-10-21")]), now)
        let diff = NotificationPlanner.diff(current: before, next: after)

        #expect(diff.removeIDs == ["go-2026-10-21", "nudge-2026-10-21", "prep-2026-10-20"])
        #expect(diff.upserts.map(\.id) == ["prep-2026-10-22", "go-2026-10-23", "nudge-2026-10-23"])
        #expect(request("prep-2026-10-22", in: diff.upserts)?.subjectDay == day("2026-10-23"))
        #expect(ids(after).count == after.count)
        #expect(Set(diff.removeIDs).isDisjoint(with: diff.upserts.map(\.id)))
    }

    @Test func aDeclaredBreakRemovesAllItsDatesInOneDiff() {
        let now = at("2026-10-19", 12)
        let breakDays = (21...25).map { day("2026-10-\($0)") }
        let trip = PlannedBreak(kind: .travel, firstDay: day("2026-10-21"), lastDay: day("2026-10-25"))
        let before = plan(HabitLog(firstDay: sunday), now)
        let after = plan(HabitLog(firstDay: sunday, breaks: [trip]), now)
        let diff = NotificationPlanner.diff(current: before, next: after)

        #expect(diff.removeIDs == [
            "go-2026-10-21", "go-2026-10-22",
            "nudge-2026-10-21", "nudge-2026-10-22",
            "prep-2026-10-20", "prep-2026-10-21", "prep-2026-10-25",
        ])
        #expect(diff.upserts.isEmpty)
        #expect(!after.contains { breakDays.contains($0.fireAt.date) || breakDays.contains($0.subjectDay) })
        // Monday the 26th still gets its morning, but no prep on Sunday the 25th, a break day.
        #expect(request("go-2026-10-26", in: after) != nil)
        #expect(!after.contains { $0.kind == .prep && $0.subjectDay == day("2026-10-26") })
    }

    @Test func aTrafficCheckReplacesExactlyTheGoAlert() {
        let log = HabitLog(firstDay: sunday)
        let now = at("2026-10-20", 7, 10)
        let today = now.date
        let before = plan(log, now)
        let after = plan(log, now, overrides: [today: 45])
        let diff = NotificationPlanner.diff(current: before, next: after)

        #expect(diff.removeIDs.isEmpty)
        #expect(diff.upserts.map(\.id) == ["go-2026-10-20"])
        let go = diff.upserts[0]
        #expect(go.fireAt == at("2026-10-20", 7, 30))
        #expect(go.fireAt < request("go-2026-10-20", in: before)!.fireAt)
        #expect(go.title == "Out the door 7:30")
        #expect(go.body == "Out the door 7:30. Drive 45, gym 8:21. Leave the gym by 9:05. Full session.")
        #expect(go.isTimeSensitive)
    }

    @Test func aDetectedWorkoutRemovesExactlyTheNudge() {
        let now = at("2026-10-20", 9, 10)
        let before = plan(HabitLog(firstDay: sunday), now)
        let workout = WorkoutSample(id: "w-tue", day: day("2026-10-20"), durationMinutes: 45)
        let after = plan(HabitLog(firstDay: sunday, workouts: [workout]), now)
        let diff = NotificationPlanner.diff(current: before, next: after)

        #expect(diff.removeIDs == ["nudge-2026-10-20"])
        #expect(diff.upserts.isEmpty)
    }

    @Test func laterTodayRemovesThatDaysNudge() {
        let now = at("2026-10-20", 8)
        let before = plan(HabitLog(firstDay: sunday), now)
        let after = plan(HabitLog(firstDay: sunday, laterToday: [day("2026-10-20")]), now)
        let diff = NotificationPlanner.diff(current: before, next: after)

        #expect(diff.removeIDs == ["nudge-2026-10-20"])
        #expect(diff.upserts.isEmpty)
    }

    @Test func aMissAddsFridayAndACompletedWeekRemovesIt() {
        let fridayIDs: Set = ["prep-2026-10-22", "go-2026-10-23", "nudge-2026-10-23"]

        // Monday visited, Tuesday open, then Tuesday closes with no visit.
        let log = HabitLog(firstDay: sunday, manualEntries: went("2026-10-19"))
        let tuesday = plan(log, at("2026-10-20", 12))
        let wednesday = plan(log, at("2026-10-21", 5))
        #expect(ids(tuesday).isDisjoint(with: fridayIDs))
        let missDiff = NotificationPlanner.diff(current: tuesday, next: wednesday)
        #expect(fridayIDs.isSubset(of: Set(missDiff.upserts.map(\.id))))
        // The rest of the upserts are the horizon rolling forward a day.
        #expect(Set(missDiff.upserts.filter { $0.fireAt.date < day("2026-10-25") }.map(\.id)) == fridayIDs)

        // Tuesday's workout arrives late, making four visits by Thursday.
        let thursday = at("2026-10-22", 12)
        let threeVisits = HabitLog(firstDay: sunday, manualEntries: went("2026-10-19", "2026-10-21", "2026-10-22"))
        var fourVisits = threeVisits
        fourVisits.workouts = [WorkoutSample(id: "w-tue", day: day("2026-10-20"), durationMinutes: 45)]
        let open = plan(threeVisits, thursday)
        let done = plan(fourVisits, thursday)
        #expect(fridayIDs.isSubset(of: ids(open)))
        #expect(!done.contains { $0.subjectDay == day("2026-10-23") })
        let doneDiff = NotificationPlanner.diff(current: open, next: done)
        #expect(Set(doneDiff.removeIDs) == fridayIDs)
        #expect(doneDiff.upserts.isEmpty)
    }

    @Test func theReturnMorningQuotesTheReentryPlanVerbatim() {
        let sentence = "On Thursday the 22nd at 7:45 I leave for a 15-minute show-up session."
        let trip = PlannedBreak(kind: .travel, firstDay: day("2026-10-19"), lastDay: day("2026-10-21"), reentryPlan: sentence)
        let queue = plan(HabitLog(firstDay: sunday, breaks: [trip]), at("2026-10-18", 12))

        #expect(request("go-2026-10-22", in: queue)?.body == "\(normalGoBody) \u{201C}\(sentence)\u{201D}")
        #expect(request("go-2026-10-26", in: queue)?.body == normalGoBody)
        #expect(request("prep-2026-10-21", in: queue) == nil)
        #expect(!queue.contains { trip.contains($0.fireAt.date) })
    }

    @Test func aRecoveryReviewFiresOnTheReviewDateAndIsAloneOnBreakDays() {
        let recovery = PlannedBreak(kind: .recovery, firstDay: day("2026-10-20"), lastDay: day("2026-10-22"))
        let queue = plan(HabitLog(firstDay: sunday, breaks: [recovery]), at("2026-10-19", 12))

        let review = request("review-2026-10-22", in: queue)
        #expect(review?.fireAt == at("2026-10-22", 20))
        #expect(review?.breakID == recovery.id)
        #expect(review?.subjectDay == day("2026-10-22"))
        #expect(review?.kind == .review)
        #expect(review?.category == .review)
        #expect(review?.title == "Back tomorrow?")
        #expect(review?.isTimeSensitive == false)
        #expect(queue.filter { recovery.contains($0.fireAt.date) }.map(\.id) == ["review-2026-10-22"])
        #expect(queue.filter { $0.kind != .review }.allSatisfy { $0.breakID == nil })
    }

    @Test func twoRecoveryBreaksWithOneReviewDateGetOneQuestion() {
        let a = PlannedBreak(kind: .recovery, firstDay: day("2026-10-20"), lastDay: day("2026-10-22"))
        let b = PlannedBreak(kind: .recovery, firstDay: day("2026-10-21"), lastDay: day("2026-10-22"))
        let queue = plan(HabitLog(firstDay: sunday, breaks: [a, b]), at("2026-10-19", 12))
        let reviews = queue.filter { $0.kind == .review }
        #expect(reviews.count == 1)
        #expect(reviews.first?.breakID == [a, b].map(\.id).min { $0.uuidString < $1.uuidString })
    }

    @Test func pastRequestsAreDropped() {
        let queue = plan(HabitLog(firstDay: sunday), at("2026-10-20", 7, 41))
        #expect(request("go-2026-10-20", in: queue) == nil)
        #expect(request("nudge-2026-10-20", in: queue) != nil)
        #expect(queue.allSatisfy { $0.fireAt > at("2026-10-20", 7, 41) })
    }

    @Test func everyActionMapsToItsEffect() {
        let tuesday = day("2026-10-20")
        let breakID = UUID()
        let planner = NotificationPlanner.self
        #expect(planner.effect(of: .restTomorrow, subjectDay: tuesday, breakID: nil) == .declareRest(tuesday))
        #expect(planner.effect(of: .bodyOff, subjectDay: tuesday, breakID: nil) == .openHardDay(tuesday, .bodyOff))
        #expect(planner.effect(of: .notToday, subjectDay: tuesday, breakID: nil) == .openHardDay(tuesday, nil))
        #expect(planner.effect(of: .went, subjectDay: tuesday, breakID: nil) == .logVisit(tuesday))
        #expect(planner.effect(of: .laterToday, subjectDay: tuesday, breakID: nil) == .laterToday(tuesday))
        #expect(planner.effect(of: .didntGo, subjectDay: tuesday, breakID: nil) == .markDidntGo(tuesday))
        #expect(planner.effect(of: .back, subjectDay: tuesday, breakID: breakID) == .endRecoveryBreak(breakID))
        #expect(planner.effect(of: .oneMoreWeek, subjectDay: tuesday, breakID: breakID) == .extendRecoveryBreak(breakID))
        #expect(planner.effect(of: .back, subjectDay: tuesday, breakID: nil) == nil)
        #expect(planner.effect(of: .oneMoreWeek, subjectDay: tuesday, breakID: nil) == nil)
    }

    @Test func categoriesCarryTheirActions() {
        #expect(NotificationCategory.prep.actions == [.restTomorrow])
        #expect(NotificationCategory.go.actions == [.bodyOff, .notToday])
        #expect(NotificationCategory.nudge.actions == [.went, .laterToday, .didntGo])
        #expect(NotificationCategory.review.actions == [.back, .oneMoreWeek])
        #expect(NotificationAction.allCases.filter(\.opensApp) == [.bodyOff, .notToday])
        #expect(NotificationAction.didntGo.title == "No")
        #expect(NotificationPlanner.isOwned(identifier: "go-2026-10-20"))
        #expect(!NotificationPlanner.isOwned(identifier: "other-2026-10-20"))
    }
}
