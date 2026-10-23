import XCTest
@testable import FinancesCore

final class RoundingRuleTests: XCTestCase {
    func testNoRoundingKeepsValue() {
        XCTAssertEqual(RoundingRule.none.apply(47_250, step: 100), 47_250)
        XCTAssertEqual(RoundingRule.none.apply(6_347.32, step: 10), 6_347.32)
    }

    func testRoundUp() {
        XCTAssertEqual(RoundingRule.up.apply(47_250, step: 100), 47_300)
        XCTAssertEqual(RoundingRule.up.apply(47_200, step: 100), 47_200)
        XCTAssertEqual(RoundingRule.up.apply(6_347.32, step: 10), 6_350)
    }

    func testRoundDown() {
        XCTAssertEqual(RoundingRule.down.apply(47_299, step: 100), 47_200)
        XCTAssertEqual(RoundingRule.down.apply(47_300, step: 100), 47_300)
        XCTAssertEqual(RoundingRule.down.apply(6_347.32, step: 10), 6_340)
    }

    func testRoundToNearest() {
        XCTAssertEqual(RoundingRule.nearest.apply(47_249, step: 100), 47_200)
        XCTAssertEqual(RoundingRule.nearest.apply(47_250, step: 100), 47_300)
        XCTAssertEqual(RoundingRule.nearest.apply(6_347.32, step: 10), 6_350)
    }

    func testInvalidStepDoesNotChangeValue() {
        XCTAssertEqual(RoundingRule.up.apply(1_234, step: 0), 1_234)
        XCTAssertEqual(RoundingRule.down.apply(1_234, step: -10), 1_234)
    }

    func testDescriptions() {
        XCTAssertEqual(RoundingRule.up.description(step: 100), "Округление вверх до 100 ₽")
        XCTAssertEqual(RoundingRule.nearest.description(step: 10), "Округление до ближайшего 10 ₽")
    }
}
