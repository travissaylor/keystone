import Foundation
import HabitCore
import Observation

/// A request to open the hard-day sheet for `day`, optionally with the
/// blocker the user already named (from a notification action).
struct HardDayRequest: Identifiable, Equatable {
    let id = UUID()
    let day: LocalDate
    let blocker: Blocker?
}

/// Which sheet the home screen shows. Notification actions set these from
/// outside the view tree; `RootView` presents them.
@Observable
@MainActor
final class AppRouter {
    static let shared = AppRouter()

    /// Opens the hard-day sheet while non-nil.
    var hardDay: HardDayRequest?

    /// Opens the break sheet while true.
    var showBreakSheet = false
}
