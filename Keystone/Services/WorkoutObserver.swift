import Foundation
import HabitCore
import HealthKit
import OSLog

/// Feeds ended HealthKit workouts into the `HabitStore`. The workout is the
/// log: nothing here ever creates a miss, and any read failure just keeps the
/// old anchor so the next foreground or delivery retries.
@MainActor
final class WorkoutObserver {
    private let store: HabitStore
    private let healthStore = HKHealthStore()
    private let defaults = UserDefaults(suiteName: "group.com.travissaylor.keystone") ?? .standard
    private let logger = Logger(subsystem: "com.travissaylor.keystone", category: "HealthKit")

    private static let anchorKey = "healthKitWorkoutAnchor"

    init(store: HabitStore) {
        self.store = store
    }

    // MARK: Start

    /// Asks for read access, turns on background delivery, and installs the
    /// long-lived observer. Call at every launch: delivery needs the query set
    /// up each time the process starts.
    func start() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let workoutType = HKObjectType.workoutType()
        Task { [healthStore, logger] in
            do {
                try await healthStore.requestAuthorization(toShare: [], read: [workoutType])
                try await healthStore.enableBackgroundDelivery(for: workoutType, frequency: .immediate)
            } catch {
                logger.error("HealthKit setup failed: \(error.localizedDescription, privacy: .public)")
            }
            self.refresh()
        }
        let query = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] _, completion, error in
            guard error == nil, let self else {
                completion()
                return
            }
            // HealthKit's completion handler is safe to call from any thread, once.
            nonisolated(unsafe) let completion = completion
            Task { @MainActor in
                await self.sync()
                completion()
            }
        }
        healthStore.execute(query)
    }

    // MARK: Refresh

    /// Fetches workouts added or deleted since the stored anchor.
    func refresh() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        Task { await sync() }
    }

    private func sync() async {
        let start = store.log.firstDay.startDate(in: store.timeZone)
        let timeZone = store.timeZone
        do {
            let result = try await Self.fetch(from: start, anchor: loadAnchor(), timeZone: timeZone)
            if !result.samples.isEmpty {
                store.importWorkouts(result.samples)
            }
            if !result.deletedIDs.isEmpty {
                store.deleteWorkouts(ids: result.deletedIDs)
            }
            saveAnchor(result.anchor)
        } catch {
            logger.error("Workout read failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private struct Fetched: Sendable {
        var samples: [WorkoutSample]
        var deletedIDs: Set<String>
        var anchor: HKQueryAnchor
    }

    private nonisolated static func fetch(from start: Date, anchor: HKQueryAnchor?, timeZone: TimeZone) async throws -> Fetched {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil, options: .strictStartDate)
        let descriptor = HKAnchoredObjectQueryDescriptor(
            predicates: [.workout(predicate)],
            anchor: anchor
        )
        let result = try await descriptor.result(for: HKHealthStore())
        let samples = result.addedSamples.map {
            WorkoutSample(
                id: $0.uuid.uuidString,
                day: LocalDate($0.startDate, in: timeZone),
                durationMinutes: Int($0.duration / 60)
            )
        }
        return Fetched(
            samples: samples,
            deletedIDs: Set(result.deletedObjects.map { $0.uuid.uuidString }),
            anchor: result.newAnchor
        )
    }

    // MARK: Anchor

    /// Device-local on purpose: another device's anchor means nothing here.
    private func loadAnchor() -> HKQueryAnchor? {
        guard let data = defaults.data(forKey: Self.anchorKey) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    private func saveAnchor(_ anchor: HKQueryAnchor) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) else { return }
        defaults.set(data, forKey: Self.anchorKey)
    }
}
