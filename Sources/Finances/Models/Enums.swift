import SwiftUI

// MARK: - Типы доходов

enum IncomeType: String, CaseIterable, Codable, Identifiable, Hashable {
    case salary
    case advance
    case vacation
    case bonus
    case sickLeave
    case compensation
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .salary: "Зарплата"
        case .advance: "Аванс"
        case .vacation: "Отпускные"
        case .bonus: "Премия"
        case .sickLeave: "Больничный"
        case .compensation: "Компенсация"
        case .other: "Прочее"
        }
    }

    var icon: String {
        switch self {
        case .salary: "briefcase.fill"
        case .advance: "banknote.fill"
        case .vacation: "beach.umbrella.fill"
        case .bonus: "star.fill"
        case .sickLeave: "cross.case.fill"
        case .compensation: "arrow.uturn.backward.circle.fill"
        case .other: "ellipsis.circle.fill"
        }
    }

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

    /// Регулярные «зарплатные» выплаты — используются в средних значениях.
    var isRegularPay: Bool { self == .salary || self == .advance }
}

// MARK: - Категории расходов

enum ExpenseCategory: String, CaseIterable, Codable, Identifiable, Hashable {
    case rent
    case garage
    case utilities
    case subscriptions
    case internet
    case transport
    case food
    case health
    case entertainment
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rent: "Квартира"
        case .garage: "Гараж"
        case .utilities: "Коммуналка"
        case .subscriptions: "Подписки"
        case .internet: "Интернет и связь"
        case .transport: "Транспорт"
        case .food: "Продукты"
        case .health: "Здоровье"
        case .entertainment: "Развлечения"
        case .other: "Прочее"
        }
    }

    var icon: String {
        switch self {
        case .rent: "building.2.fill"
        case .garage: "car.fill"
        case .utilities: "bolt.fill"
        case .subscriptions: "creditcard.fill"
        case .internet: "wifi"
        case .transport: "tram.fill"
        case .food: "cart.fill"
        case .health: "heart.fill"
        case .entertainment: "popcorn.fill"
        case .other: "square.grid.2x2.fill"
        }
    }

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

    /// Жильё, гараж, коммуналка, интернет — обязательные регулярные траты.
    var isMandatory: Bool {
        switch self {
        case .rent, .garage, .utilities, .internet: true
        default: false
        }
    }
}

// MARK: - Округление

enum RoundingRule: String, CaseIterable, Codable, Identifiable, Hashable {
    case none
    case up
    case down
    case nearest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "Без округления"
        case .up: "В большую сторону"
        case .down: "В меньшую сторону"
        case .nearest: "До ближайшего"
        }
    }

    var shortTitle: String {
        switch self {
        case .none: "Без округления"
        case .up: "Вверх"
        case .down: "Вниз"
        case .nearest: "Ближайшее"
        }
    }

    var icon: String {
        switch self {
        case .none: "minus"
        case .up: "arrow.up.to.line"
        case .down: "arrow.down.to.line"
        case .nearest: "arrow.left.and.right"
        }
    }

    /// Применяет правило округления к сумме с заданным шагом.
    func apply(_ value: Double, step: Double) -> Double {
        guard self != .none, step > 0 else { return value }
        switch self {
        case .none:
            return value
        case .up:
            return (value / step).rounded(.up) * step
        case .down:
            return (value / step).rounded(.down) * step
        case .nearest:
            return (value / step).rounded() * step
        }
    }

    func description(step: Double) -> String {
        switch self {
        case .none: "Сумма списывается как есть"
        case .up: "Округление вверх до \(Int(step)) ₽"
        case .down: "Округление вниз до \(Int(step)) ₽"
        case .nearest: "Округление до ближайшего \(Int(step)) ₽"
        }
    }
}

// MARK: - Периодичность

enum PaymentFrequency: String, CaseIterable, Codable, Identifiable, Hashable {
    case monthly
    case quarterly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly: "Ежемесячно"
        case .quarterly: "Раз в квартал"
        case .yearly: "Раз в год"
        }
    }

    var shortTitle: String {
        switch self {
        case .monthly: "мес."
        case .quarterly: "квартал"
        case .yearly: "год"
        }
    }

    var months: Int {
        switch self {
        case .monthly: 1
        case .quarterly: 3
        case .yearly: 12
        }
    }
}

enum SubscriptionCycle: String, CaseIterable, Codable, Identifiable, Hashable {
    case monthly
    case quarterly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly: "Каждый месяц"
        case .quarterly: "Раз в квартал"
        case .yearly: "Раз в год"
        }
    }

    var shortTitle: String {
        switch self {
        case .monthly: "в месяц"
        case .quarterly: "в квартал"
        case .yearly: "в год"
        }
    }

    var months: Int {
        switch self {
        case .monthly: 1
        case .quarterly: 3
        case .yearly: 12
        }
    }
}

// MARK: - Цвета для подписок

enum TintColor: String, CaseIterable, Identifiable, Hashable {
    case blue, teal, green, orange, red, pink, purple, indigo, brown, gray

    var id: String { rawValue }

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

// MARK: - Разделы приложения

enum AppRoute: String, CaseIterable, Identifiable, Hashable {
    case dashboard
    case income
    case expenses
    case recurring
    case subscriptions
    case analytics
    case settings

    var id: String { rawValue }

    var title: String {
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

    var icon: String {
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

    var color: Color {
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

// MARK: - Палитра подписок по умолчанию

extension TintColor {
    static let subscriptionPalette: [TintColor] = [
        .purple, .blue, .pink, .orange, .green, .teal, .indigo, .red
    ]

    static func forIndex(_ index: Int) -> TintColor {
        subscriptionPalette[index % subscriptionPalette.count]
    }
}
