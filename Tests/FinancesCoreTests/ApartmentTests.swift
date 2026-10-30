import XCTest
@testable import FinancesCore

final class ApartmentTests: XCTestCase {
    func testTotals() {
        let month = ApartmentMonth(
            year: 2026,
            month: 10,
            rent: 35_000,
            capitalRepair: 611.89,
            utilities: 5_181.34,
            electricity: 1_809.31,
            paid: 42_600
        )
        XCTAssertEqual(month.total, 42_602.54, accuracy: 0.001)
        XCTAssertEqual(month.overpayment, -2.54, accuracy: 0.001)
    }

    func testXLSXRoundTrip() throws {
        let source = [
            ApartmentMonthData(
                year: 2026,
                month: 9,
                rent: 35_000,
                capitalRepair: 611.89,
                utilities: 6_184.68,
                electricity: 3_415.42,
                paid: 45_000
            ),
            ApartmentMonthData(
                year: 2026,
                month: 10,
                rent: 35_000,
                capitalRepair: 611.89,
                utilities: 5_181.34,
                electricity: 1_809.31,
                paid: 42_600
            ),
        ]
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("apartment-\(UUID().uuidString).xlsx")
        defer { try? FileManager.default.removeItem(at: url) }

        try ApartmentXLSXCodec.export(months: source, to: url)
        let imported = try ApartmentXLSXCodec.importFile(from: url)
        XCTAssertEqual(imported.count, 2)
        XCTAssertEqual(imported[0].rent, 35_000)
        XCTAssertEqual(imported[0].capitalRepair, 611.89, accuracy: 0.001)
        XCTAssertEqual(imported[0].utilities, 6_184.68, accuracy: 0.001)
        XCTAssertEqual(imported[0].electricity, 3_415.42, accuracy: 0.001)
        XCTAssertEqual(imported[0].paid, 45_000)
    }
}
