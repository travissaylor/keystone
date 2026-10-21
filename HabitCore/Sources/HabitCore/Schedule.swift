/// Every constant the app runs on. There is no settings screen: to change the
/// plan, change this file. Values marked "measured" come from the trial week
/// and are starting points the phase 2 trip log will refine.
public enum Schedule {
    // MARK: Days

    /// The four planned weekdays.
    public static let plannedWeekdays: [Weekday] = [.monday, .tuesday, .wednesday, .thursday]

    /// Becomes the week's planned session when a planned weekday is missed or rested.
    public static let flexWeekday: Weekday = .friday

    /// Sessions per week unless the week's target is lowered.
    public static let defaultWeekTarget = 4

    /// A day becomes missed at this time on the next calendar day.
    public static let dayRolloverTime = TimeOfDay(hour: 4)

    // MARK: Morning times

    /// The cue. Out of the house at 7:45.
    public static let doorTime = TimeOfDay(hour: 7, minute: 45)

    /// The earliest the user will leave. Past this, traffic shrinks the session.
    public static let earliestDoorTime = TimeOfDay(hour: 7, minute: 30)

    /// The fixed go alert, five minutes before the door.
    public static let goAlertTime = TimeOfDay(hour: 7, minute: 40)

    /// The go alert fires this long before the door time.
    public static let goAlertLeadMinutes = 5

    /// Home by 9:30. The deadline everything works back from.
    public static let homeDeadline = TimeOfDay(hour: 9, minute: 30)

    // MARK: Trip budget (measured 2026-10-20)

    /// Garage exit, drive home and slack. 9:30 minus this is the latest gym exit.
    public static let outboundBaselineMinutes = 25

    /// Garage, walk and floor time between parking and the gym.
    public static let garageAndWalkInMinutes = 6

    /// Inbound drive used until a live estimate exists. Measured 32 with traffic.
    public static let defaultInboundDriveMinutes = 32

    /// Gym minutes, warm-up included, needed for each session size.
    public static let fullSessionMinutes = 40
    public static let shortSessionMinutes = 25
    public static let showUpSessionMinutes = 15

    // MARK: Notifications

    /// Night-before reminder, on the evening before each planned session.
    public static let prepReminderTime = TimeOfDay(hour: 20)

    /// "Did you go?" when no evidence has arrived.
    public static let nudgeTime = TimeOfDay(hour: 10)

    /// Recovery break review question, on the evening of the review date.
    public static let reviewQuestionTime = TimeOfDay(hour: 20)

    /// Days of single-shot requests kept queued ahead.
    public static let queueHorizonDays = 14

    // MARK: Evidence and breaks

    /// A Watch workout this long or longer is a visit.
    public static let minimumWorkoutMinutes = 10

    /// "One more week" on a recovery break moves the review date by this much.
    public static let recoveryReviewExtensionDays = 7

    // MARK: Words

    /// The user's own line about why he trains, shown on hard days.
    public static let reasonLine = "I love the process, and this morning is part of it."
}

/// What fits in the gym minutes available.
public enum SessionTemplate: String, Codable, Sendable, CaseIterable {
    case full
    case short
    case showUp
    case light

    public var title: String {
        switch self {
        case .full: "Full session"
        case .short: "Short session"
        case .showUp: "Show-up session"
        case .light: "Light day"
        }
    }

    public var detail: String {
        switch self {
        case .full: "Warm-up, then the full program."
        case .short: "Warm-up plus two lifts. Counts in full."
        case .showUp: "Warm-up and one lift, 15 minutes. Counts in full."
        case .light: "Same time, same lifts, lower load."
        }
    }
}

/// The known blockers, each with its if-then card.
public enum Blocker: String, Codable, Sendable, CaseIterable {
    case lateWake
    case travel
    case bodyOff
    case scheduleBlown
    case dontWantTo

    public var title: String {
        switch self {
        case .lateWake: "Woke up late"
        case .travel: "Traveling"
        case .bodyOff: "Body feels tight or off"
        case .scheduleBlown: "Schedule blown"
        case .dontWantTo: "Just don't want to"
        }
    }

    public var ifThen: String {
        switch self {
        case .lateWake:
            "If I wake up late, then I still leave at 7:45, warm up longer at the gym, and keep flexion lifts out of today."
        case .travel:
            "If I'm traveling, then I declare a travel break with a return date before I go."
        case .bodyOff:
            "If my body feels tight or off, then I go at 7:45 and do the light day: same lifts, lower load. If something hurts, it's a recovery break instead."
        case .scheduleBlown:
            "If the morning is blown, then I tap \"later today\" and go when it opens up. Any visit counts in full."
        case .dontWantTo:
            "If I just don't want to, then I only commit to the door at 7:45 and a 15-minute show-up. I can come home after that."
        }
    }

    /// The template the card points to, when it points to one.
    public var template: SessionTemplate? {
        switch self {
        case .lateWake, .dontWantTo: .showUp
        case .bodyOff: .light
        case .travel, .scheduleBlown: nil
        }
    }
}
