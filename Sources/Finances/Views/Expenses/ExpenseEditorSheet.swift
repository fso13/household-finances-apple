import SwiftData
import SwiftUI

struct ExpenseEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let existing: ExpenseEntry?
    @State private var draft: ExpenseDraft

    init(existing: ExpenseEntry?) {
        self.existing = existing
        _draft = State(initialValue: ExpenseDraft(entry: existing))
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
                        ForEach(ExpenseCategory.allCases) { category in
                            Label(category.title, systemImage: category.icon).tag(category)
                        }
                    }

                    DatePicker("Дата", selection: $draft.date, displayedComponents: .date)
                }

                Section("Детали") {
                    TextField("Комментарий", text: $draft.note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Text("Сумма должна быть больше нуля")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .opacity(draft.amount > 0 ? 0 : 1)
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
                .disabled(draft.amount <= 0)
            }
            .padding(16)
        }
        .frame(width: 460, height: 460)
    }

    private func save() {
        let amount = draft.amount
        let date = draft.date.startOfDay
        if let existing {
            existing.amount = amount
            existing.date = date
            existing.category = draft.category
            existing.note = draft.note
        } else {
            context.insert(ExpenseEntry(
                amount: amount,
                date: date,
                category: draft.category,
                note: draft.note
            ))
        }
        try? context.save()
        dismiss()
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
