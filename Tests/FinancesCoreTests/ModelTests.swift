import XCTest
@testable import FinancesCore

final class ModelTests: XCTestCase {
    func testRecurringPaymentRoundingAndCosts() {
        let payment = RecurringPayment(
            title: "Аренда",
            category: .rent,
            baseAmount: 47_250,
            rounding: .up,
            roundingStep: 100,
            frequency: .monthly
        )

        XCTAssertEqual(payment.payableAmount, 47_300)
        XCTAssertEqual(payment.roundingDelta, 50, accuracy: 0.001)
        XCTAssertEqual(payment.monthlyCost, 47_300)
        XCTAssertEqual(payment.yearlyCost, 567_600)
    }

    func testQuarterlyPaymentMonthlyCost() {
        let payment = RecurringPayment(
            title: "Гараж",
            category: .garage,
            baseAmount: 3_300,
            frequency: .quarterly
        )

        XCTAssertEqual(payment.monthlyCost, 1_100, accuracy: 0.001)
        XCTAssertEqual(payment.yearlyCost, 13_200, accuracy: 0.001)
    }

    func testMonthlyNextPaymentDate() {
        let payment = RecurringPayment(
            title: "Коммуналка",
            category: .utilities,
            baseAmount: 6_000,
            dayOfMonth: 10,
            startDate: makeDate(2026, 1, 10)
        )

        let next = payment.nextPaymentDate(relativeTo: makeDate(2026, 3, 15))
        XCTAssertEqual(next.components, makeDate(2026, 4, 10).components)
    }

    func testMonthlyNextPaymentDateBeforeDayOfMonth() {
        let payment = RecurringPayment(
            title: "Интернет",
            category: .internet,
            baseAmount: 1_450,
            dayOfMonth: 12,
            startDate: makeDate(2026, 1, 12)
        )

        let next = payment.nextPaymentDate(relativeTo: makeDate(2026, 3, 5))
        XCTAssertEqual(next.components, makeDate(2026, 3, 12).components)
    }

    func testMonthlyNextPaymentDateUsesFutureStart() {
        let payment = RecurringPayment(
            title: "Новый платёж",
            category: .other,
            baseAmount: 1_000,
            dayOfMonth: 10,
            startDate: makeDate(2026, 6, 20)
        )

        let next = payment.nextPaymentDate(relativeTo: makeDate(2026, 3, 5))
        XCTAssertEqual(next.components, makeDate(2026, 6, 20).components)
    }

    func testQuarterlyNextPaymentDate() {
        let payment = RecurringPayment(
            title: "Гараж",
            category: .garage,
            baseAmount: 3_300,
            frequency: .quarterly,
            startDate: makeDate(2026, 1, 5)
        )

        let next = payment.nextPaymentDate(relativeTo: makeDate(2026, 2, 1))
        XCTAssertEqual(next.components, makeDate(2026, 4, 5).components)
    }

    func testSubscriptionCosts() {
        let yearly = Subscription(name: "Облако", amount: 7_990, cycle: .yearly)
        XCTAssertEqual(yearly.monthlyCost, 665.833, accuracy: 0.01)
        XCTAssertEqual(yearly.yearlyCost, 7_990, accuracy: 0.01)
    }

    func testSubscriptionNextPaymentDate() {
        let subscription = Subscription(
            name: "Музыка",
            amount: 199,
            cycle: .monthly,
            startDate: makeDate(2026, 1, 5)
        )
        let next = subscription.nextPaymentDate(relativeTo: makeDate(2026, 3, 7))
        XCTAssertEqual(next.components, makeDate(2026, 4, 5).components)
    }

    func testIncomeAndExpenseTypeMapping() {
        let income = IncomeEntry(amount: 100, type: .bonus)
        XCTAssertEqual(income.type, .bonus)
        income.type = .vacation
        XCTAssertEqual(income.type, .vacation)

        let expense = ExpenseEntry(amount: 100, category: .utilities)
        XCTAssertEqual(expense.category, .utilities)
        expense.category = .health
        XCTAssertEqual(expense.category, .health)
    }
}
