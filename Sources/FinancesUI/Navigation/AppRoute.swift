import SwiftUI

// MARK: - Разделы приложения

package enum AppRoute: String, CaseIterable, Identifiable, Hashable {
    case dashboard
    case income
    case expenses
    case recurring
    case subscriptions
    case analytics
    case settings

    package var id: String { rawValue }

    package var title: String {
        switch self {
        case .dashboard: "Обзор"
        case .income: "Доходы"
        case .expenses: "Расходы"
        case .recurring: "Обязательные"
        case .subscriptions: "Подписки"
        case .analytics: "Аналитика"
        case .settings: "Настройки"
        }
    }

    package var icon: String {
        switch self {
        case .dashboard: "square.grid.2x2.fill"
        case .income: "arrow.down.circle.fill"
        case .expenses: "arrow.up.circle.fill"
        case .recurring: "calendar.badge.clock"
        case .subscriptions: "repeat.circle.fill"
        case .analytics: "chart.pie.fill"
        case .settings: "gearshape.fill"
        }
    }

    package var color: Color {
        switch self {
        case .dashboard: .indigo
        case .income: .green
        case .expenses: .orange
        case .recurring: .blue
        case .subscriptions: .purple
        case .analytics: .teal
        case .settings: .gray
        }
    }
}
