import FinancesCore
import SwiftData
import SwiftUI

struct GoalEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let existing: SavingsGoal?
    @State private var draft: GoalDraft

    init(existing: SavingsGoal?) {
        self.existing = existing
        _draft = State(initialValue: GoalDraft(goal: existing))
    }

    private var validationMessage: String? {
        InputValidation.titleError(draft.name)
            ?? InputValidation.amountError(draft.target)
            ?? (draft.saved < 0 ? "Накоплено не может быть отрицательным." : nil)
            ?? InputValidation.noteError(draft.note)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                IconTile(symbol: "flag.fill", tint: .pink, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(existing == nil ? "Новая цель" : "Изменить цель")
                        .font(.title3.weight(.semibold))
                    Text("Накопления на конкретную покупку или подушку")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(18)

            Divider()

            Form {
                Section("Цель") {
                    TextField("Название", text: $draft.name, prompt: Text("Например, отпуск"))

                    TextField(
                        "Сумма цели, ₽",
                        value: $draft.target,
                        format: .number.precision(.fractionLength(0...2))
                    )
                    .monospacedDigit()

                    TextField(
                        "Уже накоплено, ₽",
                        value: $draft.saved,
                        format: .number.precision(.fractionLength(0...2))
                    )
                    .monospacedDigit()

                    Toggle("Указать срок", isOn: $draft.hasDeadline)
                    if draft.hasDeadline {
                        DatePicker("Достичь к", selection: $draft.deadline, displayedComponents: .date)
                    }

                    Toggle("Цель активна", isOn: $draft.isActive)
                }

                Section("Заметка") {
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
        .frame(width: 480, height: 540)
    }

    private func save() {
        guard validationMessage == nil else { return }

        let trimmed = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let deadline = draft.hasDeadline ? draft.deadline.startOfDay : nil

        do {
            if let existing {
                existing.name = trimmed
                existing.target = draft.target
                existing.saved = draft.saved
                existing.deadline = deadline
                existing.note = draft.note
                existing.isActive = draft.isActive
            } else {
                context.insert(
                    SavingsGoal(
                        name: trimmed,
                        target: draft.target,
                        saved: draft.saved,
                        deadline: deadline,
                        note: draft.note,
                        isActive: draft.isActive
                    )
                )
            }
            try Persistence.save(context, operation: "goal.save")
            dismiss()
        } catch {
            ErrorCenter.shared.report(error)
        }
    }
}

private struct GoalDraft {
    var name: String = ""
    var target: Double = 0
    var saved: Double = 0
    var hasDeadline: Bool = true
    var deadline: Date = Date().addingMonths(6)
    var note: String = ""
    var isActive: Bool = true

    init(goal: SavingsGoal?) {
        guard let goal else { return }
        name = goal.name
        target = goal.target
        saved = goal.saved
        hasDeadline = goal.deadline != nil
        deadline = goal.deadline ?? Date().addingMonths(6)
        note = goal.note
        isActive = goal.isActive
    }
}
