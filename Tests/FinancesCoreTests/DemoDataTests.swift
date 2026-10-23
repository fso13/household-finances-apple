import SwiftData
import XCTest
@testable import FinancesCore

@MainActor
final class DemoDataTests: XCTestCase {
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
            configurations: configuration
        )
        return ModelContext(container)
    }

    func testSeedCreatesDataAndIsIdempotent() throws {
        let context = try makeContext()
        try DemoData.seed(context: context)

        let incomeCount = try context.fetchCount(FetchDescriptor<IncomeEntry>())
        let expenseCount = try context.fetchCount(FetchDescriptor<ExpenseEntry>())
        let recurringCount = try context.fetchCount(FetchDescriptor<RecurringPayment>())
        let subscriptionCount = try context.fetchCount(FetchDescriptor<Subscription>())
        let budgetCount = try context.fetchCount(FetchDescriptor<Budget>())
        let goalCount = try context.fetchCount(FetchDescriptor<SavingsGoal>())

        XCTAssertGreaterThan(incomeCount, 0)
        XCTAssertGreaterThan(expenseCount, 0)
        XCTAssertEqual(recurringCount, 4)
        XCTAssertEqual(subscriptionCount, 7)
        XCTAssertEqual(budgetCount, 4)
        XCTAssertEqual(goalCount, 2)

        try DemoData.seed(context: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<IncomeEntry>()), incomeCount)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExpenseEntry>()), expenseCount)
    }

    func testSeedIsDeterministicForReferenceDate() throws {
        let reference = makeDate(2026, 10, 23)
        let first = try makeContext()
        let second = try makeContext()
        try DemoData.seed(context: first, referenceDate: reference)
        try DemoData.seed(context: second, referenceDate: reference)

        let firstIncomes = try first.fetch(FetchDescriptor<IncomeEntry>(sortBy: [SortDescriptor(\.date)]))
        let secondIncomes = try second.fetch(FetchDescriptor<IncomeEntry>(sortBy: [SortDescriptor(\.date)]))

        XCTAssertEqual(firstIncomes.count, secondIncomes.count)
        XCTAssertEqual(firstIncomes.map(\.amount), secondIncomes.map(\.amount))
        XCTAssertTrue(firstIncomes.allSatisfy { $0.date <= reference })
    }

    func testClearRemovesEverything() throws {
        let context = try makeContext()
        try DemoData.seed(context: context)
        try DemoData.clear(context: context)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<IncomeEntry>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExpenseEntry>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<RecurringPayment>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Subscription>()), 0)
    }
}
