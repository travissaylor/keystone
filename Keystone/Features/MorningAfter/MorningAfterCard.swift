import HabitCore
import SwiftUI

/// Shown at the top of the home screen after a miss. Exactly three things:
/// what happened (with an optional one-tap reason), why it doesn't matter
/// much, and the two session sizes that both count. About the situation,
/// never about character.
struct MorningAfterCard: View {
    let now: LocalMoment
    let missedInARow: Int
    @Environment(HabitStore.self) private var store

    var body: some View {
        let log = store.log
        let today = now.date
        let missedDay = log.latestMissedDay(at: now)
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text(headline(missedDay: missedDay, today: today))
                    .font(.headline)
                if let missedDay {
                    ReasonChips(selected: log.missReasons[missedDay]) { reason in
                        store.setMissReason(reason, on: missedDay)
                    }
                }
            }
            .padding(.vertical, 4)

            Text(reassurance(flexOpen: log.flexDay(inWeekOf: today, at: now) != nil))

            VStack(spacing: 8) {
                HStack {
                    Text("Full session")
                        .frame(maxWidth: .infinity)
                    Divider()
                    Text("15-minute show-up")
                        .frame(maxWidth: .infinity)
                }
                .font(.subheadline.weight(.semibold))
                Text("Both count the same.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            if missedInARow >= 2 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Need a break? Set a return date.")
                    Button("Take a break") {
                        AppRouter.shared.showBreakSheet = true
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func headline(missedDay: LocalDate?, today: LocalDate) -> String {
        guard let missedDay, missedDay != today.adding(days: -1) else {
            return "Yesterday didn't happen."
        }
        return "\(missedDay.weekday.name) didn't happen."
    }

    private func reassurance(flexOpen: Bool) -> String {
        let line = "One miss doesn't move the needle. The next session is the one that counts."
        return flexOpen ? "\(line) Friday's open." : line
    }
}

/// The optional reason row. Tapping the selected chip clears it.
private struct ReasonChips: View {
    let selected: MissReason?
    let choose: (MissReason?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MissReason.allCases, id: \.self) { reason in
                    chip(reason)
                }
            }
        }
        .scrollClipDisabled()
    }

    @ViewBuilder
    private func chip(_ reason: MissReason) -> some View {
        let isSelected = reason == selected
        let button = Button(reason.label) {
            choose(isSelected ? nil : reason)
        }
        .controlSize(.small)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        if isSelected {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }
}
