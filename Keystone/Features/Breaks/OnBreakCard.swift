import HabitCore
import SwiftUI

/// Shown while a break covers today. Never a miss, no nudging copy. On a
/// recovery break's review date it asks the review question in-app.
struct OnBreakCard: View {
    let plannedBreak: PlannedBreak
    let now: LocalMoment
    @Environment(HabitStore.self) private var store
    /// "Back" changes nothing stored; this only hides the question once answered.
    @State private var answeredBack = false

    var body: some View {
        let today = now.date
        Section {
            switch plannedBreak.kind {
            case .travel:
                Text("Travel break. Back \(returnLabel(today: today)).")
                    .font(.headline)
                if let plan = plannedBreak.reentryPlan, !plan.isEmpty {
                    Text("“\(plan)”")
                        .italic()
                        .foregroundStyle(.secondary)
                }
                endButton(today: today)
            case .recovery:
                Text("Recovery break. Review \(plannedBreak.lastDay.weekdayAndDate).")
                    .font(.headline)
                if let plan = plannedBreak.reentryPlan, !plan.isEmpty {
                    Text("“\(plan)”")
                        .italic()
                        .foregroundStyle(.secondary)
                }
                if today == plannedBreak.lastDay {
                    reviewQuestion(today: today)
                } else {
                    endButton(today: today)
                }
            }
        }
    }

    @ViewBuilder
    private func reviewQuestion(today: LocalDate) -> some View {
        if answeredBack {
            Text("Back \(returnLabel(today: today)).")
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Back tomorrow, or one more week?")
                HStack {
                    Button("Back") {
                        answeredBack = true
                    }
                    .buttonStyle(.borderedProminent)
                    Button("One more week") {
                        var extended = plannedBreak
                        extended.lastDay = plannedBreak.lastDay.adding(days: Schedule.recoveryReviewExtensionDays)
                        store.updateBreak(extended)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 4)
        }
    }

    /// Ends the break yesterday, or removes it if it only started today.
    private func endButton(today: LocalDate) -> some View {
        Button("End break now") {
            if plannedBreak.firstDay >= today {
                store.removeBreak(id: plannedBreak.id)
            } else {
                var ended = plannedBreak
                ended.lastDay = today.adding(days: -1)
                store.updateBreak(ended)
            }
        }
    }

    /// "Monday 7:45": the first planned session after the break.
    private func returnLabel(today: LocalDate) -> String {
        let back = store.log.returnDay(after: plannedBreak, at: now) ?? plannedBreak.lastDay.adding(days: 1)
        return "\(back.homeLabel(today: today)) \(Schedule.doorTime.display)"
    }
}
