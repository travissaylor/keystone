import Foundation
import HabitCore

extension LocalDate {
    /// "Today", a weekday name within the coming week, otherwise "Monday, Nov 2".
    func homeLabel(today: LocalDate) -> String {
        let offset = today.days(to: self)
        if offset == 0 { return "Today" }
        if (1...6).contains(offset) { return weekday.name }
        return "\(weekday.name), \(Self.monthNames[month - 1]) \(day)"
    }

    /// "Tuesday, Oct 27", for review dates and anything further out.
    var weekdayAndDate: String {
        "\(weekday.name), \(Self.monthNames[month - 1]) \(day)"
    }

    private static let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
}

extension HabitLog {
    /// The latest day before today whose state is `.missed`, looking back at
    /// most 120 days. The day the morning-after card talks about.
    func latestMissedDay(at now: LocalMoment) -> LocalDate? {
        var day = now.date.adding(days: -1)
        for _ in 0..<120 where day >= firstDay {
            if state(of: day, at: now) == .missed { return day }
            day = day.adding(days: -1)
        }
        return nil
    }

    /// The break that covers today or starts later, latest-ending first.
    func currentOrUpcomingBreak(at now: LocalMoment) -> PlannedBreak? {
        breaks.filter { $0.lastDay >= now.date }.sorted { $0.lastDay > $1.lastDay }.first
    }
}

/// The re-entry plan the break sheet prefills, for a return on `weekday`.
func defaultReentryPlan(returning weekday: Weekday?) -> String {
    let day = weekday?.name ?? "my first day back"
    return "On \(day) at \(Schedule.doorTime.display) I leave for a 15-minute show-up session."
}
