import Foundation

// MARK: - Типы доходов

package enum IncomeType: String, CaseIterable, Codable, Identifiable, Hashable {
    case salary
    case advance
    case vacation
    case bonus
    case sickLeave
    case compensation
    case other

    package var id: String { rawValue }

    package var title: String {
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

    package var icon: String {
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

    /// Регулярные «зарплатные» выплаты — используются в средних значениях.
    package var isRegularPay: Bool { self == .salary || self == .advance }
}

// MARK: - Категории расходов

/// Категория — строка, чтобы поддерживать пользовательские категории.
/// Встроенные значения остаются прежними (`rent`, `food`, …).
package struct ExpenseCategory: RawRepresentable, Codable, Identifiable, Hashable, Sendable {
    package let rawValue: String

    package init?(rawValue: String) {
        guard !rawValue.isEmpty else { return nil }
        self.rawValue = rawValue
    }

    private init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    package var id: String { rawValue }

    package static let rent = ExpenseCategory("rent")
    package static let garage = ExpenseCategory("garage")
    package static let utilities = ExpenseCategory("utilities")
    package static let subscriptions = ExpenseCategory("subscriptions")
    package static let internet = ExpenseCategory("internet")
    package static let transport = ExpenseCategory("transport")
    package static let food = ExpenseCategory("food")
    package static let health = ExpenseCategory("health")
    package static let entertainment = ExpenseCategory("entertainment")
    package static let other = ExpenseCategory("other")

    package static let builtins: [ExpenseCategory] = [
        .rent, .garage, .utilities, .subscriptions, .internet,
        .transport, .food, .health, .entertainment, .other,
    ]

    package static var all: [ExpenseCategory] {
        builtins
            + CustomCategoryCatalog.shared.categories.map {
                ExpenseCategory("custom:\($0.id.uuidString)")
            }
    }

    package var customID: UUID? {
        guard rawValue.hasPrefix("custom:") else { return nil }
        return UUID(uuidString: String(rawValue.dropFirst("custom:".count)))
    }

    package var custom: CustomExpenseCategory? {
        guard let customID else { return nil }
        return CustomCategoryCatalog.shared.category(id: customID)
    }

    package var isCustom: Bool { customID != nil }

    package var title: String {
        if let custom { return custom.name }
        switch rawValue {
        case "rent": return "Квартира"
        case "garage": return "Гараж"
        case "utilities": return "Коммуналка"
        case "subscriptions": return "Подписки"
        case "internet": return "Интернет и связь"
        case "transport": return "Транспорт"
        case "food": return "Продукты"
        case "health": return "Здоровье"
        case "entertainment": return "Развлечения"
        case "other": return "Прочее"
        default: return "Категория"
        }
    }

    package var icon: String {
        if let custom { return custom.icon }
        switch rawValue {
        case "rent": return "building.2.fill"
        case "garage": return "car.fill"
        case "utilities": return "bolt.fill"
        case "subscriptions": return "creditcard.fill"
        case "internet": return "wifi"
        case "transport": return "tram.fill"
        case "food": return "cart.fill"
        case "health": return "heart.fill"
        case "entertainment": return "popcorn.fill"
        case "other": return "square.grid.2x2.fill"
        default: return "tag.fill"
        }
    }

    package var tint: TintColor? {
        custom?.tint
    }

    /// Жильё, гараж, коммуналка, интернет — обязательные регулярные траты.
    package var isMandatory: Bool {
        if let custom { return custom.isMandatory }
        switch rawValue {
        case "rent", "garage", "utilities", "internet": return true
        default: return false
        }
    }
}

// MARK: - Округление

package enum RoundingRule: String, CaseIterable, Codable, Identifiable, Hashable {
    case none
    case up
    case down
    case nearest

    package var id: String { rawValue }

    package var title: String {
        switch self {
        case .none: "Без округления"
        case .up: "В большую сторону"
        case .down: "В меньшую сторону"
        case .nearest: "До ближайшего"
        }
    }

    package var shortTitle: String {
        switch self {
        case .none: "Без округления"
        case .up: "Вверх"
        case .down: "Вниз"
        case .nearest: "Ближайшее"
        }
    }

    package var icon: String {
        switch self {
        case .none: "minus"
        case .up: "arrow.up.to.line"
        case .down: "arrow.down.to.line"
        case .nearest: "arrow.left.and.right"
        }
    }

    /// Применяет правило округления к сумме с заданным шагом.
    package func apply(_ value: Double, step: Double) -> Double {
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

    package func description(step: Double) -> String {
        switch self {
        case .none: "Сумма списывается как есть"
        case .up: "Округление вверх до \(Int(step)) ₽"
        case .down: "Округление вниз до \(Int(step)) ₽"
        case .nearest: "Округление до ближайшего \(Int(step)) ₽"
        }
    }
}

// MARK: - Периодичность

package enum PaymentFrequency: String, CaseIterable, Codable, Identifiable, Hashable {
    case monthly
    case quarterly
    case yearly

    package var id: String { rawValue }

    package var title: String {
        switch self {
        case .monthly: "Ежемесячно"
        case .quarterly: "Раз в квартал"
        case .yearly: "Раз в год"
        }
    }

    package var shortTitle: String {
        switch self {
        case .monthly: "мес."
        case .quarterly: "квартал"
        case .yearly: "год"
        }
    }

    package var months: Int {
        switch self {
        case .monthly: 1
        case .quarterly: 3
        case .yearly: 12
        }
    }
}

package enum SubscriptionCycle: String, CaseIterable, Codable, Identifiable, Hashable {
    case monthly
    case quarterly
    case yearly

    package var id: String { rawValue }

    package var title: String {
        switch self {
        case .monthly: "Каждый месяц"
        case .quarterly: "Раз в квартал"
        case .yearly: "Раз в год"
        }
    }

    package var shortTitle: String {
        switch self {
        case .monthly: "в месяц"
        case .quarterly: "в квартал"
        case .yearly: "в год"
        }
    }

    package var months: Int {
        switch self {
        case .monthly: 1
        case .quarterly: 3
        case .yearly: 12
        }
    }
}

// MARK: - Цвета для подписок

package enum TintColor: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case blue, teal, green, orange, red, pink, purple, indigo, brown, gray

    package var id: String { rawValue }
}
