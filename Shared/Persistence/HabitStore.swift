import Foundation
import HabitCore
import Observation
import OSLog
import SwiftData

/// The app's single source of truth: wraps a `ModelContext` and publishes the
/// recorded facts as a `HabitLog` snapshot. HabitCore derives everything else.
///
/// Every mutation saves the context and then reloads, so `log` always reflects
/// what is on disk, CloudKit duplicates already collapsed.
@Observable
@MainActor
final class HabitStore {
    /// Everything recorded, rebuilt by `reload()`.
    private(set) var log: HabitLog

    /// Called after every mutation and every reload with the fresh snapshot.
    /// Later units hook notification-queue and widget refreshes here.
    @ObservationIgnored var onLogChanged: ((HabitLog) -> Void)?

    var timeZone: TimeZone

    @ObservationIgnored let context: ModelContext
    @ObservationIgnored private let clock: () -> Date

    init(context: ModelContext, timeZone: TimeZone = .current, now: @escaping () -> Date = Date.init) {
        self.context = context
        self.timeZone = timeZone
        self.clock = now
        self.log = HabitLog(firstDay: LocalDate(now(), in: timeZone))
        reload()
    }

    func today() -> LocalDate {
        LocalDate(clock(), in: timeZone)
    }

    func now() -> LocalMoment {
        LocalMoment(clock(), in: timeZone)
    }

    // MARK: Reload

    /// Rebuilds `log` from every record, deleting the redundant duplicates a
    /// CloudKit merge may have produced, and ensures a `MetaRecord` exists.
    func reload() {
        var redundant: [any PersistentModel] = []
        let snapshot = buildLog(today: today(), redundant: &redundant)
        if !redundant.isEmpty {
            redundant.forEach { context.delete($0) }
        }
        if context.hasChanges {
            save()
        }
        log = snapshot
        onLogChanged?(snapshot)
    }

    // MARK: Visits

    /// A manual "went".
    func logVisit(on day: LocalDate) {
        addManualEntry(.went, on: day)
    }

    /// A confirmed "didn't go". Overrides a detected workout.
    func markDidntGo(on day: LocalDate) {
        addManualEntry(.didntGo, on: day)
    }

    private func addManualEntry(_ mark: ManualMark, on day: LocalDate) {
        context.insert(ManualEntryRecord(entryID: UUID(), dayKey: day.key, mark: mark.rawValue, recordedAt: clock()))
        commit()
    }

    // MARK: Day declarations

    func declareRest(on day: LocalDate) {
        updateDay(day) { $0.isRest = true }
    }

    func clearRest(on day: LocalDate) {
        updateDay(day) { $0.isRest = false }
    }

    func markLaterToday(on day: LocalDate) {
        updateDay(day) { $0.isLaterToday = true }
    }

    func setMissReason(_ reason: MissReason?, on day: LocalDate) {
        updateDay(day) { $0.missReason = reason?.rawValue }
    }

    /// Applies `change` to every record for `day` (creating one if absent), so
    /// an uncollapsed duplicate can't resurrect the old value.
    private func updateDay(_ day: LocalDate, _ change: (DayRecord) -> Void) {
        let stamp = clock()
        for record in dayRecords(forKey: day.key, creating: true) {
            change(record)
            record.updatedAt = stamp
        }
        commit()
    }

    // MARK: Breaks

    func declareBreak(_ plannedBreak: PlannedBreak) {
        context.insert(BreakRecord(plannedBreak))
        commit()
    }

    /// Replaces the stored break with the same id, or inserts it if absent.
    func updateBreak(_ plannedBreak: PlannedBreak) {
        let records = breakRecords(id: plannedBreak.id)
        if records.isEmpty {
            context.insert(BreakRecord(plannedBreak))
        }
        records.forEach { $0.apply(plannedBreak) }
        commit()
    }

    func removeBreak(id: UUID) {
        breakRecords(id: id).forEach { context.delete($0) }
        commit()
    }

    // MARK: Week targets

    /// Lowers (or restores) the target for the week containing `day`. `nil`
    /// clears it back to the default.
    func setWeekTarget(_ target: Int?, forWeekOf day: LocalDate) {
        let key = day.weekStart.key
        let records = fetch(FetchDescriptor<WeekTargetRecord>(predicate: #Predicate { $0.weekStartKey == key }))
        if let target {
            if records.isEmpty {
                context.insert(WeekTargetRecord(weekStartKey: key, target: target))
            }
            records.forEach { $0.target = target }
        } else {
            records.forEach { context.delete($0) }
        }
        commit()
    }

    // MARK: Workouts

    /// Inserts only workouts whose id isn't stored yet. Idempotent.
    func importWorkouts(_ samples: [WorkoutSample]) {
        var known = Set(fetch(FetchDescriptor<WorkoutRecord>()).map(\.workoutID))
        let stamp = clock()
        for sample in samples where known.insert(sample.id).inserted {
            context.insert(WorkoutRecord(sample, importedAt: stamp))
        }
        commit()
    }

    /// Removes workouts HealthKit reported deleted.
    func deleteWorkouts(ids: Set<String>) {
        for record in fetch(FetchDescriptor<WorkoutRecord>()) where ids.contains(record.workoutID) {
            context.delete(record)
        }
        commit()
    }

    // MARK: Restore

    /// Merges a restored log in without overwriting anything already stored:
    /// absent workouts, entries and breaks are inserted, rests and later-today
    /// are unioned, week targets and miss reasons fill only absent keys, and
    /// the first day moves earlier if the incoming one is.
    func importLog(_ incoming: HabitLog) {
        var redundant: [any PersistentModel] = []
        let current = buildLog(today: today(), redundant: &redundant)
        redundant.forEach { context.delete($0) }

        let stamp = clock()
        let workoutIDs = Set(current.workouts.map(\.id))
        for sample in incoming.workouts where !workoutIDs.contains(sample.id) {
            context.insert(WorkoutRecord(sample, importedAt: stamp))
        }
        let entryIDs = Set(current.manualEntries.map(\.id))
        for entry in incoming.manualEntries where !entryIDs.contains(entry.id) {
            context.insert(ManualEntryRecord(entry))
        }
        let breakIDs = Set(current.breaks.map(\.id))
        for plannedBreak in incoming.breaks where !breakIDs.contains(plannedBreak.id) {
            context.insert(BreakRecord(plannedBreak))
        }
        for (weekStart, target) in incoming.weekTargets where current.weekTargets[weekStart] == nil {
            context.insert(WeekTargetRecord(weekStartKey: weekStart.key, target: target))
        }

        let dayKeys = incoming.rests.union(incoming.laterToday).union(incoming.missReasons.keys)
        for day in dayKeys {
            for record in dayRecords(forKey: day.key, creating: true) {
                if incoming.rests.contains(day) { record.isRest = true }
                if incoming.laterToday.contains(day) { record.isLaterToday = true }
                if current.missReasons[day] == nil, let reason = incoming.missReasons[day] {
                    record.missReason = reason.rawValue
                }
                record.updatedAt = max(record.updatedAt, stamp)
            }
        }

        if incoming.firstDay < current.firstDay {
            fetch(FetchDescriptor<MetaRecord>()).forEach { $0.firstDayKey = incoming.firstDay.key }
        }
        commit()
    }

    // MARK: Plumbing

    private func commit() {
        save()
        reload()
    }

    private func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            Self.logger.error("Save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func fetch<Model: PersistentModel>(_ descriptor: FetchDescriptor<Model>) -> [Model] {
        do {
            return try context.fetch(descriptor)
        } catch {
            Self.logger.error("Fetch failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private func dayRecords(forKey key: String, creating: Bool) -> [DayRecord] {
        let records = fetch(FetchDescriptor<DayRecord>(predicate: #Predicate { $0.dayKey == key }))
        guard records.isEmpty, creating else { return records }
        let created = DayRecord(dayKey: key, updatedAt: clock())
        context.insert(created)
        return [created]
    }

    private func breakRecords(id: UUID) -> [BreakRecord] {
        fetch(FetchDescriptor<BreakRecord>(predicate: #Predicate { $0.breakID == id }))
    }

    static let logger = Logger(subsystem: "com.travissaylor.keystone", category: "HabitStore")
}
