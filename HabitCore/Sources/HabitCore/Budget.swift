/// Whether a trip leaves room for a session, and which one.
public enum SessionFit: Equatable, Sendable {
    case fits(SessionTemplate)
    case doesntFit
}

/// One morning's trip, worked back from the 9:30 deadline.
public struct TripPlan: Equatable, Sendable {
    /// When to be out the door.
    public let doorTime: TimeOfDay
    /// When the go alert fires. Nil once the departure is already past.
    public let goAlertTime: TimeOfDay?
    public let inboundDriveMinutes: Int
    public let gymArrival: TimeOfDay
    public let latestGymExit: TimeOfDay
    public let gymMinutes: Int
    public let fit: SessionFit
    /// The door is earlier than the usual 7:45.
    public let leavesEarly: Bool
    /// The door is pinned at the 7:30 floor and the session is still short of full.
    public let floorHit: Bool
}

/// The budget: working back from the 9:30 deadline to the minutes in the gym.
public enum Budget {
    /// The latest the user can leave the gym: 9:30 minus the outbound baseline.
    public static var latestGymExit: TimeOfDay {
        Schedule.homeDeadline.adding(minutes: -Schedule.outboundBaselineMinutes)
    }

    /// When the user walks onto the gym floor.
    public static func gymArrival(door: TimeOfDay, inboundDriveMinutes: Int) -> TimeOfDay {
        door.adding(minutes: inboundDriveMinutes + Schedule.garageAndWalkInMinutes)
    }

    /// Minutes between arriving and the latest gym exit. Negative when late.
    public static func gymMinutes(door: TimeOfDay, inboundDriveMinutes: Int) -> Int {
        gymArrival(door: door, inboundDriveMinutes: inboundDriveMinutes).minutes(to: latestGymExit)
    }

    /// The session that fits in `gymMinutes`, warm-up included.
    public static func fit(gymMinutes: Int) -> SessionFit {
        if gymMinutes >= Schedule.fullSessionMinutes { return .fits(.full) }
        if gymMinutes >= Schedule.shortSessionMinutes { return .fits(.short) }
        if gymMinutes >= Schedule.showUpSessionMinutes { return .fits(.showUp) }
        return .doesntFit
    }

    /// The plan for today's trip.
    ///
    /// The door stays 7:45 while it gives a full session. Otherwise it moves
    /// earlier by the deficit, rounded down to a 5-minute mark and held between
    /// the 7:30 floor and 7:45. If `now` is already past that door, the door
    /// becomes `now` and there is no go alert.
    public static func plan(
        inboundDriveMinutes: Int = Schedule.defaultInboundDriveMinutes,
        now: TimeOfDay? = nil
    ) -> TripPlan {
        var door = Schedule.doorTime
        let usual = gymMinutes(door: door, inboundDriveMinutes: inboundDriveMinutes)
        if usual < Schedule.fullSessionMinutes {
            let deficit = Schedule.fullSessionMinutes - usual
            let raw = door.minutesSinceMidnight - deficit
            let rounded = raw - ((raw % 5) + 5) % 5
            door = TimeOfDay(minutesSinceMidnight: min(
                max(rounded, Schedule.earliestDoorTime.minutesSinceMidnight),
                Schedule.doorTime.minutesSinceMidnight
            ))
        }

        var goAlert: TimeOfDay? = TimeOfDay(minutesSinceMidnight: min(
            max(door.minutesSinceMidnight - Schedule.goAlertLeadMinutes,
                Schedule.earliestDoorTime.minutesSinceMidnight),
            Schedule.goAlertTime.minutesSinceMidnight
        ))
        if let now, now > door {
            door = now
            goAlert = nil
        }

        let minutes = gymMinutes(door: door, inboundDriveMinutes: inboundDriveMinutes)
        let sessionFit = fit(gymMinutes: minutes)
        return TripPlan(
            doorTime: door,
            goAlertTime: goAlert,
            inboundDriveMinutes: inboundDriveMinutes,
            gymArrival: gymArrival(door: door, inboundDriveMinutes: inboundDriveMinutes),
            latestGymExit: latestGymExit,
            gymMinutes: minutes,
            fit: sessionFit,
            leavesEarly: door < Schedule.doorTime,
            floorHit: door == Schedule.earliestDoorTime && sessionFit != .fits(.full)
        )
    }

    /// The go alert's text for `plan`.
    public static func goAlertBody(for plan: TripPlan) -> String {
        let lead = "Out the door \(plan.doorTime.display). Drive \(plan.inboundDriveMinutes), gym \(plan.gymArrival.display). Leave the gym by \(plan.latestGymExit.display)."
        switch plan.fit {
        case .fits(.full): return "\(lead) Full session."
        case .fits(.short): return "\(lead) Short session, warm-up plus two lifts."
        case .fits(.showUp): return "\(lead) Show-up session, 15 minutes. Counts in full."
        case .fits(.light): return "\(lead) Light day."
        case .doesntFit: return "Today's trip doesn't fit before \(Schedule.homeDeadline.display). Later today counts in full."
        }
    }

    /// One line for the home screen, such as "Leave the gym by 9:05".
    public static func exitLine(for plan: TripPlan) -> String {
        "Leave the gym by \(plan.latestGymExit.display)"
    }
}
