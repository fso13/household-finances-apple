import XCTest
@testable import FinancesCore

final class CustomCategoryTests: XCTestCase {
    override func tearDown() {
        CustomCategoryCatalog.shared.replaceAll([])
        super.tearDown()
    }

    func testCustomCategoryInCatalogAndAll() throws {
        CustomCategoryCatalog.shared.replaceAll([])
        let custom = CustomExpenseCategory(
            name: "Спорт",
            icon: "figure.run",
            tint: .orange,
            isMandatory: false
        )
        CustomCategoryCatalog.shared.add(custom)

        let category = try XCTUnwrap(ExpenseCategory(rawValue: "custom:\(custom.id.uuidString)"))
        XCTAssertEqual(category.title, "Спорт")
        XCTAssertEqual(category.icon, "figure.run")
        XCTAssertEqual(category.tint, .orange)
        XCTAssertFalse(category.isMandatory)
        XCTAssertTrue(ExpenseCategory.all.contains(category))
        XCTAssertTrue(category.isCustom)
    }

    func testUpdateAndRemoveCustomCategory() throws {
        CustomCategoryCatalog.shared.replaceAll([])
        var custom = CustomExpenseCategory(name: "Спорт", icon: "figure.run", tint: .orange)
        CustomCategoryCatalog.shared.add(custom)

        custom.name = "Фитнес"
        custom.isMandatory = true
        CustomCategoryCatalog.shared.update(custom)

        let category = try XCTUnwrap(ExpenseCategory(rawValue: "custom:\(custom.id.uuidString)"))
        XCTAssertEqual(category.title, "Фитнес")
        XCTAssertTrue(category.isMandatory)

        CustomCategoryCatalog.shared.remove(id: custom.id)
        XCTAssertNil(ExpenseCategory(rawValue: "custom:\(custom.id.uuidString)")?.custom)
        XCTAssertFalse(ExpenseCategory.all.contains { $0.rawValue == "custom:\(custom.id.uuidString)" })
    }

    func testMergeCustomCategories() throws {
        CustomCategoryCatalog.shared.replaceAll([])
        let first = CustomExpenseCategory(name: "Спорт", icon: "figure.run", tint: .orange)
        let second = CustomExpenseCategory(name: "Питомцы", icon: "pawprint.fill", tint: .brown)
        CustomCategoryCatalog.shared.merge([first, second])
        CustomCategoryCatalog.shared.merge([first])

        XCTAssertEqual(CustomCategoryCatalog.shared.categories.count, 2)
        XCTAssertEqual(Set(CustomCategoryCatalog.shared.categories.map(\.name)), ["Спорт", "Питомцы"])
    }

    func testUnknownRawValueFallsBackGracefully() throws {
        let category = try XCTUnwrap(ExpenseCategory(rawValue: "unknown"))
        XCTAssertEqual(category.title, "Категория")
        XCTAssertFalse(category.isMandatory)
        XCTAssertEqual(category.icon, "tag.fill")
    }
}
