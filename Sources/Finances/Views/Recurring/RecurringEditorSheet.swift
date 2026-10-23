import SwiftData
import SwiftUI

struct RecurringEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let existing: RecurringPayment?
    @State private var draft: RecurringDraft

    init(existing: RecurringPayment?) {
        self.existing = existing
        _draft = State(initialValue: RecurringDraft(payment: existing))
    }

    private var payable: Double {
        draft.rounding.apply(draft.baseAmount, step: draft.roundingStep)
    }

    private var roundingDelta: Double {
        payable - draft.baseAmount
    }

    private var stepOptions: [Double] {
        var values: [Double] = [1, 5, 10, 50, 100, 500, 1_000]
        if !values.contains(draft.roundingStep) {
            values.append(draft.roundingStep)
        }
        return values.sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                IconTile(symbol: draft.category.icon, tint: draft.category.color, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(existing == nil ? "Новый обязательный платёж" : "Изменить платёж")
                        .font(.title3.weight(.semibold))
                    Text("Квартира, гараж, коммуналка или другой регулярный платёж")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(18)

            Divider()

            Form {
                Section("Платёж") {
                    TextField("Название", text: $draft.title, prompt: Text("Например, аренда квартиры"))

                    Picker("Категория", selection: $draft.category) {
                        ForEach(ExpenseCategory.allCases) { category in
                            Label(category.title, systemImage: category.icon).tag(category)
                        }
                    }

                    TextField(
                        "Базовая сумма, ₽",
                        value: $draft.baseAmount,
                        format: .number.precision(.fractionLength(0...2))
                    )
                    .monospacedDigit()

                    Picker("Периодичность", selection: $draft.frequency) {
                        ForEach(PaymentFrequency.allCases) { frequency in
                            Text(frequency.title).tag(frequency)
                        }
                    }

                    Picker("День платежа", selection: $draft.dayOfMonth) {
                        ForEach(1...28, id: \.self) { day in
                            Text("\(day)-е число").tag(day)
                        }
                    }

                    DatePicker("Первый платёж", selection: $draft.startDate, displayedComponents: .date)

                    Toggle("Платёж активен", isOn: $draft.isActive)
                }

                Section("Округление выплат") {
                    Picker("Правило", selection: $draft.rounding) {
                        ForEach(RoundingRule.allCases) { rule in
                            Label(rule.title, systemImage: rule.icon).tag(rule)
                        }
                    }

                    if draft.rounding != .none {
                        Picker("Шаг округления", selection: $draft.roundingStep) {
                            ForEach(stepOptions, id: \.self) { step in
                                Text("\(Int(step)) ₽").tag(step)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Итого к оплате")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(Fmt.money(payable))
                                .font(.title3.weight(.bold))
                                .monospacedDigit()
                        }

                        if draft.rounding != .none {
                            HStack {
                                Text("Базовая сумма \(Fmt.money(draft.baseAmount))")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Spacer()
                                Text(
                                    abs(roundingDelta) < 0.005
                                        ? "округление не меняет сумму"
                                        : "округление \(Fmt.signedMoney(roundingDelta))"
                                )
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(roundingDelta == 0 ? Color.secondary : Color.orange)
                            }
                        }

                        Text(draft.rounding.description(step: draft.roundingStep))
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if draft.frequency != .monthly {
                            Text("В пересчёте на месяц ≈ \(Fmt.money(payable / Double(draft.frequency.months)))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }

                Section("Заметка") {
                    TextField(
                        "Например, как считает арендодатель",
                        text: $draft.note,
                        axis: .vertical
                    )
                    .lineLimit(2...4)
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

                Button(existing == nil ? "Добавить" : "Сохранить") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.baseAmount <= 0)
            }
            .padding(16)
        }
        .frame(width: 500, height: 700)
    }

    private func save() {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing {
            existing.title = title
            existing.category = draft.category
            existing.baseAmount = draft.baseAmount
            existing.rounding = draft.rounding
            existing.roundingStep = draft.roundingStep
            existing.frequency = draft.frequency
            existing.dayOfMonth = draft.dayOfMonth
            existing.startDate = draft.startDate.startOfDay
            existing.isActive = draft.isActive
            existing.note = draft.note
        } else {
            context.insert(RecurringPayment(
                title: title,
                category: draft.category,
                baseAmount: draft.baseAmount,
                rounding: draft.rounding,
                roundingStep: draft.roundingStep,
                frequency: draft.frequency,
                dayOfMonth: draft.dayOfMonth,
                startDate: draft.startDate,
                isActive: draft.isActive,
                note: draft.note
            ))
        }
        try? context.save()
        dismiss()
    }
}

private struct RecurringDraft {
    var title: String = ""
    var category: ExpenseCategory = .rent
    var baseAmount: Double = 0
    var rounding: RoundingRule = .none
    var roundingStep: Double = 100
    var frequency: PaymentFrequency = .monthly
    var dayOfMonth: Int = 10
    var startDate: Date = .now
    var isActive: Bool = true
    var note: String = ""

    init(payment: RecurringPayment?) {
        guard let payment else { return }
        title = payment.title
        category = payment.category
        baseAmount = payment.baseAmount
        rounding = payment.rounding
        roundingStep = payment.roundingStep
        frequency = payment.frequency
        dayOfMonth = payment.dayOfMonth
        startDate = payment.startDate
        isActive = payment.isActive
        note = payment.note
    }
}
