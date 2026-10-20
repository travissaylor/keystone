import Foundation
import Testing
@testable import HabitCore

@Suite("Reconciliation")
struct ReconciliationTests {
    let tuesday = LocalDate("2026-10-20")!
    let saturday = LocalDate("2026-10-24")!
    let base = Date(timeIntervalSince1970: 1_800_000_000)

    func log(workouts: [WorkoutSample] = [], manual: [ManualEntry] = []) -> HabitLog {
        HabitLog(firstDay: LocalDate("2026-10-19")!, workouts: workouts, manualEntries: manual)
    }

    @Test func duplicateHealthKitWritesMakeOneVisit() {
        let w = WorkoutSample(id: "A", day: tuesday, durationMinutes: 45)
        let l = log(workouts: [w, w])
        #expect(l.evidence(on: tuesday) == .candidate)
        #expect(l.visitDays == [tuesday])
    }

    @Test func lateArrivingWorkoutMakesTheDayAVisit() {
        var l = log()
        #expect(l.evidence(on: tuesday) == .unknown)
        l.workouts.append(WorkoutSample(id: "A", day: tuesday, durationMinutes: 45))
        #expect(l.isVisit(tuesday))
    }

    @Test func deletedWorkoutMakesTheDayUnknownAgain() {
        var l = log(workouts: [WorkoutSample(id: "A", day: tuesday, durationMinutes: 45)])
        l.workouts.removeAll()
        #expect(l.evidence(on: tuesday) == .unknown)
        #expect(l.visitDays.isEmpty)
    }

    @Test func manualWentSurvivesWorkoutDeletion() {
        var l = log(
            workouts: [WorkoutSample(id: "A", day: tuesday, durationMinutes: 45)],
            manual: [ManualEntry(day: tuesday, mark: .went, recordedAt: base)]
        )
        l.workouts.removeAll()
        #expect(l.evidence(on: tuesday) == .confirmed)
        #expect(l.isVisit(tuesday))
    }

    @Test func manualRejectionOverridesAWorkout() {
        let l = log(
            workouts: [WorkoutSample(id: "A", day: tuesday, durationMinutes: 45)],
            manual: [ManualEntry(day: tuesday, mark: .didntGo, recordedAt: base)]
        )
        #expect(l.evidence(on: tuesday) == .rejected)
        #expect(!l.isVisit(tuesday))
        #expect(l.visitDays.isEmpty)
    }

    @Test func manualConfirmationSurvivesLaterEvidence() {
        let l = log(
            workouts: [WorkoutSample(id: "A", day: tuesday, durationMinutes: 45)],
            manual: [ManualEntry(day: tuesday, mark: .went, recordedAt: base)]
        )
        #expect(l.evidence(on: tuesday) == .confirmed)
    }

    @Test func latestManualMarkWins() {
        let l = log(manual: [
            ManualEntry(day: tuesday, mark: .didntGo, recordedAt: base),
            ManualEntry(day: tuesday, mark: .went, recordedAt: base.addingTimeInterval(60)),
        ])
        #expect(l.evidence(on: tuesday) == .confirmed)
    }

    @Test func twoWorkoutsInOneDayAreOneVisit() {
        let l = log(workouts: [
            WorkoutSample(id: "A", day: tuesday, durationMinutes: 30),
            WorkoutSample(id: "B", day: tuesday, durationMinutes: 20),
        ])
        #expect(l.visitDays == [tuesday])
    }

    @Test func shortWorkoutsDoNotCountButTenMinutesDoes() {
        #expect(log(workouts: [WorkoutSample(id: "A", day: tuesday, durationMinutes: 9)]).evidence(on: tuesday) == .unknown)
        #expect(log(workouts: [WorkoutSample(id: "A", day: tuesday, durationMinutes: 10)]).evidence(on: tuesday) == .candidate)
    }

    @Test func aSaturdayVisitCounts() {
        #expect(saturday.weekday == .saturday)
        #expect(log(workouts: [WorkoutSample(id: "A", day: saturday, durationMinutes: 45)]).isVisit(saturday))
    }
}
