import Foundation
import Testing
@testable import HabitCore

@Suite("Export")
struct ExportTests {
    let monday = LocalDate("2026-10-19")!
    let tuesday = LocalDate("2026-10-20")!
    let exportedAt = Date(timeIntervalSince1970: 1_800_000_000)

    func fullLog() -> HabitLog {
        HabitLog(
            firstDay: monday,
            workouts: [
                WorkoutSample(id: "A", day: tuesday, durationMinutes: 45),
                WorkoutSample(id: "B", day: monday, durationMinutes: 30),
            ],
            manualEntries: [
                ManualEntry(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, day: monday, mark: .went, recordedAt: exportedAt),
            ],
            rests: [monday.adding(days: 7)],
            laterToday: [tuesday],
            breaks: [
                PlannedBreak(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                    kind: .travel, firstDay: monday.adding(days: 14), lastDay: monday.adding(days: 18),
                    reentryPlan: "Go at 7:45 and keep it short."
                ),
            ],
            weekTargets: [monday: 3],
            missReasons: [tuesday.adding(days: 1): .work]
        ).sortedForTest()
    }

    @Test func roundTrips() throws {
        let log = fullLog()
        let envelope = try Export.decode(Export.encode(log, exportedAt: exportedAt))
        #expect(envelope.log == log)
        #expect(envelope.exportedAt == exportedAt)
        #expect(envelope.version == ExportEnvelope.currentVersion)
    }

    @Test func sameLogEncodesToIdenticalBytes() throws {
        let log = HabitLog(firstDay: monday, rests: [monday, tuesday, monday.adding(days: 3), monday.adding(days: 9)])
        let first = try Export.encode(log, exportedAt: exportedAt)
        let second = try Export.encode(log, exportedAt: exportedAt)
        #expect(first == second)
        #expect(try Export.encode(fullLog(), exportedAt: exportedAt) == Export.encode(fullLog(), exportedAt: exportedAt))
    }

    @Test func restoreAfterReinstall() throws {
        let log = fullLog()
        let data = try Export.encode(log, exportedAt: exportedAt)
        let fresh = HabitLog(firstDay: monday.adding(days: 30))
        let restored = Export.merge(try Export.decode(data).log, into: fresh)
        #expect(restored == log)
        #expect(restored.firstDay == monday)
    }

    @Test func mergeIsIdempotentAndDoesNotDuplicate() {
        let a = fullLog()
        var b = HabitLog(firstDay: tuesday)
        b.workouts = [WorkoutSample(id: "C", day: tuesday.adding(days: 1), durationMinutes: 20)]
        b.rests = [tuesday]
        let once = Export.merge(b, into: a)
        #expect(Export.merge(b, into: once) == once)
        #expect(Export.merge(a, into: a) == a)
        #expect(once.workouts.count == 3)
        #expect(once.manualEntries.count == 1)
        #expect(once.breaks.count == 1)
    }

    @Test func existingWinsOnConflicts() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000009")!
        let existing = HabitLog(
            firstDay: monday,
            breaks: [PlannedBreak(id: id, kind: .travel, firstDay: monday, lastDay: monday.adding(days: 2))],
            weekTargets: [monday: 3]
        )
        let incoming = HabitLog(
            firstDay: monday,
            breaks: [PlannedBreak(id: id, kind: .recovery, firstDay: monday, lastDay: monday.adding(days: 9))],
            weekTargets: [monday: 2, monday.adding(days: 7): 1]
        )
        let merged = Export.merge(incoming, into: existing)
        #expect(merged.breaks.count == 1)
        #expect(merged.breaks[0].kind == .travel)
        #expect(merged.weekTargets[monday] == 3)
        #expect(merged.weekTargets[monday.adding(days: 7)] == 1)
    }

    @Test func newerVersionThrows() throws {
        let json = #"{"version": 2, "exportedAt": "2027-01-01T00:00:00Z", "log": {}}"#
        #expect(throws: ExportError.unsupportedVersion(2)) {
            try Export.decode(Data(json.utf8))
        }
    }

    @Test func fileNameUsesTheLocalDay() {
        // 2026-10-22 02:30 UTC is still 2026-10-21 in Eastern time.
        let date = Date(timeIntervalSince1970: 1_792_636_200)
        let eastern = TimeZone(identifier: "America/New_York")!
        #expect(Export.fileName(exportedAt: date, in: eastern) == "keystone-export-2026-10-21.json")
        #expect(Export.fileName(exportedAt: date, in: TimeZone(identifier: "UTC")!) == "keystone-export-2026-10-22.json")
    }
}

private extension HabitLog {
    /// Sorted the way the export sorts, so equality after a round trip is meaningful.
    func sortedForTest() -> HabitLog {
        Export.merge(self, into: HabitLog(firstDay: firstDay))
    }
}
