import FinancesCore
import SwiftData
import SwiftUI

struct BudgetEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query private var budgets: [Budget]

    let existing: Budget?
    let month: Date

    @State private var draft: BudgetDraft

    init(existing: Budget?, month: Date) {
        self.existing = existing
        self.month = month
        _draft = State(initialValue: BudgetDraft(budget: existing))
    }

    private var validationMessage: String? {
        InputValidation.amountError(draft.limit)
            ?? InputValidation.noteError(draft.note)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                IconTile(symbol: draft.category.icon, tint: draft.category.color, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(existing == nil ? "Новый бюджет" : "Изменить бюджет")
                        .font(.title3.weight(.semibold))
                    Text(MonthFormat.monthTitle(month))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(18)

            Divider()

            Form {
                Section("Лимит") {
                    Picker("Категория", selection: $draft.category) {
                        ForEach(ExpenseCategory.allCases) { category in
                            Label(category.title, systemImage: category.icon).tag(category)
                        }
                    }

                    TextField(
                        "Лимит, ₽",
                        value: $draft.limit,
                        format: .number.precision(.fractionLength(0...2))
                    )
                    .monospacedDigit()

                    TextField("Комментарий", text: $draft.note, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    Text("Бюджет действует только на выбранный месяц. Если лимит уже есть, он будет обновлён.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                if let validationMessage {
                    Text(validationMessage)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
                Button("Отмена") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button(existing == nil ? "Добавить" : "Сохранить") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(validationMessage != nil)
            }
            .padding(16)
        }
        .frame(width: 470, height: 430)
    }

    private func save() {
        guard validationMessage == nil else { return }

        let duplicate = budgets.first {
            $0 !== existing
                && $0.category == draft.category
                && $0.year == month.year
                && $0.month == month.month
        }

        do {
            if let existing {
                if let duplicate {
                    duplicate.limit = draft.limit
                    duplicate.note = draft.note
                    context.delete(existing)
                } else {
                    existing.category = draft.category
                    existing.limit = draft.limit
                    existing.note = draft.note
                }
            } else if let duplicate {
                duplicate.limit = draft.limit
                duplicate.note = draft.note
            } else {
                context.insert(
                    Budget(
                        category: draft.category,
                        year: month.year,
                        month: month.month,
                        limit: draft.limit,
                        note: draft.note
                    )
                )
            }
            try Persistence.save(context, operation: "budget.save")
            dismiss()
        } catch {
            ErrorCenter.shared.report(error)
        }
    }
}

private struct BudgetDraft {
    var category: ExpenseCategory = .food
    var limit: Double = 0
    var note: String = ""

    init(budget: Budget?) {
        guard let budget else { return }
        category = budget.category
        limit = budget.limit
        note = budget.note
    }
}
