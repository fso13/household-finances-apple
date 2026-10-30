import SwiftUI

// MARK: - Разделы приложения

package enum AppRoute: String, CaseIterable, Identifiable, Hashable {
    case dashboard
    case income
    case expenses
    case budgets
    case goals
    case apartment
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
        case .budgets: "Бюджеты"
        case .goals: "Цели"
        case .apartment: "Квартира"
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
        case .budgets: "target"
        case .goals: "flag.checkered"
        case .apartment: "building.2.fill"
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
        case .budgets: .green
        case .goals: .pink
        case .apartment: .blue
        case .recurring: .blue
        case .subscriptions: .purple
        case .analytics: .teal
        case .settings: .gray
        }
    }
}
