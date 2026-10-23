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

        XCTAssertGreaterThan(incomeCount, 0)
        XCTAssertGreaterThan(expenseCount, 0)
        XCTAssertEqual(recurringCount, 4)
        XCTAssertEqual(subscriptionCount, 7)

        try DemoData.seed(context: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<IncomeEntry>()), incomeCount)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExpenseEntry>()), expenseCount)
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
