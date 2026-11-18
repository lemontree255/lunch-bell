import Foundation

struct LunchSchedule {
    var hour: Int
    var minute: Int

    func isWeekday(_ date: Date, calendar: Calendar = .current) -> Bool {
        (2...6).contains(calendar.component(.weekday, from: date))
    }

    func scheduledTime(on day: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    func isDue(now: Date, handled: Date?, snoozedUntil: Date?, calendar: Calendar = .current) -> Bool {
        guard isWeekday(now, calendar: calendar) else { return false }
        if let snoozedUntil { return now >= snoozedUntil }
        if let handled, calendar.isDate(handled, inSameDayAs: now) { return false }
        let scheduled = scheduledTime(on: now, calendar: calendar)
        // shortcut: catch up until 15:00 or one hour after a later lunch; revisit for shift-work schedules.
        let cutoff = max(calendar.date(bySettingHour: 15, minute: 0, second: 0, of: now)!,
                         scheduled.addingTimeInterval(60 * 60))
        return now >= scheduled && now < cutoff
    }
}
