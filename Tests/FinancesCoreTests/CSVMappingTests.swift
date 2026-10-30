import XCTest
@testable import FinancesCore

final class CSVMappingTests: XCTestCase {
    private let headers = [
        "Название продукта", "Дата и время операции", "Списание/Зачисление",
        "Сумма в валюте операции", "Категория", "Наименование операции",
        "Наименование ТСП", "Комментарий к операции", "Статус операции",
    ]

    private let rows = [
        [
            "Карта", "28.10.2026 23:56", "Списание", "-250,0", "Маркетплейсы",
            "OZON", "YM*ozon", "", "Выполнено",
        ],
        [
            "Карта", "27.10.2026 18:47", "Списание", "-968,68", "Супермаркеты",
            "Metro", "METRO STORE 1015", "", "Выполнено",
        ],
        [
            "Счёт", "25.10.2026 10:00", "Зачисление", "150000,0", "",
            "Зарплата", "", "", "Выполнено",
        ],
        [
            "Карта", "24.10.2026 10:00", "Списание", "-500,0", "",
            "Отмена", "", "", "Отменено",
        ],
        [
            "Карта", "23.10.2026 10:00", "Списание", "-500,0", "Между счетами",
            "Перевод", "", "", "Выполнено",
        ],
    ]

    func testAutomaticMappingAndPreview() throws {
        let mapping = CSVColumnMapping.automatic(headers: headers)
        XCTAssertTrue(mapping.hasHeader)
        XCTAssertEqual(mapping.kind, .mixed)
        XCTAssertEqual(mapping.direction, 2)
        XCTAssertEqual(mapping.income.date, 1)
        XCTAssertEqual(mapping.income.amount, 3)
        XCTAssertEqual(mapping.income.employer, 5)
        XCTAssertEqual(mapping.expense.date, 1)
        XCTAssertEqual(mapping.expense.amount, 3)
        XCTAssertEqual(mapping.expense.category, 4)
        XCTAssertEqual(mapping.expense.note, 5)
        XCTAssertEqual(mapping.status, 8)

        let table = CSVTable(name: "statement.csv", headers: headers, rows: rows)
        let preview = try CSVColumnImporter.preview(table: table, mapping: mapping)
        XCTAssertEqual(preview.incomes.count, 1)
        XCTAssertEqual(preview.expenses.count, 2)
        XCTAssertEqual(preview.skippedSections, 2)
        XCTAssertEqual(preview.expenses.last?.category, ExpenseCategory.food.rawValue)
        XCTAssertEqual(preview.incomes.first?.type, IncomeType.salary.rawValue)
    }

    func testNoHeaderUsesColumnNumbersAndFirstRowAsData() throws {
        let table = CSVTable(
            name: "no-header.csv",
            allRows: [
                ["28.10.2026", "-250,0", "OZON"],
                ["27.10.2026", "-968,68", "Metro"],
            ]
        )
        var mapping = CSVColumnMapping()
        mapping.hasHeader = false
        mapping.kind = .expense
        mapping.expense = CSVFieldMapping(
            date: 0, amount: 1, type: nil, employer: nil, category: nil, note: 2
        )

        let preview = try CSVColumnImporter.preview(table: table, mapping: mapping)
        XCTAssertEqual(preview.expenses.count, 2)
        XCTAssertEqual(preview.errors.count, 0)
    }

    func testDateWithTimeIsParsed() {
        let date = CSVCodec.parseDate("28.10.2026 23:56")
        XCTAssertNotNil(date)
        XCTAssertEqual(date.map { Calendar.current.component(.day, from: $0) }, 28)
    }
}
