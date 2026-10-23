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
        switch self {
        case .rent: .blue
        case .garage: .brown
        case .utilities: .orange
        case .subscriptions: .purple
        case .internet: .cyan
        case .transport: .teal
        case .food: .green
        case .health: .pink
        case .entertainment: .indigo
        case .other: .gray
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
