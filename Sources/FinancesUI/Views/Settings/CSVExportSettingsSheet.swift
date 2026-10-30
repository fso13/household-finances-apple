import FinancesCore
import SwiftData
import SwiftUI

struct CSVExportSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var settings = CSVExportSettings.load()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                IconTile(symbol: "square.and.arrow.up", tint: .teal, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Экспорт в CSV")
                        .font(.title3.weight(.semibold))
                    Text("Настройки сохранятся для следующих экспортов")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(18)

            Divider()

            Form {
                Section("Что экспортировать") {
                    Toggle("Доходы", isOn: $settings.includeIncomes)
                    Toggle("Расходы", isOn: $settings.includeExpenses)
                    Toggle("Регулярные платежи", isOn: $settings.includeRecurring)
                    Toggle("Подписки", isOn: $settings.includeSubscriptions)
                }

                Section("Формат") {
                    Picker("Разделитель", selection: $settings.delimiter) {
                        ForEach(CSVExportSettings.Delimiter.allCases) { delimiter in
                            Text(delimiter.title).tag(delimiter)
                        }
                    }
                    Toggle("Добавить BOM для Excel", isOn: $settings.includeBOM)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Отмена") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Экспортировать") {
                    settings.save()
                    do {
                        try Exporter.exportCSV(context: context, settings: settings)
                        dismiss()
                    } catch {
                        ErrorCenter.shared.report(error)
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(
                    !settings.includeIncomes && !settings.includeExpenses
                        && !settings.includeRecurring && !settings.includeSubscriptions
                )
            }
            .padding(16)
        }
        .frame(width: 480, height: 440)
    }
}
