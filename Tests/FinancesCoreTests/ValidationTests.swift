import SwiftData
import XCTest
@testable import FinancesCore

final class ValidationTests: XCTestCase {
    func testAmountValidation() {
        XCTAssertNil(InputValidation.amountError(1))
        XCTAssertNotNil(InputValidation.amountError(0))
        XCTAssertNotNil(InputValidation.amountError(-10))
        XCTAssertNotNil(InputValidation.amountError(.infinity))
        XCTAssertNotNil(InputValidation.amountError(InputValidation.maxAmount + 1))
    }

    func testEntryDateValidation() {
        let now = makeDate(2026, 10, 23)
        XCTAssertNil(InputValidation.entryDateError(makeDate(2026, 10, 23), now: now))
        XCTAssertNotNil(InputValidation.entryDateError(makeDate(2026, 10, 24), now: now))
        XCTAssertNotNil(InputValidation.entryDateError(makeDate(1999, 12, 31), now: now))
    }

    func testStartDateValidation() {
        let now = makeDate(2026, 10, 23)
        XCTAssertNil(InputValidation.startDateError(makeDate(2027, 1, 1), now: now))
        XCTAssertNotNil(InputValidation.startDateError(makeDate(1999, 1, 1), now: now))
        XCTAssertNotNil(InputValidation.startDateError(makeDate(2050, 1, 1), now: now))
    }

    func testTitleAndNoteValidation() {
        XCTAssertNil(InputValidation.titleError("Аренда"))
        XCTAssertNotNil(InputValidation.titleError("   "))
        XCTAssertNotNil(InputValidation.titleError(String(repeating: "a", count: 121)))
        XCTAssertNil(InputValidation.noteError(String(repeating: "a", count: 500)))
        XCTAssertNotNil(InputValidation.noteError(String(repeating: "a", count: 501)))
    }

    func testRoundingStepValidation() {
        XCTAssertNil(InputValidation.roundingStepError(100))
        XCTAssertNotNil(InputValidation.roundingStepError(0))
        XCTAssertNotNil(InputValidation.roundingStepError(100_001))
    }

    func testSchemaVersion() {
        XCTAssertEqual(FinancesSchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
        XCTAssertEqual(FinancesSchemaV1.models.count, 4)
        XCTAssertEqual(FinancesMigrationPlan.schemas.count, 1)
        XCTAssertTrue(FinancesMigrationPlan.stages.isEmpty)
    }
}
