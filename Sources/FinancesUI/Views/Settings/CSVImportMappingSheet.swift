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
                    Text("\(table.name) · \(table.rows.count) строк · первая строка — заголовки")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Автонастройка") {
                    mapping = .automatic(headers: table.headers)
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
            .padding(18)

            Divider()

            Form {
                Section("Обязательные колонки") {
                    columnPicker("Дата", selection: $mapping.date)
                    columnPicker("Сумма", selection: $mapping.amount)
                    columnPicker("Списание/Зачисление", selection: $mapping.direction)
                }

                Section("Категории и описание") {
                    columnPicker("Категория", selection: $mapping.category)
                    columnPicker("Описание операции", selection: $mapping.description)
                    columnPicker("Контрагент / ТСП", selection: $mapping.merchant)
                    columnPicker("Комментарий", selection: $mapping.comment)
                }

                Section("Доходы и служебное") {
                    Toggle("Пропускать переводы между счетами", isOn: $mapping.skipTransfers)
                    columnPicker("Тип дохода", selection: $mapping.incomeType)
                    columnPicker("Работодатель", selection: $mapping.employer)
                    columnPicker("Статус операции", selection: $mapping.status)
                }

                if !sampleRows.isEmpty {
                    Section("Пример строк") {
                        ForEach(Array(sampleRows.enumerated()), id: \.offset) { _, row in
                            HStack(spacing: 8) {
                                Text(sampleValue(row, mapping.date) ?? "—")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 110, alignment: .leading)
                                Text(sampleValue(row, mapping.amount) ?? "—")
                                    .font(.caption2.weight(.semibold))
                                    .monospacedDigit()
                                    .frame(width: 80, alignment: .trailing)
                                Text(sampleValue(row, mapping.description) ?? sampleValue(row, mapping.merchant) ?? "—")
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
                        "Выберите, какие колонки файла соответствуют дате, сумме, направлению и описанию. Настройки можно менять перед каждым импортом."
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
                    .disabled(mapping.date == nil || mapping.amount == nil)
            }
            .padding(16)
        }
        .frame(width: 640, height: 620)
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

    private var sampleRows: [[String]] {
        Array(table.rows.prefix(4))
    }

    private func columnPicker(_ title: String, selection: Binding<Int?>) -> some View {
        Picker(title, selection: selection) {
            Text("Не использовать").tag(Int?.none)
            ForEach(table.headers.indices, id: \.self) { index in
                Text(table.headers[index]).tag(Int?.some(index))
            }
        }
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
