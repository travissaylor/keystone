import SwiftData
import SwiftUI

@main
struct KeystoneApp: App {
    @Environment(\.scenePhase) private var scenePhase

    private let container: ModelContainer
    @State private var store: HabitStore
    @State private var workoutObserver: WorkoutObserver

    init() {
        // The main app process is the only one that syncs with CloudKit; the
        // factory itself falls back to local-only if CloudKit can't load.
        let container: ModelContainer
        do {
            container = try KeystoneStore.makeContainer(syncWithCloudKit: true)
        } catch {
            do {
                container = try KeystoneStore.makeContainer(syncWithCloudKit: false)
            } catch {
                fatalError("Failed to open the Keystone store: \(error)")
            }
        }
        self.container = container
        let store = HabitStore(context: container.mainContext)
        _store = State(initialValue: store)

        let workoutObserver = WorkoutObserver(store: store)
        _workoutObserver = State(initialValue: workoutObserver)

        // Services start here.
        workoutObserver.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            // Pick up anything a CloudKit merge or the widget wrote while the
            // app was in the background, and roll the day over if needed.
            if newPhase == .active {
                store.reload()
                workoutObserver.refresh()
            }
        }
    }
}
