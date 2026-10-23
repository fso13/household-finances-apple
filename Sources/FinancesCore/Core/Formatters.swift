import Foundation

package enum Fmt {
    package static let ru = Locale(identifier: "ru_RU")

    /// Сумма в рублях. Копейки показываются только если они есть.
    package static func money(_ value: Double, cents: Bool? = nil) -> String {
        let showCents = cents ?? (abs(value.rounded() - value) > 0.005)
        return value.formatted(
            .currency(code: "RUB")
                .locale(ru)
                .precision(.fractionLength(showCents ? 2 : 0))
        )
    }

    /// Округлённая сумма для средних значений и итоговых KPI.
    package static func moneyRounded(_ value: Double) -> String {
        money(value.rounded())
    }

    /// Компактная сумма для осей графиков и подписей: 145 тыс., 1,2 млн.
    package static func compact(_ value: Double) -> String {
        let magnitude = abs(value)
        if magnitude >= 1_000_000 {
            let formatted = (value / 1_000_000)
                .formatted(.number.precision(.fractionLength(1)).locale(ru))
            return "\(formatted) млн"
        }
        if magnitude >= 10_000 {
            let formatted = (value / 1_000).rounded()
                .formatted(.number.precision(.fractionLength(0)).locale(ru))
            return "\(formatted) тыс."
        }
        if magnitude >= 1_000 {
            let formatted = (value / 1_000)
                .formatted(.number.precision(.fractionLength(1)).locale(ru))
            return "\(formatted) тыс."
        }
        let formatted = value.formatted(.number.precision(.fractionLength(0)).locale(ru))
        return formatted
    }

    package static func plain(_ value: Double, decimals: Int = 0) -> String {
        value.formatted(.number.precision(.fractionLength(decimals)).locale(ru))
    }

    package static func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(1)).locale(ru))
    }

    package static func signedPercent(_ value: Double) -> String {
        let sign = value > 0 ? "+" : (value < 0 ? "−" : "")
        return sign + value.formatted(.percent.precision(.fractionLength(1)).locale(ru))
    }

    package static func signedMoney(_ value: Double) -> String {
        let sign = value > 0 ? "+" : (value < 0 ? "−" : "")
        return sign + money(abs(value))
    }

    package static func signedCompact(_ value: Double) -> String {
        let sign = value > 0 ? "+" : (value < 0 ? "−" : "")
        return sign + compact(abs(value))
    }

    package static func plural(_ count: Int, one: String, few: String, many: String) -> String {
        let mod100 = count % 100
        let mod10 = count % 10
        if mod100 >= 11 && mod100 <= 14 {
            return "\(count) \(many)"
        }
        if mod10 == 1 {
            return "\(count) \(one)"
        }
        if mod10 >= 2 && mod10 <= 4 {
            return "\(count) \(few)"
        }
        return "\(count) \(many)"
    }
}
