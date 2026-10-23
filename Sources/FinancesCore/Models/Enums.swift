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

package enum ExpenseCategory: String, CaseIterable, Codable, Identifiable, Hashable {
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

    package var id: String { rawValue }

    package var title: String {
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

    package var icon: String {
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

    /// Жильё, гараж, коммуналка, интернет — обязательные регулярные траты.
    package var isMandatory: Bool {
        switch self {
        case .rent, .garage, .utilities, .internet: true
        default: false
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

package enum TintColor: String, CaseIterable, Identifiable, Hashable {
    case blue, teal, green, orange, red, pink, purple, indigo, brown, gray

    package var id: String { rawValue }
}
