import Foundation

// MARK: - Баланс по квартире

package struct ApartmentYearBalance {
    package let opening: Double
    package let yearOverpayment: Double

    package var closing: Double { opening + yearOverpayment }
}

package enum ApartmentService {
    package static func openingBalance(
        before year: Int,
        months: [ApartmentMonth]
    ) -> Double {
        months
            .filter { $0.year < year }
            .reduce(0) { $0 + $1.overpayment }
    }

    package static func balance(
        for year: Int,
        months: [ApartmentMonth]
    ) -> ApartmentYearBalance {
        ApartmentYearBalance(
            opening: openingBalance(before: year, months: months),
            yearOverpayment:
                months
                .filter { $0.year == year }
                .reduce(0) { $0 + $1.overpayment }
        )
    }

    /// Запас после каждого месяца года с учётом переплат прошлых лет.
    package static func runningBalances(
        for year: Int,
        months: [ApartmentMonth]
    ) -> [Int: Double] {
        var balance = openingBalance(before: year, months: months)
        var result: [Int: Double] = [:]
        for month in 1...12 {
            let overpayment =
                months
                .filter { $0.year == year && $0.month == month }
                .reduce(0) { $0 + $1.overpayment }
            balance += overpayment
            result[month] = balance
        }
        return result
    }
}
