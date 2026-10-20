import Foundation

/// A local calendar day, keyed as "yyyy-MM-dd".
///
/// Days are captured in local time when something happens and stored as this
/// key, so a later timezone change never moves an old visit to another day.
/// All arithmetic is on a day number (days since 1970-01-01), with no Calendar.
public struct LocalDate: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        // Normalize through the day number so out-of-range days roll over.
        let number = LocalDate.dayNumber(year: year, month: month, day: day)
        let civil = LocalDate.civil(fromDayNumber: number)
        self.year = civil.year
        self.month = civil.month
        self.day = civil.day
    }

    public init(dayNumber: Int) {
        let civil = LocalDate.civil(fromDayNumber: dayNumber)
        self.year = civil.year
        self.month = civil.month
        self.day = civil.day
    }

    /// Parses "yyyy-MM-dd". Returns nil for anything else.
    public init?(_ key: String) {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), (1...31).contains(d) else { return nil }
        let candidate = LocalDate(year: y, month: m, day: d)
        guard candidate.year == y, candidate.month == m, candidate.day == d else { return nil }
        self = candidate
    }

    /// The local day containing `date` in `timeZone`.
    public init(_ date: Date, in timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    public var key: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public var description: String { key }

    public var dayNumber: Int {
        LocalDate.dayNumber(year: year, month: month, day: day)
    }

    public func adding(days: Int) -> LocalDate {
        LocalDate(dayNumber: dayNumber + days)
    }

    /// Whole days from `self` to `other`; positive when `other` is later.
    public func days(to other: LocalDate) -> Int {
        other.dayNumber - dayNumber
    }

    public var weekday: Weekday {
        // 1970-01-01 was a Thursday.
        let index = ((dayNumber + 3) % 7 + 7) % 7
        return Weekday(rawValue: index + 1)!
    }

    /// The Monday that starts this day's Monday-to-Sunday week.
    public var weekStart: LocalDate {
        adding(days: -(weekday.rawValue - 1))
    }

    /// The day of `weekday` in this day's Monday-to-Sunday week.
    public func inSameWeek(_ weekday: Weekday) -> LocalDate {
        weekStart.adding(days: weekday.rawValue - 1)
    }

    /// Midnight at the start of this day in `timeZone`.
    public func startDate(in timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        lhs.dayNumber < rhs.dayNumber
    }

    // Howard Hinnant's days_from_civil / civil_from_days.
    static func dayNumber(year: Int, month: Int, day: Int) -> Int {
        // Fold month overflow into the year first.
        var y = year + (month - 1).floorDiv(12)
        let m = (month - 1).floorMod(12) + 1
        y -= m <= 2 ? 1 : 0
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (m > 2 ? m - 3 : m + 9) + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    static func civil(fromDayNumber number: Int) -> (year: Int, month: Int, day: Int) {
        let z = number + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        return (yoe + era * 400 + (m <= 2 ? 1 : 0), m, d)
    }
}

extension LocalDate: Codable, CodingKeyRepresentable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let key = try container.decode(String.self)
        guard let value = LocalDate(key) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a yyyy-MM-dd date: \(key)")
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(key)
    }

    public var codingKey: CodingKey { LocalDateCodingKey(stringValue: key) }

    public init?<T: CodingKey>(codingKey: T) {
        self.init(codingKey.stringValue)
    }
}

private struct LocalDateCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

public enum Weekday: Int, Codable, Sendable, CaseIterable, Comparable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    public var name: String {
        switch self {
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        case .sunday: "Sunday"
        }
    }

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A wall-clock time with minute precision.
public struct TimeOfDay: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let minutesSinceMidnight: Int

    public init(hour: Int, minute: Int = 0) {
        self.minutesSinceMidnight = hour * 60 + minute
    }

    public init(minutesSinceMidnight: Int) {
        self.minutesSinceMidnight = minutesSinceMidnight
    }

    public var hour: Int { minutesSinceMidnight / 60 }
    public var minute: Int { minutesSinceMidnight % 60 }

    public func adding(minutes: Int) -> TimeOfDay {
        TimeOfDay(minutesSinceMidnight: minutesSinceMidnight + minutes)
    }

    /// Minutes from `self` to `other`; positive when `other` is later.
    public func minutes(to other: TimeOfDay) -> Int {
        other.minutesSinceMidnight - minutesSinceMidnight
    }

    /// "7:45" in the morning, "8:00 pm" from noon on. Matches the plan's copy.
    public var display: String {
        let h12 = hour % 12 == 0 ? 12 : hour % 12
        let base = String(format: "%d:%02d", h12, minute)
        return hour >= 12 ? "\(base) pm" : base
    }

    public var description: String { display }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }
}

/// A local day plus a wall-clock time: "now" as HabitCore sees it.
public struct LocalMoment: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let date: LocalDate
    public let time: TimeOfDay

    public init(date: LocalDate, time: TimeOfDay) {
        self.date = date
        self.time = time
    }

    public init(_ instant: Date, in timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: instant)
        self.date = LocalDate(year: parts.year!, month: parts.month!, day: parts.day!)
        self.time = TimeOfDay(hour: parts.hour!, minute: parts.minute!)
    }

    /// Calendar components for a floating `UNCalendarNotificationTrigger`.
    public var dateComponents: DateComponents {
        DateComponents(year: date.year, month: date.month, day: date.day, hour: time.hour, minute: time.minute)
    }

    public var description: String { "\(date.key) \(String(format: "%02d:%02d", time.hour, time.minute))" }

    public static func < (lhs: LocalMoment, rhs: LocalMoment) -> Bool {
        (lhs.date, lhs.time.minutesSinceMidnight) < (rhs.date, rhs.time.minutesSinceMidnight)
    }

    /// True once `day` can no longer gain a visit on time: the next calendar
    /// day has reached the rollover hour. Before that the day is still open.
    public func hasClosed(_ day: LocalDate) -> Bool {
        self >= LocalMoment(date: day.adding(days: 1), time: Schedule.dayRolloverTime)
    }
}

private extension Int {
    func floorDiv(_ divisor: Int) -> Int {
        let q = self / divisor
        return (self % divisor != 0 && (self < 0) != (divisor < 0)) ? q - 1 : q
    }

    func floorMod(_ divisor: Int) -> Int {
        self - floorDiv(divisor) * divisor
    }
}
