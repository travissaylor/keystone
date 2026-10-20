/// What the evidence says about one day.
public enum VisitEvidence: Equatable, Sendable {
    /// Nothing recorded yet. Never a miss on its own while the day is open.
    case unknown
    /// A qualifying Watch workout and no manual mark. Counts as a visit.
    case candidate
    /// The latest manual mark is "went". Survives any later sensor evidence.
    case confirmed
    /// The latest manual mark is "didn't go". Overrides a detected workout.
    case rejected

    public var isVisit: Bool {
        self == .candidate || self == .confirmed
    }
}

extension HabitLog {
    /// Reconciles a day's evidence: manual beats sensor, the latest manual
    /// mark wins, and duplicate or multiple workouts make at most one visit.
    /// A deleted workout is simply absent from `workouts`; a manual "went"
    /// stands without it.
    public func evidence(on day: LocalDate) -> VisitEvidence {
        let manual = manualEntries
            .filter { $0.day == day }
            .max { ($0.recordedAt, $0.id.uuidString) < ($1.recordedAt, $1.id.uuidString) }
        if let manual {
            return manual.mark == .went ? .confirmed : .rejected
        }
        let qualifies = workouts.contains {
            $0.day == day && $0.durationMinutes >= Schedule.minimumWorkoutMinutes
        }
        return qualifies ? .candidate : .unknown
    }

    public func isVisit(_ day: LocalDate) -> Bool {
        evidence(on: day).isVisit
    }

    /// Every day that counts as a visit, at most one per calendar day.
    public var visitDays: Set<LocalDate> {
        let days = Set(workouts.map(\.day)).union(manualEntries.map(\.day))
        return days.filter(isVisit)
    }
}
