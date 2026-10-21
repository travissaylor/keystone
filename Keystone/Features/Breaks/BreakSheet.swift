import Foundation
import HabitCore
import SwiftUI

/// Declares a travel or recovery break starting today. A travel break ends on
/// a chosen last day; a recovery break ends on a review date. Either way its
/// days leave every denominator.
struct BreakSheet: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var kind: PlannedBreak.Kind = .travel
    @State private var lastDayAway: Date?
    @State private var reviewDate: Date?
    /// Off by default: nobody ready on Tuesday should have to wait.
    @State private var makeItAMonday = false
    /// Nil until the user edits the prefilled re-entry plan.
    @State private var editedPlan: String?

    var body: some View {
        let today = store.today()
        let draft = draftBreak(today: today)
        let back = store.log.returnDay(after: draft, at: store.now())
        NavigationStack {
            Form {
                Section {
                    Picker("Kind", selection: $kind) {
                        Text("Travel").tag(PlannedBreak.Kind.travel)
                        Text("Recovery").tag(PlannedBreak.Kind.recovery)
                    }
                    .pickerStyle(.segmented)
                }

                switch kind {
                case .travel:
                    Section {
                        DatePicker("Last day away", selection: dateBinding($lastDayAway, default: today), in: start(today)..., displayedComponents: .date)
                        Toggle("Make it a Monday", isOn: $makeItAMonday)
                        if let back {
                            LabeledContent("Back", value: "\(back.homeLabel(today: today)) \(Schedule.doorTime.display)")
                        }
                    }
                case .recovery:
                    Section {
                        DatePicker("Review date", selection: dateBinding($reviewDate, default: today.adding(days: 7)), in: start(today)..., displayedComponents: .date)
                    } footer: {
                        Text("No penalty and no nudges. On the review date you'll be asked: back, or one more week.")
                    }
                }

                Section {
                    TextField("Re-entry plan", text: planBinding(back: back), axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text(kind == .travel ? "Re-entry plan" : "Re-entry plan (optional)")
                } footer: {
                    Text("No notifications until then.")
                }
            }
            .environment(\.timeZone, store.timeZone)
            .navigationTitle("Take a break")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var plannedBreak = draft
                        plannedBreak.reentryPlan = trimmedPlan(back: back)
                        store.declareBreak(plannedBreak)
                        dismiss()
                    }
                    .disabled(kind == .travel && trimmedPlan(back: back) == nil)
                }
            }
        }
    }

    // MARK: Draft

    /// The break as it would be saved, without its re-entry plan.
    private func draftBreak(today: LocalDate) -> PlannedBreak {
        let lastDay: LocalDate
        switch kind {
        case .travel:
            let away = localDate(lastDayAway) ?? today
            // The Sunday before the following Monday, so the return is a Monday.
            lastDay = makeItAMonday ? away.inSameWeek(.sunday) : away
        case .recovery:
            lastDay = localDate(reviewDate) ?? today.adding(days: 7)
        }
        return PlannedBreak(kind: kind, firstDay: today, lastDay: max(lastDay, today))
    }

    private func trimmedPlan(back: LocalDate?) -> String? {
        let text = (editedPlan ?? defaultReentryPlan(returning: back?.weekday))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    // MARK: Bindings

    /// Follows the return day until the user types, then keeps their words.
    private func planBinding(back: LocalDate?) -> Binding<String> {
        Binding(
            get: { editedPlan ?? defaultReentryPlan(returning: back?.weekday) },
            set: { editedPlan = $0 }
        )
    }

    private func dateBinding(_ value: Binding<Date?>, default fallback: LocalDate) -> Binding<Date> {
        let timeZone = store.timeZone
        return Binding(
            get: { value.wrappedValue ?? fallback.startDate(in: timeZone) },
            set: { value.wrappedValue = $0 }
        )
    }

    private func start(_ day: LocalDate) -> Date {
        day.startDate(in: store.timeZone)
    }

    private func localDate(_ date: Date?) -> LocalDate? {
        date.map { LocalDate($0, in: store.timeZone) }
    }
}
