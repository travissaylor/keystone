import HabitCore
import SwiftUI

/// The hard-day sheet. In order: the show-up version, the if-then cards (the
/// named blocker first and open), the user's own reason, and a rest that
/// needs no reason. The app never decides whether a body can train.
struct HardDayView: View {
    let request: HardDayRequest
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var expanded: Set<Blocker>

    init(request: HardDayRequest) {
        self.request = request
        _expanded = State(initialValue: request.blocker.map { [$0] } ?? [])
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Show up") {
                    Text("Leave at \(Schedule.doorTime.display), do 15 minutes, come home early. Counts in full.")
                }

                Section("If-then") {
                    ForEach(orderedBlockers, id: \.self) { blocker in
                        DisclosureGroup(blocker.title, isExpanded: isExpanded(blocker)) {
                            BlockerCard(blocker: blocker)
                        }
                    }
                }

                Section("Why I train") {
                    Text(Schedule.reasonLine)
                }

                Section {
                    Button("Rest today") {
                        store.declareRest(on: request.day)
                        dismiss()
                    }
                } footer: {
                    Text("A declared rest, not a miss.")
                }
            }
            .navigationTitle("Hard day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    /// The named blocker first, then the rest in their usual order.
    private var orderedBlockers: [Blocker] {
        guard let first = request.blocker else { return Blocker.allCases }
        return [first] + Blocker.allCases.filter { $0 != first }
    }

    private func isExpanded(_ blocker: Blocker) -> Binding<Bool> {
        Binding(
            get: { expanded.contains(blocker) },
            set: { isOpen in
                if isOpen { expanded.insert(blocker) } else { expanded.remove(blocker) }
            }
        )
    }
}

/// One if-then card: the plan, and the session it points to when it points to one.
private struct BlockerCard: View {
    let blocker: Blocker

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(blocker.ifThen)
            if let template = blocker.template {
                Text("\(template.title): \(template.detail)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
