import SwiftData
import XCTest
@testable import FinancesCore

@MainActor
final class PaymentPeriodTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: IncomeEntry.self,
            ExpenseEntry.self,
            RecurringPayment.self,
            Subscription.self,
            Budget.self,
            SavingsGoal.self,
            PaymentPeriod.self,
            RecurringDetail.self,
            RecurringPriceChange.self,
            ApartmentMonth.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    private func payment(active: Bool = true) -> RecurringPayment {
        RecurringPayment(
            title: "Аренда",
            category: .rent,
            baseAmount: 47_250,
            rounding: .up,
            roundingStep: 100,
            startDate: makeDate(2026, 1, 1),
            isActive: active
        )
    }

    func testMarkPaidCreatesPeriodAndExpense() throws {
        let context = try makeContext()
        let payment = payment()
        context.insert(payment)
        let month = makeDate(2026, 10, 1)

        let period = try PaymentPeriodService.markPaid(
            payment,
            month: month,
            context: context,
            periods: [],
            date: makeDate(2026, 10, 5)
        )

        XCTAssertEqual(period.status, .paid)
        XCTAssertEqual(period.paidAmount, 47_300)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExpenseEntry>()), 1)
    }

    func testSkipAndUnskip() throws {
        let context = try makeContext()
        let payment = payment()
        context.insert(payment)
        let month = makeDate(2026, 10, 1)

        let period = try PaymentPeriodService.skip(
            payment,
            month: month,
            context: context,
            periods: []
        )
        XCTAssertEqual(period.status, .skipped)

        let periods = try context.fetch(FetchDescriptor<PaymentPeriod>())
        XCTAssertEqual(
            PaymentPeriodService.status(
                for: payment,
                month: month,
                periods: periods,
                expenses: []
            ),
            .skipped
        )

        try PaymentPeriodService.unskip(period, context: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PaymentPeriod>()), 0)
    }

    func testStatusFromRecordedExpenseAndOverdue() throws {
        let context = try makeContext()
        let payment = payment()
        context.insert(payment)
        let month = makeDate(2026, 10, 1)
        context.insert(
            ExpenseEntry(
                amount: payment.payableAmount,
                date: makeDate(2026, 10, 10),
                category: .rent,
                note: payment.title
            )
        )

        XCTAssertEqual(
            PaymentPeriodService.status(
                for: payment,
                month: month,
                periods: [],
                expenses: try context.fetch(FetchDescriptor<ExpenseEntry>())
            ),
            .paid
        )
        XCTAssertFalse(
            PaymentPeriodService.isOverdue(
                payment,
                month: month,
                periods: [],
                expenses: [],
                now: makeDate(2026, 10, 5)
            )
        )
        XCTAssertTrue(
            PaymentPeriodService.isOverdue(
                payment,
                month: month,
                periods: [],
                expenses: [],
                now: makeDate(2026, 10, 15)
            )
        )
        XCTAssertTrue(
            PaymentPeriodService.isOverdue(
                payment,
                month: makeDate(2026, 11, 1),
                periods: [],
                expenses: [],
                now: makeDate(2026, 12, 15)
            )
        )
    }

    func testSkipPaidPeriodFails() throws {
        let context = try makeContext()
        let payment = payment()
        context.insert(payment)
        let month = makeDate(2026, 10, 1)
        let period = try PaymentPeriodService.markPaid(
            payment,
            month: month,
            context: context,
            periods: [],
            date: makeDate(2026, 10, 5)
        )

        XCTAssertThrowsError(
            try PaymentPeriodService.skip(
                payment,
                month: month,
                context: context,
                periods: [period]
            )
        )
    }

    func testPartialPaymentAccumulatesAndCompletes() throws {
        let context = try makeContext()
        let payment = payment()
        context.insert(payment)
        let month = makeDate(2026, 10, 1)

        _ = try PaymentPeriodService.recordPartial(
            payment,
            month: month,
            amount: 20_000,
            context: context,
            periods: []
        )
        var periods = try context.fetch(FetchDescriptor<PaymentPeriod>())
        XCTAssertEqual(periods.first?.status, .partial)
        XCTAssertEqual(periods.first?.paidAmount, 20_000)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExpenseEntry>()), 1)

        _ = try PaymentPeriodService.recordPartial(
            payment,
            month: month,
            amount: 10_000,
            context: context,
            periods: periods
        )
        periods = try context.fetch(FetchDescriptor<PaymentPeriod>())
        XCTAssertEqual(periods.first?.paidAmount, 30_000)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExpenseEntry>()), 1)

        _ = try PaymentPeriodService.recordPartial(
            payment,
            month: month,
            amount: 17_300,
            context: context,
            periods: periods
        )
        periods = try context.fetch(FetchDescriptor<PaymentPeriod>())
        XCTAssertEqual(periods.first?.status, .paid)
        XCTAssertEqual(periods.first?.paidAmount, 47_300)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExpenseEntry>()), 1)

        let expenses = try context.fetch(FetchDescriptor<ExpenseEntry>())
        XCTAssertEqual(expenses.first?.amount, 47_300)
    }

    func testPaymentActiveWindow() {
        let payment = payment()
        payment.startDate = makeDate(2026, 10, 1)
        XCTAssertFalse(PaymentPeriodService.isActive(payment, in: makeDate(2026, 9, 1)))
        XCTAssertTrue(PaymentPeriodService.isActive(payment, in: makeDate(2026, 10, 1)))
    }
}
