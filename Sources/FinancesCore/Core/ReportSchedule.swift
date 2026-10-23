import Foundation

// MARK: - Расписание отчётов

package enum ReportFrequency: String, CaseIterable, Identifiable, Codable, Sendable {
    case weekly
    case monthly

    package var id: String { rawValue }
    package var title: String {
        switch self {
        case .weekly: "Раз в неделю"
        case .monthly: "Раз в месяц"
        }
    }
    package var days: Int {
        switch self {
        case .weekly: 7
        case .monthly: 30
        }
    }
}

package enum ReportSchedulePlanner {
    package static func isDue(
        lastGenerated: Date?,
        frequency: ReportFrequency,
        now: Date = Date()
    ) -> Bool {
        guard let lastGenerated else { return true }
        let elapsed = now.timeIntervalSince(lastGenerated)
        return elapsed >= Double(frequency.days) * 86_400
    }
}
