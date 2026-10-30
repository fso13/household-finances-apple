import SwiftData
import XCTest
@testable import FinancesCore

@MainActor
final class CSVTests: XCTestCase {
    func testCSVRoundTripWithQuotesAndNewlines() throws {
        let rows = [
            ["Дата", "Сумма", "Комментарий"],
            ["2026-10-01", "1000.50", "обычная строка"],
            ["2026-10-02", "2000", "с точкой; и \"кавычками\""],
            ["2026-10-03", "3000", "первая строка\nвторая строка"],
        ]
        let data = CSVCodec.encode(rows: rows)
        let parsed = try CSVCodec.parse(data)
        XCTAssertEqual(parsed.count, 4)
        XCTAssertEqual(parsed[2][2], "с точкой; и \"кавычками\"")
        XCTAssertEqual(parsed[3][2], "первая строка\nвторая строка")
    }

    func testCSVParsesCommaDelimiter() throws {
        let text = "Дата,Сумма,Комментарий\n2026-10-01,1000.50,тест\n"
        let parsed = try CSVCodec.parse(Data(text.utf8))
        XCTAssertEqual(parsed[1], ["2026-10-01", "1000.50", "тест"])
    }

    func testMachineFormats() {
        XCTAssertEqual(CSVCodec.machineDate(makeDate(2026, 10, 5)), "2026-10-05")
        XCTAssertEqual(CSVCodec.machineNumber(1_234.5), "1234.50")
        XCTAssertEqual(CSVCodec.parseNumber("1 234,50 ₽"), 1_234.5)
        XCTAssertEqual(CSVCodec.parseDate("05.10.2026")?.components.day, 5)
        XCTAssertEqual(CSVCodec.parseDate("2026-10-05")?.components.day, 5)
    }

    func testPreviewRecognizesExportHeaders() throws {
        let rows = [
            ["Раздел", "Дата", "Тип / категория", "Сумма", "Примечание"],
            ["Доход", "2026-10-01", "Зарплата", "1000.00", "Оклад"],
            ["Расход", "2026-10-02", "Продукты", "500.50", "Магазин"],
            ["Обязательный платёж", "2026-10-03", "Квартира", "47300.00", "Аренда"],
            ["Расход", "не дата", "Продукты", "100", "Ошибка"],
        ]
        let data = CSVCodec.encode(rows: rows)
        let preview = try CSVImporter.preview(data: data)

        XCTAssertEqual(preview.incomes.count, 1)
        XCTAssertEqual(preview.expenses.count, 1)
        XCTAssertEqual(preview.skippedSections, 1)
        XCTAssertEqual(preview.errors.count, 1)
        XCTAssertEqual(preview.incomes.first?.amount, 1_000)
        XCTAssertEqual(preview.expenses.first?.amount, 500.5)
    }

    func testImportAddsRowsAndCreatesBackup() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: IncomeEntry.self,
            ExpenseEntry.self,
            RecurringPayment.self,
            Subscription.self,
            Budget.self,
            SavingsGoal.self,
            PaymentPeriod.self,
            RecurringDetail.self,
            RecurringPriceChange.self,
            ApartmentMonth.self,
            configurations: configuration
        )
        let context = ModelContext(container)

        let rows = [
            ["Раздел", "Дата", "Тип / категория", "Сумма", "Примечание"],
            ["Доход", "2026-10-01", "Зарплата", "1000.00", "Оклад"],
            ["Расход", "2026-10-02", "Продукты", "500.50", "Магазин"],
        ]
        let preview = try CSVImporter.preview(data: CSVCodec.encode(rows: rows))
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("finances-csv-\(UUID().uuidString)")
        let summary = try CSVImporter.performImport(
            preview,
            context: context,
            automaticBackupFolder: folder
        )

        XCTAssertEqual(summary.inserted, 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<IncomeEntry>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExpenseEntry>()), 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path))
    }
}
