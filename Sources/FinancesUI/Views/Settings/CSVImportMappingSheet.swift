import FinancesCore
import SwiftData
import SwiftUI

struct CSVImportMappingSheet: View {
    @Environment(\.dismiss) private var dismiss

    let table: CSVTable
    let context: ModelContext
    let onImported: (CSVImportSummary) -> Void

    @State private var mapping: CSVColumnMapping
    @State private var preview: CSVImportPreview?
    @State private var errorMessage: String?

    init(
        table: CSVTable,
        context: ModelContext,
        onImported: @escaping (CSVImportSummary) -> Void
    ) {
        self.table = table
        self.context = context
        self.onImported = onImported
        _mapping = State(initialValue: .automatic(headers: table.headers))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                IconTile(symbol: "tablecells", tint: .teal, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Маппинг колонок CSV")
                        .font(.title3.weight(.semibold))
                    Text("\(table.name) · \(mapping.hasHeader ? table.rowCount : table.allRows.count) строк")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Автонастройка") {
                    mapping = .automatic(headers: table.headers)
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .disabled(!mapping.hasHeader)
            }
            .padding(18)

            Divider()

            Form {
                Section("Файл") {
                    Toggle("Первая строка — шапка", isOn: $mapping.hasHeader)
                    Picker("Что импортировать", selection: $mapping.kind) {
                        ForEach(CSVImportKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    if mapping.kind == .mixed {
                        columnPicker("Списание/Зачисление", selection: $mapping.direction)
                    }
                }

                if mapping.kind == .income || mapping.kind == .mixed {
                    Section("Доходы — 5 полей") {
                        columnPicker("Дата", selection: $mapping.income.date)
                        columnPicker("Сумма", selection: $mapping.income.amount)
                        columnPicker("Тип выплаты", selection: $mapping.income.type)
                        columnPicker("Работодатель", selection: $mapping.income.employer)
                        columnPicker("Заметка", selection: $mapping.income.note)
                    }
                }

                if mapping.kind == .expense || mapping.kind == .mixed {
                    Section("Расходы — 4 поля") {
                        columnPicker("Дата", selection: $mapping.expense.date)
                        columnPicker("Сумма", selection: $mapping.expense.amount)
                        columnPicker("Категория", selection: $mapping.expense.category)
                        columnPicker("Заметка", selection: $mapping.expense.note)
                    }
                }

                Section("Служебное") {
                    columnPicker("Статус операции", selection: $mapping.status)
                    Toggle("Пропускать переводы между счетами", isOn: $mapping.skipTransfers)
                    if mapping.skipTransfers {
                        TextField(
                            "Игнорировать, если содержит",
                            text: $mapping.ignoreKeywords,
                            axis: .vertical
                        )
                        .lineLimit(2...3)
                        Text("Слова через запятую. Например: между счетами, перевод с карты.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                if !sampleRows.isEmpty {
                    Section("Пример строк") {
                        ForEach(Array(sampleRows.enumerated()), id: \.offset) { _, row in
                            HStack(spacing: 8) {
                                Text(sampleValue(row, mapping.income.date ?? mapping.expense.date) ?? "—")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 105, alignment: .leading)
                                Text(sampleValue(row, mapping.income.amount ?? mapping.expense.amount) ?? "—")
                                    .font(.caption2.weight(.semibold))
                                    .monospacedDigit()
                                    .frame(width: 75, alignment: .trailing)
                                Text(sampleValue(row, mapping.income.note ?? mapping.expense.note) ?? "—")
                                    .font(.caption2)
                                    .lineLimit(1)
                                Spacer()
                            }
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Text(
                        "Для доходов доступны 5 полей приложения, для расходов — 4. Если шапки нет, вместо названий показываются номера колонок."
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Отмена") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Предпросмотр") { makePreview() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canPreview)
            }
            .padding(16)
        }
        .frame(width: 660, height: 760)
        .sheet(item: $preview) { preview in
            CSVImportPreviewSheet(
                preview: preview,
                context: context,
                onImported: { summary in
                    self.preview = nil
                    dismiss()
                    onImported(summary)
                }
            )
        }
    }

    private var canPreview: Bool {
        switch mapping.kind {
        case .income:
            return mapping.income.date != nil && mapping.income.amount != nil
        case .expense:
            return mapping.expense.date != nil && mapping.expense.amount != nil
        case .mixed:
            return mapping.income.date != nil && mapping.income.amount != nil
                && mapping.expense.date != nil && mapping.expense.amount != nil
                && mapping.direction != nil
        }
    }

    private var sampleRows: [[String]] {
        Array(table.dataRows(hasHeader: mapping.hasHeader).prefix(4))
    }

    private func columnPicker(_ title: String, selection: Binding<Int?>) -> some View {
        Picker(title, selection: selection) {
            Text("Не использовать").tag(Int?.none)
            ForEach(0..<max(table.columnCount, table.headers.count), id: \.self) { index in
                Text(columnTitle(index)).tag(Int?.some(index))
            }
        }
    }

    private func columnTitle(_ index: Int) -> String {
        if mapping.hasHeader, table.headers.indices.contains(index) {
            let header = table.headers[index].trimmingCharacters(in: .whitespacesAndNewlines)
            if !header.isEmpty {
                return header
            }
        }
        return "Колонка \(index + 1)"
    }

    private func sampleValue(_ row: [String], _ index: Int?) -> String? {
        guard let index, row.indices.contains(index) else { return nil }
        let value = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func makePreview() {
        do {
            let result = try CSVColumnImporter.preview(table: table, mapping: mapping)
            guard result.totalRows > 0 else {
                errorMessage = "Не удалось найти операции. Проверьте колонки даты, суммы и направления."
                return
            }
            errorMessage = nil
            preview = result
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
