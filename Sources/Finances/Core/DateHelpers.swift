import Foundation

extension Date {
    var calendar: Calendar { .current }

    var startOfDay: Date { calendar.startOfDay(for: self) }

    var startOfMonth: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: self)) ?? self
    }

    var startOfQuarter: Date {
        let month = calendar.component(.month, from: self)
        let quarterStartMonth = ((month - 1) / 3) * 3 + 1
        var components = calendar.dateComponents([.year], from: self)
        components.month = quarterStartMonth
        components.day = 1
        return calendar.date(from: components) ?? self
    }

    var startOfYear: Date {
        let components = calendar.dateComponents([.year], from: self)
        return calendar.date(from: components) ?? self
    }

    var year: Int { calendar.component(.year, from: self) }

    var month: Int { calendar.component(.month, from: self) }

    var day: Int { calendar.component(.day, from: self) }

    var quarter: Int { ((month - 1) / 3) + 1 }

    func addingMonths(_ value: Int) -> Date {
        calendar.date(byAdding: .month, value: value, to: self) ?? self
    }

    func addingDays(_ value: Int) -> Date {
        calendar.date(byAdding: .day, value: value, to: self) ?? self
    }

    func isSameMonth(as other: Date) -> Bool {
        calendar.isDate(self, equalTo: other, toGranularity: .month)
    }

    func isSameYear(as other: Date) -> Bool {
        calendar.isDate(self, equalTo: other, toGranularity: .year)
    }

    static func make(year: Int, month: Int, day: Int = 1) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components) ?? Date()
    }

    /// Ближайшая дата платежа: та же дата, что у старта, но не раньше сегодняшнего дня.
    func nextOccurrence(everyMonths months: Int, from start: Date) -> Date {
        guard months > 0 else { return start }
        let today = Date().startOfDay
        var occurrence = start.startOfDay
        var guardCounter = 0
        while occurrence < today && guardCounter < 1000 {
            occurrence = occurrence.addingMonths(months)
            guardCounter += 1
        }
        return occurrence
    }
}

enum MonthFormat {
    static let ruLocale = Locale(identifier: "ru_RU")

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

    static func monthTitle(_ date: Date) -> String {
        monthYearFormatter.string(from: date).capitalizedFirst
    }

    static func shortMonth(_ date: Date) -> String {
        shortMonthFormatter.string(from: date).replacingOccurrences(of: ".", with: "")
    }

    static func day(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func shortMonthWithYear(_ date: Date) -> String {
        "\(shortMonth(date)) \(String(format: "%02d", date.year % 100))"
    }

    static func compactDay(_ date: Date) -> String {
        compactDayFormatter.string(from: date)
    }

    static func quarterTitle(year: Int, quarter: Int) -> String {
        "\(romanQuarter(quarter)) кв. \(year)"
    }

    static func romanQuarter(_ quarter: Int) -> String {
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
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
