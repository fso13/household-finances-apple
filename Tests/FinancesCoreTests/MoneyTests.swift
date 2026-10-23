import XCTest
@testable import FinancesCore

final class MoneyTests: XCTestCase {
    func testKopecksFromDouble() {
        XCTAssertEqual(Money.kopecks(from: 47_250), 4_725_000)
        XCTAssertEqual(Money.kopecks(from: 6_347.32), 634_732)
        XCTAssertEqual(Money.kopecks(from: 0.1 + 0.2), 30)
        XCTAssertEqual(Money.kopecks(from: -1.25), -125)
    }

    func testAmountFromKopecks() {
        XCTAssertEqual(Money.amount(from: 4_725_000), 47_250)
        XCTAssertEqual(Money.amount(from: 30), 0.3, accuracy: 0.0001)
    }

    func testModelsStoreKopecks() {
        let income = IncomeEntry(amount: 1_234.56)
        XCTAssertEqual(income.amountKopecks, 123_456)
        XCTAssertEqual(income.amount, 1_234.56, accuracy: 0.0001)

        let payment = RecurringPayment(
            title: "Коммуналка",
            category: .utilities,
            baseAmount: 6_347.32,
            rounding: .nearest,
            roundingStep: 10
        )
        XCTAssertEqual(payment.baseAmountKopecks, 634_732)
        XCTAssertEqual(payment.roundingStepKopecks, 1_000)
        XCTAssertEqual(payment.payableAmount, 6_350)
    }
}
