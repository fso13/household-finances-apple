import FinancesCore
import SwiftUI

// MARK: - Цвета и иконки моделей (только UI-слой)

package extension IncomeType {
    var color: Color {
        switch self {
        case .salary: .blue
        case .advance: .teal
        case .vacation: .orange
        case .bonus: .purple
        case .sickLeave: .pink
        case .compensation: .indigo
        case .other: .gray
        }
    }
}

package extension ExpenseCategory {
    var color: Color {
        if let tint {
            return tint.color
        }
        switch rawValue {
        case "rent": return .blue
        case "garage": return .brown
        case "utilities": return .orange
        case "subscriptions": return .purple
        case "internet": return .cyan
        case "transport": return .teal
        case "food": return .green
        case "health": return .pink
        case "entertainment": return .indigo
        case "other": return .gray
        default: return .gray
        }
    }
}

package extension TintColor {
    var color: Color {
        switch self {
        case .blue: .blue
        case .teal: .teal
        case .green: .green
        case .orange: .orange
        case .red: .red
        case .pink: .pink
        case .purple: .purple
        case .indigo: .indigo
        case .brown: .brown
        case .gray: .gray
        }
    }
}
