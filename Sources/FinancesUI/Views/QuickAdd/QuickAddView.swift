import FinancesCore
import SwiftData
import SwiftUI

package struct QuickAddView: View {
    package init() {}

    @Environment(\.modelContext) private var context
    @Environment(\.dismissWindow) private var dismissWindow
    @EnvironmentObject private var appState: AppState

    @State private var kind: QuickAddKind = .expense
    @State private var amount: Double = 0
    @State private var category: ExpenseCategory = .food
    @State private var incomeType: IncomeType = .salary
    @State private var date = Date()
    @State private var note = ""
    @State private var errorMessage: String?

    package var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                IconTile(
                    symbol: kind == .expense ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                    tint: kind == .expense ? .orange : .green,
                    size: 34
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text("Быстрый ввод")
                        .font(.title3.weight(.semibold))
                    Text("Запись сразу попадёт в обзор месяца")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)

            Divider()

            Form {
                Picker("Тип", selection: $kind) {
                    Text("Расход").tag(QuickAddKind.expense)
                    Text("Доход").tag(QuickAddKind.income)
                }
                .pickerStyle(.segmented)

                TextField(
                    "Сумма, ₽",
                    value: $amount,
                    format: .number.precision(.fractionLength(0...2))
                )
                .font(.title2.weight(.semibold))
                .monospacedDigit()

                if kind == .expense {
                    Picker("Категория", selection: $category) {
                        ForEach(ExpenseCategory.all) { category in
                            Label(category.title, systemImage: category.icon).tag(category)
                        }
                    }
                } else {
                    Picker("Тип выплаты", selection: $incomeType) {
                        ForEach(IncomeType.allCases) { type in
                            Label(type.title, systemImage: type.icon).tag(type)
                        }
                    }
                }

                DatePicker("Дата", selection: $date, in: ...Date(), displayedComponents: .date)
                TextField("Комментарий (#тег)", text: $note, axis: .vertical)
                    .lineLimit(2...4)
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
                Button("Отмена") {
                    dismissWindow(id: "quickAdd")
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Записать") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(amount <= 0)
            }
            .padding(16)
        }
        .frame(width: 430, height: 470)
        .onAppear(perform: consumePending)
        .onChange(of: appState.pendingQuickAdd) { _, _ in
            consumePending()
        }
    }

    private func consumePending() {
        guard let pending = appState.pendingQuickAdd else { return }
        kind = pending
        appState.pendingQuickAdd = nil
    }

    private func save() {
        guard amount > 0 else {
            errorMessage = "Сумма должна быть больше нуля."
            return
        }
        do {
            if kind == .expense {
                context.insert(
                    ExpenseEntry(
                        amount: amount,
                        date: date,
                        category: category,
                        note: note
                    )
                )
            } else {
                context.insert(
                    IncomeEntry(
                        amount: amount,
                        date: date,
                        type: incomeType,
                        note: note
                    )
                )
            }
            try Persistence.save(context, operation: "quickAdd.save")
            dismissWindow(id: "quickAdd")
        } catch {
            ErrorCenter.shared.report(error)
            errorMessage = "Не удалось сохранить запись."
        }
    }
}
