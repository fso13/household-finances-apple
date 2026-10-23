import XCTest
@testable import FinancesCore

final class CategoryRuleTests: XCTestCase {
    func testMatchesKeyword() {
        let rules = [
            CategoryRule(keyword: "пятёрочка", category: .food),
            CategoryRule(keyword: "такси", category: .transport),
        ]
        XCTAssertEqual(CategoryRuleEngine.category(for: "Оплата Пятёрочка 1234", rules: rules), .food)
        XCTAssertEqual(CategoryRuleEngine.category(for: "Яндекс Такси", rules: rules), .transport)
        XCTAssertNil(CategoryRuleEngine.category(for: "Аптека", rules: rules))
    }

    func testPriorityWins() {
        let rules = [
            CategoryRule(keyword: "аренда", category: .rent, priority: 1),
            CategoryRule(keyword: "аренда квартиры", category: .utilities, priority: 10),
        ]
        XCTAssertEqual(
            CategoryRuleEngine.category(for: "Аренда квартиры, октябрь", rules: rules),
            .utilities
        )
    }

    func testCatalogCRUD() {
        CategoryRuleCatalog.shared.replaceAll([])
        defer { CategoryRuleCatalog.shared.replaceAll([]) }

        let rule = CategoryRule(keyword: "кофе", category: .food)
        CategoryRuleCatalog.shared.add(rule)
        XCTAssertEqual(CategoryRuleCatalog.shared.rules.count, 1)

        CategoryRuleCatalog.shared.update(
            CategoryRule(id: rule.id, keyword: "кофе", category: .entertainment)
        )
        XCTAssertEqual(CategoryRuleCatalog.shared.rules.first?.category, .entertainment)

        CategoryRuleCatalog.shared.remove(id: rule.id)
        XCTAssertTrue(CategoryRuleCatalog.shared.rules.isEmpty)
    }
}
