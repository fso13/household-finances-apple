import SwiftData
import SwiftUI
import FinancesCore

struct IncomeEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let existing: IncomeEntry?
    @State private var draft: IncomeDraft

    init(existing: IncomeEntry?) {
        self.existing = existing
        _draft = State(initialValue: IncomeDraft(entry: existing))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                IconTile(symbol: draft.type.icon, tint: draft.type.color, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(existing == nil ? "Новая выплата" : "Изменить выплату")
                        .font(.title3.weight(.semibold))
                    Text(draft.type.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(18)

            Divider()

            Form {
                Section("Выплата") {
                    TextField(
                        "Сумма, ₽",
                        value: $draft.amount,
                        format: .number.precision(.fractionLength(0...2))
                    )
                    .monospacedDigit()

                    Picker("Тип выплаты", selection: $draft.type) {
                        ForEach(IncomeType.allCases) { type in
                            Label(type.title, systemImage: type.icon).tag(type)
                        }
                    }

                    DatePicker("Дата", selection: $draft.date, displayedComponents: .date)
                }

                Section("Детали") {
                    TextField("Работодатель", text: $draft.employer)

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
        .frame(width: 460, height: 500)
    }

    private func save() {
        let amount = draft.amount
        let date = draft.date.startOfDay
        do {
            if let existing {
                existing.amount = amount
                existing.date = date
                existing.type = draft.type
                existing.employer = draft.employer
                existing.note = draft.note
            } else {
                context.insert(
                    IncomeEntry(
                        amount: amount,
                        date: date,
                        type: draft.type,
                        employer: draft.employer,
                        note: draft.note
                    ))
            }
            try Persistence.save(context, operation: "income.save")
            dismiss()
        } catch {
            ErrorCenter.shared.report(error)
        }
    }
}

private struct IncomeDraft {
    var amount: Double = 0
    var date: Date = .now
    var type: IncomeType = .salary
    var employer: String = ""
    var note: String = ""

    init(entry: IncomeEntry?) {
        guard let entry else { return }
        amount = entry.amount
        date = entry.date
        type = entry.type
        employer = entry.employer
        note = entry.note
    }
}
