import XCTest
@testable import FinancesCore

final class CSVSettingsTests: XCTestCase {
    func testMappingPresetRoundTrip() {
        let table = CSVTable(
            name: "test.csv",
            headers: ["Дата", "Сумма", "Категория"],
            rows: []
        )
        var mapping = CSVColumnMapping()
        mapping.kind = .expense
        mapping.hasHeader = true
        mapping.expense = CSVFieldMapping(
            date: 0, amount: 1, type: nil, employer: nil, category: 2, note: 2
        )
        mapping.skipTransfers = false
        CSVMappingStore.shared.save(mapping, for: table)

        let loaded = CSVMappingStore.shared.load(for: table, hasHeader: true)
        XCTAssertEqual(loaded?.kind, .expense)
        XCTAssertEqual(loaded?.expense.category, 2)
        XCTAssertEqual(loaded?.skipTransfers, false)
    }

    func testExportSettingsRoundTrip() {
        var settings = CSVExportSettings()
        settings.delimiter = .comma
        settings.includeIncomes = false
        settings.includeBOM = false
        settings.save()

        let loaded = CSVExportSettings.load()
        XCTAssertEqual(loaded.delimiter, .comma)
        XCTAssertFalse(loaded.includeIncomes)
        XCTAssertFalse(loaded.includeBOM)

        CSVExportSettings().save()
    }
}
