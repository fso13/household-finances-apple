import XCTest
@testable import FinancesUI
@testable import FinancesCore

@MainActor
final class AnalyticsPDFTests: XCTestCase {
    func testPDFDataHasPDFHeader() {
        let data = AnalyticsReportData(
            period: "Октябрь 2026",
            income: 100_000,
            expense: 70_000,
            net: 30_000,
            savingsRate: 0.3,
            topExpenses: [],
            monthly: [],
            changes: [],
            generatedAt: Date()
        )
        let pdf = AnalyticsPDFExporter.pdfData(data)
        XCTAssertNotNil(pdf)
        XCTAssertGreaterThan(pdf?.count ?? 0, 100)
        XCTAssertEqual(String(data: pdf?.prefix(4) ?? Data(), encoding: .ascii), "%PDF")
    }
}
