import Foundation

/// The file written to the share sheet: a version, a timestamp, and the whole log.
public struct ExportEnvelope: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public let version: Int
    public let exportedAt: Date
    public let log: HabitLog

    public init(version: Int = ExportEnvelope.currentVersion, exportedAt: Date, log: HabitLog) {
        self.version = version
        self.exportedAt = exportedAt
        self.log = log
    }

    private enum CodingKeys: String, CodingKey { case version, exportedAt, log }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        log = try container.decode(StableLog.self, forKey: .log).log
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(exportedAt, forKey: .exportedAt)
        try container.encode(StableLog(log), forKey: .log)
    }
}

public enum ExportError: Error, Equatable {
    /// The file was written by a newer version of the app.
    case unsupportedVersion(Int)
}

/// JSON export and import of the whole log, plus the restore merge.
public enum Export {
    /// Pretty-printed, sorted keys, ISO 8601 dates, and the log's sets/arrays sorted so the same log always encodes to the same bytes.
    public static func encode(_ log: HabitLog, exportedAt: Date) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(ExportEnvelope(exportedAt: exportedAt, log: log))
    }

    /// Throws ExportError.unsupportedVersion for a version newer than currentVersion.
    public static func decode(_ data: Data) throws -> ExportEnvelope {
        struct VersionProbe: Decodable { let version: Int }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let probe = try decoder.decode(VersionProbe.self, from: data)
        guard probe.version <= ExportEnvelope.currentVersion else {
            throw ExportError.unsupportedVersion(probe.version)
        }
        return try decoder.decode(ExportEnvelope.self, from: data)
    }

    /// Suggested share-sheet file name: "keystone-export-2026-10-21.json" (date = local day of exportedAt in the given time zone).
    public static func fileName(exportedAt: Date, in timeZone: TimeZone) -> String {
        "keystone-export-\(LocalDate(exportedAt, in: timeZone).key).json"
    }

    /// Union by stable identity, idempotent: merge(a, merge(a, b)) == merge(a, b) and merge(x, x) == x.
    /// - workouts by id, manual entries by id, breaks by id (existing wins on the same id)
    /// - rests and laterToday: set union
    /// - weekTargets and missReasons: union of keys, existing wins on the same key
    /// - firstDay: the earlier of the two
    public static func merge(_ incoming: HabitLog, into existing: HabitLog) -> HabitLog {
        var workouts = Dictionary(existing.workouts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for w in incoming.workouts where workouts[w.id] == nil { workouts[w.id] = w }
        var entries = Dictionary(existing.manualEntries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for e in incoming.manualEntries where entries[e.id] == nil { entries[e.id] = e }
        var breaks = Dictionary(existing.breaks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for b in incoming.breaks where breaks[b.id] == nil { breaks[b.id] = b }

        return StableLog.sorted(HabitLog(
            firstDay: min(existing.firstDay, incoming.firstDay),
            workouts: Array(workouts.values),
            manualEntries: Array(entries.values),
            rests: existing.rests.union(incoming.rests),
            laterToday: existing.laterToday.union(incoming.laterToday),
            breaks: Array(breaks.values),
            weekTargets: existing.weekTargets.merging(incoming.weekTargets) { first, _ in first },
            missReasons: existing.missReasons.merging(incoming.missReasons) { first, _ in first }
        ))
    }
}

/// A Codable mirror of `HabitLog` that writes sets as sorted arrays and sorts every list.
private struct StableLog: Codable {
    var firstDay: LocalDate
    var workouts: [WorkoutSample]
    var manualEntries: [ManualEntry]
    var rests: [LocalDate]
    var laterToday: [LocalDate]
    var breaks: [PlannedBreak]
    var weekTargets: [LocalDate: Int]
    var missReasons: [LocalDate: MissReason]

    init(_ log: HabitLog) {
        let log = StableLog.sorted(log)
        firstDay = log.firstDay
        workouts = log.workouts
        manualEntries = log.manualEntries
        rests = log.rests.sorted()
        laterToday = log.laterToday.sorted()
        breaks = log.breaks
        weekTargets = log.weekTargets
        missReasons = log.missReasons
    }

    var log: HabitLog {
        HabitLog(
            firstDay: firstDay,
            workouts: workouts,
            manualEntries: manualEntries,
            rests: Set(rests),
            laterToday: Set(laterToday),
            breaks: breaks,
            weekTargets: weekTargets,
            missReasons: missReasons
        )
    }

    /// Workouts by id, manual entries by recordedAt then id, breaks by firstDay then id.
    static func sorted(_ log: HabitLog) -> HabitLog {
        var copy = log
        copy.workouts.sort { $0.id < $1.id }
        copy.manualEntries.sort { ($0.recordedAt, $0.id.uuidString) < ($1.recordedAt, $1.id.uuidString) }
        copy.breaks.sort { ($0.firstDay, $0.id.uuidString) < ($1.firstDay, $1.id.uuidString) }
        return copy
    }
}
