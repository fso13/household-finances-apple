import FinancesCore
import SwiftData
import SwiftUI

struct CSVImportPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let preview: CSVImportPreview
    let context: ModelContext
    let onImported: (CSVImportSummary) -> Void

    @State private var isImporting = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                IconTile(symbol: "tablecells", tint: .teal, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Импорт CSV")
                        .font(.title3.weight(.semibold))
                    Text("Колонки распознаны автоматически")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(18)

            Divider()

            Form {
                Section("Что будет импортировано") {
                    countRow("Доходы", preview.incomes.count, .green)
                    countRow("Расходы", preview.expenses.count, .orange)
                    if preview.skippedSections > 0 {
                        HStack {
                            Text("Пропущено служебных строк")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(preview.skippedSections)")
                                .monospacedDigit()
                        }
                    }
                    if !preview.errors.isEmpty {
                        HStack {
                            Text("Ошибки")
                                .foregroundStyle(.red)
                            Spacer()
                            Text("\(preview.errors.count)")
                                .foregroundStyle(.red)
                                .monospacedDigit()
                        }
                    }
                }

                if !preview.rows.isEmpty {
                    Section("Предпросмотр") {
                        ForEach(preview.rows.prefix(8)) { row in
                            HStack(spacing: 8) {
                                Text(MonthFormat.compactDay(row.date))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 58, alignment: .leading)
                                Text(row.kind)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text(Fmt.money(row.amount))
                                    .font(.caption.weight(.medium))
                                    .monospacedDigit()
                            }
                        }
                    }
                }

                if !preview.errors.isEmpty {
                    Section("Строки с ошибками") {
                        ForEach(Array(preview.errors.prefix(6).enumerated()), id: \.offset) { _, error in
                            Text(error)
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                        if preview.errors.count > 6 {
                            Text("…и ещё \(preview.errors.count - 6)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Section {
                    Text(
                        "Перед импортом автоматически создастся резервная копия. Импорт добавляет записи и не удаляет текущие данные."
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Отмена") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Импортировать") {
                    performImport()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(isImporting || preview.totalRows == 0)
            }
            .padding(16)
        }
        .frame(width: 560, height: 640)
    }

    private func countRow(_ title: String, _ count: Int, _ tint: Color) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(count)")
                .fontWeight(.semibold)
                .foregroundStyle(tint)
                .monospacedDigit()
        }
    }

    private func performImport() {
        isImporting = true
        do {
            let summary = try CSVImporter.performImport(preview, context: context)
            onImported(summary)
            dismiss()
        } catch {
            ErrorCenter.shared.report(error)
            isImporting = false
        }
    }
}
