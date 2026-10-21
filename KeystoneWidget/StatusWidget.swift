import AppIntents
import Foundation
import HabitCore
import SwiftData
import SwiftUI
import WidgetKit

/// Everything the status widget shows, precomputed so views touch no store.
nonisolated struct StatusEntry: TimelineEntry, Sendable {
    let date: Date
    /// "Today 7:45" or "Wednesday 7:45". Nil when no session is ahead.
    let nextLine: String?
    /// "Leave the gym by 9:05", set only when the next session is today.
    let exitLine: String?
    /// "2 of 4".
    let weekLine: String
    /// Today is a planned session with no visit yet.
    let canLog: Bool
    /// Today already has a visit.
    let doneToday: Bool

    static let placeholder = StatusEntry(
        date: .now,
        nextLine: "Today 7:45",
        exitLine: "Leave the gym by 9:05",
        weekLine: "2 of 4",
        canLog: true,
        doneToday: false
    )
}

nonisolated struct StatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatusEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        guard !context.isPreview else { return completion(.placeholder) }
        // WidgetKit calls the completion exactly once; it is safe to hand to the task.
        nonisolated(unsafe) let completion = completion
        Task { completion(await Self.entries(from: .now).first ?? .placeholder) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        nonisolated(unsafe) let completion = completion
        Task {
            let entries = await Self.entries(from: .now)
            completion(Timeline(entries: entries, policy: .atEnd))
        }
    }

    /// An entry for `now`, plus one at the next 4:00 am rollover and one at
    /// 9:30 today if still ahead.
    @MainActor
    private static func buildEntries(from instant: Date) -> [StatusEntry] {
        let zone = TimeZone.current
        guard let container = try? KeystoneStore.makeContainer(syncWithCloudKit: false) else {
            return [StatusEntry(date: instant, nextLine: nil, exitLine: nil, weekLine: "", canLog: false, doneToday: false)]
        }
        let store = HabitStore(context: ModelContext(container), timeZone: zone, now: { instant })
        let moment = store.now()
        let today = moment.date
        let log = store.log
        let week = log.week(containing: today, at: moment)
        let next = log.nextSession(at: moment)
        let state = log.state(of: today, at: moment)

        var nextLine: String?
        var exitLine: String?
        if let next {
            let isToday = next == today
            nextLine = "\(isToday ? "Today" : next.weekday.name) \(Schedule.doorTime.display)"
            if isToday { exitLine = Budget.exitLine(for: Budget.plan()) }
        }
        let current = StatusEntry(
            date: instant,
            nextLine: nextLine,
            exitLine: exitLine,
            weekLine: "\(week.counted) of \(week.slots)",
            canLog: state == .planned,
            doneToday: log.isVisit(today)
        )

        var entries = [current]
        let deadline = today.startDate(in: zone).addingTimeInterval(TimeInterval(Schedule.homeDeadline.minutesSinceMidnight * 60))
        if deadline > instant { entries.append(refreshed(current, at: deadline)) }
        let rollover = today.adding(days: 1).startDate(in: zone)
            .addingTimeInterval(TimeInterval(Schedule.dayRolloverTime.minutesSinceMidnight * 60))
        entries.append(refreshed(current, at: rollover))
        return entries
    }

    /// Later entries only need to trigger a timeline reload; `.atEnd` rebuilds
    /// from the store once the last one passes.
    private static func refreshed(_ entry: StatusEntry, at date: Date) -> StatusEntry {
        StatusEntry(
            date: date,
            nextLine: entry.nextLine,
            exitLine: nil,
            weekLine: entry.weekLine,
            canLog: false,
            doneToday: entry.doneToday
        )
    }

    private static func entries(from instant: Date) async -> [StatusEntry] {
        await MainActor.run { buildEntries(from: instant) }
    }
}

struct StatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StatusEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(entry.nextLine.map { "\($0) · \(entry.weekLine)" } ?? entry.weekLine)
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Text(entry.nextLine ?? "No session ahead").font(.headline)
                if let exitLine = entry.exitLine { Text(exitLine) }
                Text("This week \(entry.weekLine)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.nextLine ?? "No session ahead").font(.headline)
                if let exitLine = entry.exitLine {
                    Text(exitLine).font(.caption).foregroundStyle(.secondary)
                }
                Text("This week \(entry.weekLine)").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if entry.canLog {
                    Button(intent: LogGymVisitIntent()) { Text("Went") }
                } else if entry.doneToday {
                    Text("Done today").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Next session, this week's count, and a one-tap "Went" on session days.
struct KeystoneStatusWidget: Widget {
    let kind = "KeystoneStatus"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatusProvider()) { entry in
            StatusWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Keystone")
        .description("Next session and this week's gym visits.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline])
    }
}
