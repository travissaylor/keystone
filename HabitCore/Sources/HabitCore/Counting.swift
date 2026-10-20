/// What one day is, as the counting contract sees it at a given moment.
public enum DayState: Equatable, Sendable {
    /// Not a planned session and no visit: a weekend, an inactive Friday, a
    /// day before the first window, or a day after the week's target was met.
    case notPlanned
    /// A planned session with no visit that is still open (today or later).
    case planned
    /// A visit. Takes precedence over every other state.
    case done
    /// A planned session that reached rollover with no visit.
    case missed
    /// Declared rest, no visit.
    case rest
    /// Inside a break, no visit.
    case onBreak
}

/// One Monday-to-Sunday week, counted.
public struct WeekSummary: Equatable, Sendable {
    public let weekStart: LocalDate
    public let target: Int
    /// Monday-to-Thursday days the week can offer once breaks and rests are
    /// taken out, plus the flex day when it is active.
    public let capacity: Int
    /// The most visits the week can ask for: `min(target, capacity)`.
    public let slots: Int
    /// Visit days in the week up to and including today, any weekday.
    public let visits: Int
    /// Visits counted toward the week: `min(visits, target)`.
    public let counted: Int
    /// Missed planned sessions in the week so far.
    public let misses: Int
    public let isFlexActive: Bool

    /// A week with no slots (all on break) is neither hit nor missed.
    public var isHit: Bool { slots > 0 && counted >= slots }
}

/// "count of of", as in "15 of 16".
public struct Tally: Equatable, Sendable {
    public let count: Int
    public let of: Int

    public init(count: Int, of: Int) {
        self.count = count
        self.of = of
    }
}

/// Where the user stands today. Derived, never stored.
public enum Standing: Equatable, Sendable {
    case onPlan
    case missed(inARow: Int)
    case onBreak(PlannedBreak)
    /// Today is the first visit after one or more misses or a break.
    case comeback
}

extension HabitLog {
    /// Precedence: visit, break, rest, planned session (missed once closed),
    /// otherwise not planned.
    public func state(of day: LocalDate, at now: LocalMoment) -> DayState {
        if isVisit(day) { return .done }
        if isOnBreak(day) { return .onBreak }
        if rests.contains(day) { return .rest }
        if isPlannedSession(day, at: now) {
            return now.hasClosed(day) ? .missed : .planned
        }
        return .notPlanned
    }

    /// True for every planned session, whether it ends up planned, done or
    /// missed. A visit on the day itself does not stop it being planned.
    public func isPlannedSession(_ day: LocalDate, at now: LocalMoment) -> Bool {
        guard isCountable(day), !rests.contains(day) else { return false }
        if day.weekday == Schedule.flexWeekday {
            return isFlexActive(inWeekOf: day, at: now)
        }
        guard Schedule.plannedWeekdays.contains(day.weekday) else { return false }
        let earlierVisits = days(from: day.weekStart, to: day).filter(isVisit).count
        return earlierVisits < weekTarget(for: day)
    }

    /// Friday becomes the week's planned session when a Monday-to-Thursday
    /// session was missed or rested and the week's Monday-to-Thursday visits
    /// are below target. Break days never turn it on.
    public func isFlexActive(inWeekOf day: LocalDate, at now: LocalMoment) -> Bool {
        let friday = day.inSameWeek(Schedule.flexWeekday)
        guard isCountable(friday), !rests.contains(friday) else { return false }
        let plannedDays = plannedWeekdayDays(inWeekOf: day)
        let triggered = plannedDays.contains { d in
            guard isCountable(d) else { return false }
            if rests.contains(d) { return true }
            return isPlannedSession(d, at: now) && !isVisit(d) && now.hasClosed(d)
        }
        let visits = plannedDays.filter(isVisit).count
        return triggered && visits < weekTarget(for: day)
    }

    /// The week's Friday while it is an open flex day with no visit yet:
    /// "Friday's open".
    public func flexDay(inWeekOf day: LocalDate, at now: LocalMoment) -> LocalDate? {
        let friday = day.inSameWeek(Schedule.flexWeekday)
        guard isFlexActive(inWeekOf: day, at: now), state(of: friday, at: now) == .planned else { return nil }
        return friday
    }

    public func week(containing day: LocalDate, at now: LocalMoment) -> WeekSummary {
        let start = day.weekStart
        let target = weekTarget(for: start)
        let flex = isFlexActive(inWeekOf: start, at: now)
        let open = plannedWeekdayDays(inWeekOf: start).filter { isCountable($0) && !rests.contains($0) }.count
        let capacity = open + (flex ? 1 : 0)
        let weekDays = days(from: start, to: start.adding(days: 7))
        let visits = weekDays.filter { $0 <= now.date && isVisit($0) }.count
        let misses = weekDays.filter { state(of: $0, at: now) == .missed }.count
        return WeekSummary(
            weekStart: start,
            target: target,
            capacity: capacity,
            slots: min(target, capacity),
            visits: visits,
            counted: min(visits, target),
            misses: misses,
            isFlexActive: flex
        )
    }

    /// The current week and the three before it. Each week counts at most its
    /// target, and its denominator is the planned sessions whose day has ended
    /// (plus today if visited), so breaks, rests and lowered targets shrink it.
    public func lastFourWeeks(at now: LocalMoment) -> Tally {
        var count = 0
        var of = 0
        for back in 0..<4 {
            let start = now.date.weekStart.adding(days: -7 * back)
            guard start >= firstDay.weekStart else { continue }
            let week = week(containing: start, at: now)
            count += week.counted
            of += max(week.counted, min(week.slots, week.visits + week.misses))
        }
        return Tally(count: count, of: of)
    }

    /// Consecutive misses counted back from the latest closed day. A visit or
    /// a break day ends the run; weekends, rests and unplanned days are skipped.
    public func missedInARow(at now: LocalMoment) -> Int {
        var day = latestClosedDay(at: now)
        var run = 0
        while day >= firstDay {
            if isVisit(day) || isOnBreak(day) { break }
            if state(of: day, at: now) == .missed { run += 1 }
            day = day.adding(days: -1)
        }
        return run
    }

    public func standing(at now: LocalMoment) -> Standing {
        let today = now.date
        if !isVisit(today), let current = breaks(containing: today).first {
            return .onBreak(current)
        }
        if isVisit(today), followsMissOrBreak(today, at: now) {
            return .comeback
        }
        let run = missedInARow(at: now)
        return run > 0 ? .missed(inARow: run) : .onPlan
    }

    /// The next open planned session. Today qualifies only before the home
    /// deadline. Looks at most 120 days ahead.
    public func nextSession(at now: LocalMoment) -> LocalDate? {
        for offset in 0...120 {
            if offset == 0 && now.time >= Schedule.homeDeadline { continue }
            let day = now.date.adding(days: offset)
            if state(of: day, at: now) == .planned { return day }
        }
        return nil
    }

    /// The first planned session after the break's last day. Planned sessions
    /// never fall inside a break, so overlapping breaks merge on their own.
    public func returnDay(after plannedBreak: PlannedBreak, at now: LocalMoment) -> LocalDate? {
        for offset in 1...120 {
            let day = plannedBreak.lastDay.adding(days: offset)
            if isPlannedSession(day, at: now) { return day }
        }
        return nil
    }

    // MARK: Helpers

    /// On or after the first day and outside every break.
    private func isCountable(_ day: LocalDate) -> Bool {
        day >= firstDay && !isOnBreak(day)
    }

    /// Days from `start` up to but not including `end`.
    private func days(from start: LocalDate, to end: LocalDate) -> [LocalDate] {
        (0..<max(0, start.days(to: end))).map { start.adding(days: $0) }
    }

    /// Monday to Thursday of the week containing `day`.
    private func plannedWeekdayDays(inWeekOf day: LocalDate) -> [LocalDate] {
        Schedule.plannedWeekdays.map { day.inSameWeek($0) }
    }

    /// Yesterday once rollover has passed, otherwise the day before.
    private func latestClosedDay(at now: LocalMoment) -> LocalDate {
        let yesterday = now.date.adding(days: -1)
        return now.hasClosed(yesterday) ? yesterday : yesterday.adding(days: -1)
    }

    /// Walking back from the day before `day`, skipping days that decide
    /// nothing: true when the first visit, miss or break day found is a miss
    /// or a break day.
    private func followsMissOrBreak(_ day: LocalDate, at now: LocalMoment) -> Bool {
        var earlier = day.adding(days: -1)
        while earlier >= firstDay {
            if isVisit(earlier) { return false }
            if isOnBreak(earlier) { return true }
            if state(of: earlier, at: now) == .missed { return true }
            earlier = earlier.adding(days: -1)
        }
        return false
    }
}
