import FinancesCore
import SwiftData
import SwiftUI

struct CategoriesSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var expenses: [ExpenseEntry]
    @Query private var budgets: [Budget]

    @State private var categories: [CustomExpenseCategory] = []
    @State private var editor: EditorContext?
    @State private var pendingDelete: CustomExpenseCategory?

    private struct EditorContext: Identifiable {
        let id = UUID()
        let category: CustomExpenseCategory?
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                IconTile(symbol: "tag.fill", tint: .pink, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Пользовательские категории")
                        .font(.title3.weight(.semibold))
                    Text("Появятся в расходах, бюджетах и фильтрах")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    editor = EditorContext(category: nil)
                } label: {
                    Label("Добавить", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(18)

            Divider()

            if categories.isEmpty {
                EmptyStateView(
                    icon: "tag",
                    title: "Пока только встроенные категории",
                    message: "Добавьте свою категорию — например, «Спорт», «Питомцы» или «Обучение».",
                    actionTitle: "Добавить категорию"
                ) {
                    editor = EditorContext(category: nil)
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(categories) { category in
                            row(category)
                            Divider().padding(.leading, 62)
                        }
                    }
                }
            }

            Divider()

            HStack {
                Text("Удалённая категория остаётся в старых записях как «Категория».")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Готово") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 560, height: 600)
        .onAppear(perform: reload)
        .sheet(item: $editor) { context in
            CustomCategoryEditorSheet(existing: context.category)
        }
        .alert(
            "Удалить категорию?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { newValue in if !newValue { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { category in
            Button("Удалить", role: .destructive) {
                CustomCategoryCatalog.shared.remove(id: category.id)
                pendingDelete = nil
                reload()
            }
            Button("Отмена", role: .cancel) {
                pendingDelete = nil
            }
        } message: { category in
            Text(
                "«\(category.name)» исчезнет из выбора. В существующих записях останется raw-значение, но подпись станет «Категория»."
            )
        }
    }

    private func row(_ category: CustomExpenseCategory) -> some View {
        HStack(spacing: 12) {
            IconTile(symbol: category.icon, tint: category.tint.color, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.callout.weight(.medium))
                HStack(spacing: 6) {
                    if category.isMandatory {
                        TagBadge(text: "обязательная", color: .blue)
                    }
                    Text("\(usage(category)) записей · \(usage(category, in: budgets)) бюджетов")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Button {
                editor = EditorContext(category: category)
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Изменить категорию")

            Button(role: .destructive) {
                pendingDelete = category
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Удалить категорию")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func usage(_ category: CustomExpenseCategory) -> Int {
        usage(category, in: expenses)
    }

    private func usage(_ category: CustomExpenseCategory, in expenses: [ExpenseEntry]) -> Int {
        let raw = "custom:\(category.id.uuidString)"
        return expenses.filter { $0.category.rawValue == raw }.count
    }

    private func usage(_ category: CustomExpenseCategory, in budgets: [Budget]) -> Int {
        let raw = "custom:\(category.id.uuidString)"
        return budgets.filter { $0.category.rawValue == raw }.count
    }

    private func reload() {
        categories = CustomCategoryCatalog.shared.categories
    }
}

// MARK: - Редактор категории

private struct CustomCategoryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existing: CustomExpenseCategory?

    @State private var name: String
    @State private var icon: String
    @State private var tint: TintColor
    @State private var isMandatory: Bool
    @State private var errorMessage: String?

    private let icons = [
        "tag.fill", "figure.run", "pawprint.fill", "book.fill",
        "graduationcap.fill", "gift.fill", "airplane", "paintbrush.fill",
        "gamecontroller.fill", "music.note", "camera.fill", "hammer.fill",
        "leaf.fill", "cross.case.fill", "car.fill", "tram.fill",
        "cart.fill", "fork.knife", "wineglass.fill", "tshirt.fill",
    ]

    init(existing: CustomExpenseCategory?) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _icon = State(initialValue: existing?.icon ?? "tag.fill")
        _tint = State(initialValue: existing?.tint ?? .pink)
        _isMandatory = State(initialValue: existing?.isMandatory ?? false)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                IconTile(symbol: icon, tint: tint.color, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(existing == nil ? "Новая категория" : "Изменить категорию")
                        .font(.title3.weight(.semibold))
                    Text("Пользовательская категория расходов")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(18)

            Divider()

            Form {
                Section("Категория") {
                    TextField("Название", text: $name, prompt: Text("Например, Спорт"))

                    Toggle("Обязательная регулярная трата", isOn: $isMandatory)
                }

                Section("Иконка") {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.fixed(32), spacing: 6), count: 10),
                        spacing: 6
                    ) {
                        ForEach(icons, id: \.self) { item in
                            Button {
                                icon = item
                            } label: {
                                Image(systemName: item)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(icon == item ? .white : .secondary)
                                    .frame(width: 30, height: 30)
                                    .background(
                                        icon == item
                                            ? AnyShapeStyle(tint.color)
                                            : AnyShapeStyle(Color.primary.opacity(0.06)),
                                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Иконка \(item)")
                        }
                    }
                    .padding(.vertical, 2)
                }

                Section("Цвет") {
                    HStack(spacing: 9) {
                        ForEach(TintColor.allCases) { color in
                            Button {
                                tint = color
                            } label: {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 18, height: 18)
                                    .padding(3)
                                    .overlay {
                                        Circle()
                                            .strokeBorder(
                                                tint == color ? Color.primary.opacity(0.65) : .clear,
                                                lineWidth: 2
                                            )
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Цвет \(color.rawValue)")
                        }
                    }
                    .padding(.vertical, 2)
                }
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
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button(existing == nil ? "Добавить" : "Сохранить") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
        }
        .frame(width: 520, height: 650)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let duplicate = CustomCategoryCatalog.shared.categories.contains {
            $0.id != existing?.id
                && $0.name.caseInsensitiveCompare(trimmed) == .orderedSame
        }
        guard !duplicate else {
            errorMessage = "Категория с таким названием уже есть."
            return
        }

        if let existing {
            CustomCategoryCatalog.shared.update(
                CustomExpenseCategory(
                    id: existing.id,
                    name: trimmed,
                    icon: icon,
                    tint: tint,
                    isMandatory: isMandatory
                )
            )
        } else {
            CustomCategoryCatalog.shared.add(
                CustomExpenseCategory(
                    name: trimmed,
                    icon: icon,
                    tint: tint,
                    isMandatory: isMandatory
                )
            )
        }
        dismiss()
    }
}
