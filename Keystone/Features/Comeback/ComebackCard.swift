import SwiftUI

/// The first visit after a miss or a break: the warmest moment in the app.
/// One line and a subline. No confetti, no points.
struct ComebackCard: View {
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("You're back.")
                    .font(.title3.weight(.semibold))
                Text("This is the session that counts most.")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        }
    }
}
