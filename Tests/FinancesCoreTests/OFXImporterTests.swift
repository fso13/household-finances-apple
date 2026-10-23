import XCTest
@testable import FinancesCore

final class OFXImporterTests: XCTestCase {
    private let sample = """
        OFXHEADER:100
        <OFX>
        <BANKMSGSRSV1><STMTTRNRS><STMTRS><BANKTRANLIST>
        <STMTTRN>
        <TRNTYPE>DEBIT
        <DTPOSTED>20261005120000
        <TRNAMT>-1234.50
        <FITID>1
        <NAME>ПЯТЁРОЧКА</NAME>
        <MEMO>Продукты</MEMO>
        </STMTTRN>
        <STMTTRN>
        <TRNTYPE>CREDIT
        <DTPOSTED>20261010
        <TRNAMT>150000.00
        <FITID>2
        <NAME>Зарплата</NAME>
        </STMTTRN>
        </BANKTRANLIST></STMTRS></STMTTRNRS></BANKMSGSRSV1>
        </OFX>
        """

    func testParsesDebitAndCredit() throws {
        let preview = try OFXImporter.preview(data: Data(sample.utf8))
        XCTAssertEqual(preview.expenses.count, 1)
        XCTAssertEqual(preview.incomes.count, 1)
        XCTAssertEqual(preview.expenses.first?.amount, 1_234.5)
        XCTAssertEqual(preview.incomes.first?.amount, 150_000)
        XCTAssertEqual(preview.incomes.first?.type, IncomeType.salary.rawValue)
    }

    func testAppliesCategoryRules() throws {
        CategoryRuleCatalog.shared.replaceAll([])
        defer { CategoryRuleCatalog.shared.replaceAll([]) }
        CategoryRuleCatalog.shared.add(CategoryRule(keyword: "пятёрочка", category: .food))

        let preview = try OFXImporter.preview(data: Data(sample.utf8))
        XCTAssertEqual(preview.expenses.first?.category, ExpenseCategory.food.rawValue)
    }

    func testRejectsNonOFX() {
        XCTAssertThrowsError(try OFXImporter.preview(data: Data("date,amount".utf8)))
    }
}
