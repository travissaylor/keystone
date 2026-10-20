import SwiftData
import SwiftUI

/// Placeholder for the one screen. A later unit replaces it.
struct RootView: View {
    var body: some View {
        NavigationStack {
            Text("Keystone")
        }
    }
}

#Preview {
    RootView()
        .environment(HabitStore(context: KeystoneStore.makeInMemoryContainer().mainContext))
}
