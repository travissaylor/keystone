import Foundation
import Testing
@testable import HabitCore

@Suite("LocalDate")
struct LocalDateTests {
    @Test func parsesAndFormatsKeys() {
        let day = LocalDate("2026-10-21")
        #expect(day == LocalDate(year: 2026, month: 10, day: 21))
        #expect(day?.key == "2026-10-21")
        #expect(LocalDate("2026-02-30") == nil)
        #expect(LocalDate("2026-10-1") == nil)
    }

    @Test func knowsWeekdays() {
        #expect(LocalDate("2026-10-19")!.weekday == .monday)
        #expect(LocalDate("2026-10-22")!.weekday == .thursday)
        #expect(LocalDate("2026-10-25")!.weekday == .sunday)
        #expect(LocalDate("2026-10-25")!.weekStart == LocalDate("2026-10-19"))
        #expect(LocalDate("2026-10-21")!.inSameWeek(.friday) == LocalDate("2026-10-23"))
    }

    @Test func addsAcrossMonthsAndYears() {
        #expect(LocalDate("2026-12-31")!.adding(days: 1) == LocalDate("2027-01-01"))
        #expect(LocalDate("2028-03-01")!.adding(days: -1) == LocalDate("2028-02-29"))
        #expect(LocalDate("2026-10-19")!.days(to: LocalDate("2026-11-02")!) == 14)
    }

    @Test func roundTripsAsJSONDictionaryKeys() throws {
        let map: [LocalDate: Int] = [LocalDate("2026-10-19")!: 3]
        let data = try JSONEncoder().encode(map)
        #expect(String(decoding: data, as: UTF8.self) == #"{"2026-10-19":3}"#)
        #expect(try JSONDecoder().decode([LocalDate: Int].self, from: data) == map)
    }

    @Test func aDayClosesAtFourTheNextMorning() {
        let tuesday = LocalDate("2026-10-20")!
        let wednesday = tuesday.adding(days: 1)
        #expect(!LocalMoment(date: tuesday, time: TimeOfDay(hour: 23, minute: 59)).hasClosed(tuesday))
        #expect(!LocalMoment(date: wednesday, time: TimeOfDay(hour: 3, minute: 59)).hasClosed(tuesday))
        #expect(LocalMoment(date: wednesday, time: TimeOfDay(hour: 4)).hasClosed(tuesday))
    }

    @Test func displaysTimesLikeThePlan() {
        #expect(TimeOfDay(hour: 7, minute: 45).display == "7:45")
        #expect(TimeOfDay(hour: 20).display == "8:00 pm")
    }

    @Test func keepsTheDayItWasRecordedIn() {
        // 23:30 in Pittsburgh is already the next day in UTC; the stored key is local.
        let instant = ISO8601DateFormatter().date(from: "2026-10-21T03:30:00Z")!
        #expect(LocalDate(instant, in: TimeZone(identifier: "America/New_York")!) == LocalDate("2026-10-20"))
        #expect(LocalDate(instant, in: TimeZone(identifier: "UTC")!) == LocalDate("2026-10-21"))
    }
}
