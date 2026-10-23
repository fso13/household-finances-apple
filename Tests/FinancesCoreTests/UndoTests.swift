import SwiftData
import XCTest
@testable import FinancesCore

@MainActor
final class UndoTests: XCTestCase {
    func testUndoDeleteRestoresEntry() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: IncomeEntry.self,
            ExpenseEntry.self,
            RecurringPayment.self,
            Subscription.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        DataUndo.shared.removeAllActions()

        let entry = IncomeEntry(amount: 1_000, date: makeDate(2026, 10, 1), type: .salary)
        context.insert(entry)
        try Persistence.save(context, operation: "test.insert")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<IncomeEntry>()), 1)

        DeletionUndo.register(entry, in: context)
        context.delete(entry)
        try Persistence.save(context, operation: "test.delete")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<IncomeEntry>()), 0)

        DataUndo.shared.undo()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<IncomeEntry>()), 1)

        DataUndo.shared.redo()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<IncomeEntry>()), 0)
    }
}
