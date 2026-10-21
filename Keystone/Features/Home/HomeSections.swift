import HabitCore
import SwiftUI

/// The next session's door time with the latest gym exit directly under it.
/// With no next session in sight, the current break's return instead.
struct NextSessionSection: View {
    let now: LocalMoment
    @Environment(HabitStore.self) private var store

    var body: some View {
        let log = store.log
        let plan = Budget.plan()
        Section("Next") {
            if let next = log.nextSession(at: now) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(next.homeLabel(today: now.date)) \(plan.doorTime.display)")
                        .font(.title2.weight(.semibold))
                    Text(Budget.exitLine(for: plan))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            } else if let plannedBreak = log.currentOrUpcomingBreak(at: now) {
                let back = log.returnDay(after: plannedBreak, at: now) ?? plannedBreak.lastDay.adding(days: 1)
                Text("Back \(back.homeLabel(today: now.date)) \(plan.doorTime.display)")
                    .font(.title2.weight(.semibold))
                    .padding(.vertical, 4)
            } else {
                Text("Nothing planned yet.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Today's one-tap row. Shown only when today is a planned session with no
/// visit, or when today is already a visit.
struct TodaySection: View {
    let now: LocalMoment
    @Environment(HabitStore.self) private var store
    @State private var confirmingDidntGo = false

    var body: some View {
        let today = now.date
        switch store.log.state(of: today, at: now) {
        case .planned:
            Section("Today") {
                Button("Log today's visit") {
                    store.logVisit(on: today)
                }
                .font(.headline)
                Button("Hard day?") {
                    AppRouter.shared.hardDay = HardDayRequest(day: today, blocker: nil)
                }
            }
        case .done:
            Section("Today") {
                HStack {
                    Text("Done today.")
                    Spacer()
                    Button("Didn't go?") {
                        confirmingDidntGo = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .confirmationDialog("Didn't go today?", isPresented: $confirmingDidntGo, titleVisibility: .visible) {
                        Button("I didn't go") {
                            store.markDidntGo(on: today)
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This removes today's visit.")
                    }
                }
            }
        default:
            EmptyView()
        }
    }
}

/// "This week" and "Last 4 weeks", as plain counts.
struct CountsSection: View {
    let now: LocalMoment
    @Environment(HabitStore.self) private var store

    var body: some View {
        let log = store.log
        let week = log.week(containing: now.date, at: now)
        let tally = log.lastFourWeeks(at: now)
        Section {
            LabeledContent("This week", value: week.slots == 0 ? "On break" : "\(week.counted) of \(week.slots)")
            LabeledContent("Last 4 weeks", value: "\(tally.count) of \(tally.of)")
        }
    }
}
