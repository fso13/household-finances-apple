import SwiftData
import SwiftUI
import FinancesCore

struct ExpenseEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let existing: ExpenseEntry?
    @State private var draft: ExpenseDraft

    init(existing: ExpenseEntry?) {
        self.existing = existing
        _draft = State(initialValue: ExpenseDraft(entry: existing))
    }

    private var validationMessage: String? {
        InputValidation.amountError(draft.amount)
            ?? InputValidation.entryDateError(draft.date)
            ?? InputValidation.noteError(draft.note)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                IconTile(symbol: draft.category.icon, tint: draft.category.color, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(existing == nil ? "Новый расход" : "Изменить расход")
                        .font(.title3.weight(.semibold))
                    Text(draft.category.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(18)

            Divider()

            Form {
                Section("Расход") {
                    TextField(
                        "Сумма, ₽",
                        value: $draft.amount,
                        format: .number.precision(.fractionLength(0...2))
                    )
                    .monospacedDigit()

                    Picker("Категория", selection: $draft.category) {
                        ForEach(ExpenseCategory.all) { category in
                            Label(category.title, systemImage: category.icon).tag(category)
                        }
                    }

                    DatePicker("Дата", selection: $draft.date, in: ...Date(), displayedComponents: .date)
                }

                Section("Детали") {
                    TextField("Комментарий", text: $draft.note, axis: .vertical)
                        .lineLimit(2...4)
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
                Spacer()
                Button("Отмена") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(existing == nil ? "Добавить" : "Сохранить") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(validationMessage != nil)
            }
            .padding(16)
        }
        .frame(width: 460, height: 460)
    }

    private func save() {
        guard validationMessage == nil else { return }
        let amount = draft.amount
        let date = draft.date.startOfDay
        do {
            if let existing {
                existing.amount = amount
                existing.date = date
                existing.category = draft.category
                existing.note = draft.note
            } else {
                context.insert(
                    ExpenseEntry(
                        amount: amount,
                        date: date,
                        category: draft.category,
                        note: draft.note
                    ))
            }
            try Persistence.save(context, operation: "expense.save")
            dismiss()
        } catch {
            ErrorCenter.shared.report(error)
        }
    }
}

private struct ExpenseDraft {
    var amount: Double = 0
    var date: Date = .now
    var category: ExpenseCategory = .food
    var note: String = ""

    init(entry: ExpenseEntry?) {
        guard let entry else { return }
        amount = entry.amount
        date = entry.date
        category = entry.category
        note = entry.note
    }
}
