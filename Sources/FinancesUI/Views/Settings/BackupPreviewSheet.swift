import FinancesCore
import SwiftData
import SwiftUI

struct BackupPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let envelope: BackupEnvelope
    let context: ModelContext
    let onImported: (RestoreSummary) -> Void

    @State private var mode: RestoreMode = .merge
    @State private var isImporting = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                IconTile(symbol: "shippingbox.fill", tint: .orange, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Восстановление из бэкапа")
                        .font(.title3.weight(.semibold))
                    Text(MonthFormat.day(envelope.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(18)

            Divider()

            Form {
                Section("Содержимое") {
                    backupRow("Доходы", envelope.data.incomes.count)
                    backupRow("Расходы", envelope.data.expenses.count)
                    backupRow("Регулярные платежи", envelope.data.recurring.count)
                    backupRow("Подписки", envelope.data.subscriptions.count)
                    backupRow("Бюджеты", envelope.data.budgets?.count ?? 0)
                    backupRow("Цели", envelope.data.goals?.count ?? 0)
                    backupRow("Категории", envelope.data.customCategories?.count ?? 0)
                    backupRow("Периоды платежей", envelope.data.periods?.count ?? 0)
                    backupRow("Настройки платежей", envelope.data.recurringDetails?.count ?? 0)
                    backupRow("История сумм", envelope.data.priceChanges?.count ?? 0)
                    backupRow("Правила категоризации", envelope.data.categoryRules?.count ?? 0)
                    HStack {
                        Text("Версия")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(envelope.appVersion) · схема \(envelope.schemaVersion)")
                            .monospacedDigit()
                    }
                }

                Section("Режим импорта") {
                    Picker("Режим", selection: $mode) {
                        ForEach(RestoreMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)

                    Text(
                        mode == .replace
                            ? "Текущие записи будут заменены. Перед этим автоматически создастся резервная копия."
                            : "Добавятся только записи, которых ещё нет. Совпадения определяются по дате, сумме и описанию."
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Section {
                    Text("Формат: finances.backup v\(envelope.formatVersion). Не редактируйте файл вручную.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
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
                    importBackup()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(isImporting || envelope.data.totalCount == 0)
            }
            .padding(16)
        }
        .frame(width: 520, height: 560)
    }

    private func backupRow(_ title: String, _ count: Int) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(count)")
                .monospacedDigit()
                .fontWeight(.medium)
        }
    }

    private func importBackup() {
        isImporting = true
        do {
            let summary = try BackupCodec.restore(envelope, mode: mode, context: context)
            onImported(summary)
            dismiss()
        } catch {
            ErrorCenter.shared.report(error)
            isImporting = false
        }
    }
}
