import XCTest
@testable import FinancesCore

final class ApartmentBalanceTests: XCTestCase {
    private func month(
        _ year: Int,
        _ month: Int,
        rent: Double = 35_000,
        capital: Double = 611.89,
        utilities: Double = 4_247.92,
        electricity: Double = 1_363.82,
        paid: Double
    ) -> ApartmentMonth {
        ApartmentMonth(
            year: year,
            month: month,
            rent: rent,
            capitalRepair: capital,
            utilities: utilities,
            electricity: electricity,
            paid: paid
        )
    }

    func testCarryFromPreviousYear() {
        let december2025 = month(
            2025, 12, capital: 523.11, utilities: 4_247.92, electricity: 1_568.78, paid: 41_500
        )
        let january2026 = month(2026, 1, paid: 42_000)
        let months = [december2025, january2026]

        XCTAssertEqual(ApartmentService.openingBalance(before: 2026, months: months), 160.19, accuracy: 0.001)
        let running = ApartmentService.runningBalances(for: 2026, months: months)
        XCTAssertEqual(running[1] ?? 0, 936.56, accuracy: 0.001)

        let balance = ApartmentService.balance(for: 2026, months: months)
        XCTAssertEqual(balance.opening, 160.19, accuracy: 0.001)
        XCTAssertEqual(balance.yearOverpayment, 776.37, accuracy: 0.001)
        XCTAssertEqual(balance.closing, 936.56, accuracy: 0.001)
    }
}
