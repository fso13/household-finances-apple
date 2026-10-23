import Foundation

package extension Date {
    package var calendar: Calendar { .current }

    package var startOfDay: Date { calendar.startOfDay(for: self) }

    package var startOfMonth: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: self)) ?? self
    }

    package var startOfQuarter: Date {
        let month = calendar.component(.month, from: self)
        let quarterStartMonth = ((month - 1) / 3) * 3 + 1
        var components = calendar.dateComponents([.year], from: self)
        components.month = quarterStartMonth
        components.day = 1
        return calendar.date(from: components) ?? self
    }

    package var startOfYear: Date {
        let components = calendar.dateComponents([.year], from: self)
        return calendar.date(from: components) ?? self
    }

    package var year: Int { calendar.component(.year, from: self) }

    package var month: Int { calendar.component(.month, from: self) }

    package var day: Int { calendar.component(.day, from: self) }

    package var quarter: Int { ((month - 1) / 3) + 1 }

    package func addingMonths(_ value: Int) -> Date {
        calendar.date(byAdding: .month, value: value, to: self) ?? self
    }

    package func addingDays(_ value: Int) -> Date {
        calendar.date(byAdding: .day, value: value, to: self) ?? self
    }

    package func isSameMonth(as other: Date) -> Bool {
        calendar.isDate(self, equalTo: other, toGranularity: .month)
    }

    package func isSameYear(as other: Date) -> Bool {
        calendar.isDate(self, equalTo: other, toGranularity: .year)
    }

    package static func make(year: Int, month: Int, day: Int = 1) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components) ?? Date()
    }

    /// Ближайшая дата платежа: та же дата, что у старта, но не раньше `now`.
    /// `now` передаётся явно, чтобы расчёт был детерминированным в тестах.
    package func nextOccurrence(
        everyMonths months: Int,
        from start: Date,
        relativeTo now: Date = Date()
    ) -> Date {
        guard months > 0 else { return start }
        let today = now.startOfDay
        var occurrence = start.startOfDay
        var guardCounter = 0
        while occurrence < today && guardCounter < 1000 {
            occurrence = occurrence.addingMonths(months)
            guardCounter += 1
        }
        return occurrence
    }
}

package enum MonthFormat {
    package static let ruLocale = Locale(identifier: "ru_RU")

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = ruLocale
        formatter.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        return formatter
    }()

    private static let shortMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = ruLocale
        formatter.setLocalizedDateFormatFromTemplate("LLL")
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = ruLocale
        formatter.setLocalizedDateFormatFromTemplate("d MMM yyyy")
        return formatter
    }()

    private static let compactDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = ruLocale
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter
    }()

    package static func monthTitle(_ date: Date) -> String {
        monthYearFormatter.string(from: date).capitalizedFirst
    }

    package static func shortMonth(_ date: Date) -> String {
        shortMonthFormatter.string(from: date).replacingOccurrences(of: ".", with: "")
    }

    package static func day(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    package static func shortMonthWithYear(_ date: Date) -> String {
        "\(shortMonth(date)) \(String(format: "%02d", date.year % 100))"
    }

    package static func compactDay(_ date: Date) -> String {
        compactDayFormatter.string(from: date)
    }

    package static func quarterTitle(year: Int, quarter: Int) -> String {
        "\(romanQuarter(quarter)) кв. \(year)"
    }

    package static func romanQuarter(_ quarter: Int) -> String {
        switch quarter {
        case 1: "I"
        case 2: "II"
        case 3: "III"
        case 4: "IV"
        default: "?"
        }
    }
}

private extension String {
    package var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
