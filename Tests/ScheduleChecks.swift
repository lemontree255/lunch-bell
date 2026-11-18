import Foundation

@main
struct ScheduleChecks {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Copenhagen")!
        func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
        let schedule = LunchSchedule(hour: 11, minute: 21)
        var checks = 0
        func check(_ timestamp: String, _ expected: Bool, handled: Date? = nil,
                   snoozedUntil: Date? = nil, using schedule: LunchSchedule = LunchSchedule(hour: 11, minute: 21)) {
            precondition(schedule.isDue(now: date(timestamp), handled: handled,
                                       snoozedUntil: snoozedUntil, calendar: calendar) == expected, timestamp)
            checks += 1
        }
        // Exact boundary and catching a missed lunch after waking.
        check("2026-11-18T10:20:59Z", false)
        check("2026-11-18T10:21:00Z", true)
        check("2026-11-18T12:00:00Z", true)
        check("2026-11-18T14:00:00Z", false)
        check("2026-11-18T22:00:00Z", false)
        // Acknowledgement lasts only for the local calendar day.
        let handled = date("2026-11-18T10:21:00Z")
        check("2026-11-18T10:26:00Z", false, handled: handled)
        check("2026-11-19T10:21:00Z", true, handled: handled)
        // An explicit snooze can extend beyond the automatic catch-up cutoff.
        let snooze = date("2026-11-18T14:05:00Z")
        check("2026-11-18T14:04:59Z", false, snoozedUntil: snooze)
        check("2026-11-18T14:05:00Z", true, snoozedUntil: snooze)
        // Configurable late lunch and daylight-saving time.
        let late = LunchSchedule(hour: 16, minute: 30)
        check("2026-11-18T15:30:00Z", true, using: late)
        check("2026-11-18T16:30:00Z", false, using: late)
        check("2026-03-29T09:21:00Z", true)
        check("2026-03-29T09:20:59Z", false)
        check("2026-10-25T10:21:00Z", true)
        precondition(calendar.component(.hour, from: schedule.scheduledTime(on: handled, calendar: calendar)) == 11)
        print("Passed \(checks + 1) schedule checks")
    }
}
