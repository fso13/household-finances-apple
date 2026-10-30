import Foundation

// MARK: - Настройки CSV-экспорта

package struct CSVExportSettings: Codable, Equatable, Sendable {
    package enum Delimiter: String, CaseIterable, Identifiable, Codable, Sendable {
        case semicolon
        case comma
        case tab

        package var id: String { rawValue }
        package var title: String {
            switch self {
            case .semicolon: "Точка с запятой (;)"
            case .comma: "Запятая (,)"
            case .tab: "Табуляция"
            }
        }
        package var character: Character {
            switch self {
            case .semicolon: ";"
            case .comma: ","
            case .tab: "\t"
            }
        }
    }

    package var delimiter: Delimiter = .semicolon
    package var includeIncomes = true
    package var includeExpenses = true
    package var includeRecurring = true
    package var includeSubscriptions = true
    package var includeBOM = true

    package init() {}

    package static func load() -> CSVExportSettings {
        guard let data = UserDefaults.standard.data(forKey: "csvExportSettings"),
            let settings = try? JSONDecoder().decode(CSVExportSettings.self, from: data)
        else { return CSVExportSettings() }
        return settings
    }

    package func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: "csvExportSettings")
    }
}
