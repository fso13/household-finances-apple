import Foundation

func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return Calendar.current.date(from: components)!
}

func makeDate(_ year: Int, _ month: Int, _ day: Int, hour: Int, minute: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    return Calendar.current.date(from: components)!
}

extension Date {
    var components: DateComponents {
        Calendar.current.dateComponents([.year, .month, .day], from: self)
    }
}
