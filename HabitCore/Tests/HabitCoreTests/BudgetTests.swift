import Testing
@testable import HabitCore

@Suite("Budget")
struct BudgetTests {
    private func t(_ hour: Int, _ minute: Int) -> TimeOfDay { TimeOfDay(hour: hour, minute: minute) }

    @Test func latestExitIsNineOhFive() {
        #expect(Budget.latestGymExit == t(9, 5))
    }

    @Test func measuredMorningIsFull() {
        let plan = Budget.plan(inboundDriveMinutes: 32)
        #expect(plan.doorTime == t(7, 45))
        #expect(plan.gymArrival == t(8, 23))
        #expect(plan.gymMinutes == 42)
        #expect(plan.fit == .fits(.full))
        #expect(plan.leavesEarly == false)
        #expect(plan.floorHit == false)
    }

    @Test func fasterDriveGivesMoreMinutes() {
        let plan = Budget.plan(inboundDriveMinutes: 25)
        #expect(plan.doorTime == t(7, 45))
        #expect(plan.gymArrival == t(8, 16))
        #expect(plan.gymMinutes == 49)
        #expect(plan.fit == .fits(.full))
    }

    @Test func slowDriveLeavesEarlierRoundedDown() {
        let plan = Budget.plan(inboundDriveMinutes: 40)
        #expect(plan.doorTime == t(7, 35))
        #expect(plan.leavesEarly)
        #expect(plan.floorHit == false)
        #expect(plan.fit == .fits(.full))
        #expect(plan.gymMinutes >= Schedule.fullSessionMinutes)
        // At 7:45 this drive would arrive 8:31 with 34 minutes.
        #expect(Budget.gymArrival(door: t(7, 45), inboundDriveMinutes: 40) == t(8, 31))
        #expect(Budget.gymMinutes(door: t(7, 45), inboundDriveMinutes: 40) == 34)
    }

    @Test func floorHitShrinksSession() {
        let plan = Budget.plan(inboundDriveMinutes: 55)
        #expect(plan.doorTime == t(7, 30))
        #expect(plan.gymArrival == t(8, 31))
        #expect(plan.gymMinutes == 34)
        #expect(plan.fit == .fits(.short))
        #expect(plan.floorHit)
        #expect(plan.leavesEarly)
    }

    @Test func tripThatDoesntFit() {
        // Even at the floor, the 7:30 door leaves under 15 minutes.
        let plan = Budget.plan(inboundDriveMinutes: 90)
        #expect(plan.fit == .doesntFit)
        #expect(plan.floorHit)
        #expect(Budget.goAlertBody(for: plan) == "Today's trip doesn't fit before 9:30. Later today counts in full.")
    }

    @Test func seventyMinuteDriveIsStillAShowUp() {
        // 7:30 + 70 + 6 = 8:46, leaving 19 minutes.
        let plan = Budget.plan(inboundDriveMinutes: 70)
        #expect(plan.gymMinutes == 19)
        #expect(plan.fit == .fits(.showUp))
    }

    @Test func legsAreAsymmetric() {
        let fast = Budget.plan(inboundDriveMinutes: 25)
        let slow = Budget.plan(inboundDriveMinutes: 50)
        #expect(fast.latestGymExit == t(9, 5))
        #expect(slow.latestGymExit == t(9, 5))
    }

    @Test func departureAlreadyPast() {
        let plan = Budget.plan(inboundDriveMinutes: 32, now: t(7, 52))
        #expect(plan.doorTime == t(7, 52))
        #expect(plan.goAlertTime == nil)
        #expect(plan.gymMinutes == 35)
        #expect(plan.fit == .fits(.short))
        #expect(plan.leavesEarly == false)
    }

    @Test func nowBeforeDoorChangesNothing() {
        #expect(Budget.plan(inboundDriveMinutes: 32, now: t(7, 0)) == Budget.plan(inboundDriveMinutes: 32))
    }

    @Test func negativeGymMinutesDontFit() {
        #expect(Budget.fit(gymMinutes: -5) == .doesntFit)
        #expect(Budget.gymMinutes(door: t(8, 30), inboundDriveMinutes: 60) < 0)
        #expect(Budget.plan(inboundDriveMinutes: 32, now: t(9, 0)).fit == .doesntFit)
    }

    @Test func goAlertIsClamped() {
        #expect(Budget.plan(inboundDriveMinutes: 32).goAlertTime == t(7, 40))
        #expect(Budget.plan(inboundDriveMinutes: 40).goAlertTime == t(7, 30))
        #expect(Budget.plan(inboundDriveMinutes: 55).goAlertTime == t(7, 30))
    }

    @Test(arguments: [
        (40, SessionFit.fits(.full)), (39, .fits(.short)),
        (25, .fits(.short)), (24, .fits(.showUp)),
        (15, .fits(.showUp)), (14, .doesntFit),
    ])
    func thresholds(minutes: Int, expected: SessionFit) {
        #expect(Budget.fit(gymMinutes: minutes) == expected)
    }

    @Test func fullAlertBodyIsExact() {
        let plan = Budget.plan(inboundDriveMinutes: 32)
        #expect(Budget.goAlertBody(for: plan) == "Out the door 7:45. Drive 32, gym 8:23. Leave the gym by 9:05. Full session.")
        #expect(Budget.exitLine(for: plan) == "Leave the gym by 9:05")
    }

    @Test func shortAndShowUpBodies() {
        #expect(Budget.goAlertBody(for: Budget.plan(inboundDriveMinutes: 55))
            == "Out the door 7:30. Drive 55, gym 8:31. Leave the gym by 9:05. Short session, warm-up plus two lifts.")
        #expect(Budget.goAlertBody(for: Budget.plan(inboundDriveMinutes: 70))
            == "Out the door 7:30. Drive 70, gym 8:46. Leave the gym by 9:05. Show-up session, 15 minutes. Counts in full.")
    }
}
