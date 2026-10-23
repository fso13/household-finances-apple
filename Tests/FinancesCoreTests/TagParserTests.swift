import XCTest
@testable import FinancesCore

final class TagParserTests: XCTestCase {
    func testExtractsTags() {
        XCTAssertEqual(
            TagParser.tags(in: "Отпуск #лето #Море #лето"),
            ["лето", "море"]
        )
        XCTAssertEqual(
            TagParser.tags(in: "Покупка #дом_и_сад, #ремонт-2026!"),
            ["дом_и_сад", "ремонт-2026"]
        )
        XCTAssertTrue(TagParser.tags(in: "без тегов").isEmpty)
        XCTAssertTrue(TagParser.tags(in: "#").isEmpty)
    }

    func testCountsAndMatching() {
        let incomes = [
            IncomeEntry(amount: 100, note: "#работа"),
            IncomeEntry(amount: 200, note: "#работа #отпуск"),
        ]
        let expenses = [
            ExpenseEntry(amount: 50, note: "#отпуск"),
        ]
        let counts = TagParser.counts(incomes: incomes, expenses: expenses)
        XCTAssertEqual(counts.first?.tag, "отпуск")
        XCTAssertEqual(counts.first?.count, 2)
        XCTAssertTrue(TagParser.matches("#работа", selected: ["работа"]))
        XCTAssertFalse(TagParser.matches("#работа", selected: ["отпуск"]))
        XCTAssertTrue(TagParser.matches("", selected: []))
    }
}
