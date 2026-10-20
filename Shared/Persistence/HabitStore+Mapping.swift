import Foundation
import HabitCore
import SwiftData

// Records -> HabitLog, collapsing the duplicates a CloudKit merge can produce.
// Each group of records sharing a stable id keeps one survivor (holding the
// merged values); the rest are appended to `redundant` for deletion.

extension HabitStore {
    /// Builds a snapshot from every record. Ensures a `MetaRecord` exists,
    /// inserting one dated `today` on first launch.
    func buildLog(today: LocalDate, redundant: inout [any PersistentModel]) -> HabitLog {
        var log = HabitLog(firstDay: collapseMeta(today: today, redundant: &redundant))

        // Workouts: same workoutID -> keep the earliest import.
        let workouts = survivors(of: fetch(FetchDescriptor<WorkoutRecord>()), by: \.workoutID, redundant: &redundant) { group in
            group.min { $0.importedAt < $1.importedAt }!
        }
        log.workouts = workouts.compactMap(\.sample).sorted { ($0.day, $0.id) < ($1.day, $1.id) }

        // Manual entries: same entryID -> keep one.
        let entries = survivors(of: fetch(FetchDescriptor<ManualEntryRecord>()), by: \.entryID, redundant: &redundant) { $0[0] }
        log.manualEntries = entries.compactMap(\.entry).sorted {
            ($0.recordedAt, $0.id.uuidString) < ($1.recordedAt, $1.id.uuidString)
        }

        // Breaks: same breakID -> keep one.
        let breaks = survivors(of: fetch(FetchDescriptor<BreakRecord>()), by: \.breakID, redundant: &redundant) { $0[0] }
        log.breaks = breaks.compactMap(\.plannedBreak).sorted {
            ($0.firstDay, $0.lastDay, $0.id.uuidString) < ($1.firstDay, $1.lastDay, $1.id.uuidString)
        }

        // Week targets: same week -> the lowest target wins (no timestamp to
        // say which is newer, and lowering is the deliberate act).
        let targets = survivors(of: fetch(FetchDescriptor<WeekTargetRecord>()), by: \.weekStartKey, redundant: &redundant) { group in
            let survivor = group[0]
            survivor.target = group.map(\.target).min()!
            return survivor
        }
        for record in targets {
            guard let weekStart = LocalDate(record.weekStartKey) else { continue }
            log.weekTargets[weekStart] = record.target
        }

        // Days: same dayKey -> OR the flags; the newest non-nil miss reason wins.
        let days = survivors(of: fetch(FetchDescriptor<DayRecord>()), by: \.dayKey, redundant: &redundant) { group in
            let survivor = group[0]
            guard group.count > 1 else { return survivor }
            survivor.isRest = group.contains(where: \.isRest)
            survivor.isLaterToday = group.contains(where: \.isLaterToday)
            survivor.missReason = group
                .filter { $0.missReason != nil }
                .max { $0.updatedAt < $1.updatedAt }?
                .missReason
            survivor.updatedAt = group.map(\.updatedAt).max()!
            return survivor
        }
        for record in days {
            guard let day = LocalDate(record.dayKey) else { continue }
            if record.isRest { log.rests.insert(day) }
            if record.isLaterToday { log.laterToday.insert(day) }
            if let raw = record.missReason, let reason = MissReason(rawValue: raw) {
                log.missReasons[day] = reason
            }
        }
        return log
    }

    /// The earliest stored first day; inserts a `MetaRecord` for `today` if none.
    private func collapseMeta(today: LocalDate, redundant: inout [any PersistentModel]) -> LocalDate {
        let records = fetch(FetchDescriptor<MetaRecord>())
        let dated = records.compactMap { record in LocalDate(record.firstDayKey).map { (record, $0) } }
        guard let earliest = dated.min(by: { $0.1 < $1.1 }) else {
            records.forEach { redundant.append($0) }
            context.insert(MetaRecord(firstDayKey: today.key))
            return today
        }
        for record in records where record !== earliest.0 {
            redundant.append(record)
        }
        return earliest.1
    }

    /// Groups `records` by `key`, picks one survivor per group with `merge`,
    /// and marks the others redundant.
    private func survivors<Record: PersistentModel, Key: Hashable>(
        of records: [Record],
        by key: (Record) -> Key,
        redundant: inout [any PersistentModel],
        merge: ([Record]) -> Record
    ) -> [Record] {
        Dictionary(grouping: records, by: key).values.map { group in
            let survivor = merge(group)
            for record in group where record !== survivor {
                redundant.append(record)
            }
            return survivor
        }
    }
}

// MARK: - Record <-> value mapping

extension WorkoutRecord {
    convenience init(_ sample: WorkoutSample, importedAt: Date) {
        self.init(workoutID: sample.id, dayKey: sample.day.key, durationMinutes: sample.durationMinutes, importedAt: importedAt)
    }

    var sample: WorkoutSample? {
        LocalDate(dayKey).map { WorkoutSample(id: workoutID, day: $0, durationMinutes: durationMinutes) }
    }
}

extension ManualEntryRecord {
    convenience init(_ entry: ManualEntry) {
        self.init(entryID: entry.id, dayKey: entry.day.key, mark: entry.mark.rawValue, recordedAt: entry.recordedAt)
    }

    var entry: ManualEntry? {
        guard let day = LocalDate(dayKey), let mark = ManualMark(rawValue: mark) else { return nil }
        return ManualEntry(id: entryID, day: day, mark: mark, recordedAt: recordedAt)
    }
}

extension BreakRecord {
    convenience init(_ plannedBreak: PlannedBreak) {
        self.init(
            breakID: plannedBreak.id,
            kind: plannedBreak.kind.rawValue,
            firstDayKey: plannedBreak.firstDay.key,
            lastDayKey: plannedBreak.lastDay.key,
            reentryPlan: plannedBreak.reentryPlan
        )
    }

    func apply(_ plannedBreak: PlannedBreak) {
        kind = plannedBreak.kind.rawValue
        firstDayKey = plannedBreak.firstDay.key
        lastDayKey = plannedBreak.lastDay.key
        reentryPlan = plannedBreak.reentryPlan
    }

    var plannedBreak: PlannedBreak? {
        guard let kind = PlannedBreak.Kind(rawValue: kind),
              let first = LocalDate(firstDayKey),
              let last = LocalDate(lastDayKey) else { return nil }
        return PlannedBreak(id: breakID, kind: kind, firstDay: first, lastDay: last, reentryPlan: reentryPlan)
    }
}
