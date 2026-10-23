import FinancesCore
import SwiftUI

struct CategoryRulesSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var rules: [CategoryRule] = []
    @State private var editor: EditorContext?
    @State private var pendingDelete: CategoryRule?

    private struct EditorContext: Identifiable {
        let id = UUID()
        let rule: CategoryRule?
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                IconTile(symbol: "wand.and.stars", tint: .purple, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Правила категоризации")
                        .font(.title3.weight(.semibold))
                    Text("По ключевому слову в заметке при импорте CSV")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    editor = EditorContext(rule: nil)
                } label: {
                    Label("Добавить", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(18)

            Divider()

            if rules.isEmpty {
                EmptyStateView(
                    icon: "wand.and.stars",
                    title: "Правил пока нет",
                    message: "Например: «пятёрочка» → Продукты, «такси» → Транспорт.",
                    actionTitle: "Добавить правило"
                ) {
                    editor = EditorContext(rule: nil)
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(rules) { rule in
                            HStack(spacing: 12) {
                                IconTile(symbol: rule.category.icon, tint: rule.category.color, size: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(rule.keyword)
                                        .font(.callout.weight(.medium))
                                    Text(rule.category.title)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if rule.priority != 0 {
                                    Text("приоритет \(rule.priority)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                Button {
                                    editor = EditorContext(rule: rule)
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.borderless)
                                Button(role: .destructive) {
                                    pendingDelete = rule
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            Divider().padding(.leading, 60)
                        }
                    }
                }
            }

            Divider()
            HStack {
                Text("Правила применяются, если категория в CSV пустая или «Прочее».")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Готово") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 560, height: 560)
        .onAppear(perform: reload)
        .sheet(item: $editor) { context in
            CategoryRuleEditorSheet(existing: context.rule)
        }
        .alert(
            "Удалить правило?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { newValue in if !newValue { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { rule in
            Button("Удалить", role: .destructive) {
                CategoryRuleCatalog.shared.remove(id: rule.id)
                pendingDelete = nil
                reload()
            }
            Button("Отмена", role: .cancel) { pendingDelete = nil }
        } message: { rule in
            Text("«\(rule.keyword)» больше не будет влиять на импорт.")
        }
    }

    private func reload() {
        rules = CategoryRuleCatalog.shared.rules
    }
}

private struct CategoryRuleEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existing: CategoryRule?
    @State private var keyword: String
    @State private var category: ExpenseCategory
    @State private var priority: Int
    @State private var errorMessage: String?

    init(existing: CategoryRule?) {
        self.existing = existing
        _keyword = State(initialValue: existing?.keyword ?? "")
        _category = State(initialValue: existing?.category ?? .food)
        _priority = State(initialValue: existing?.priority ?? 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(existing == nil ? "Новое правило" : "Изменить правило")
                    .font(.title3.weight(.semibold))
                Spacer()
            }
            .padding(18)

            Divider()

            Form {
                Section("Условие") {
                    TextField("Ключевое слово", text: $keyword, prompt: Text("Например, пятёрочка"))
                    Picker("Категория", selection: $category) {
                        ForEach(ExpenseCategory.all) { category in
                            Label(category.title, systemImage: category.icon).tag(category)
                        }
                    }
                    Stepper("Приоритет: \(priority)", value: $priority, in: 0...100)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                if let errorMessage {
                    Text(errorMessage).font(.caption2).foregroundStyle(.red)
                }
                Button("Отмена") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(existing == nil ? "Добавить" : "Сохранить") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
        }
        .frame(width: 460, height: 380)
    }

    private func save() {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let duplicate = CategoryRuleCatalog.shared.rules.contains {
            $0.id != existing?.id
                && $0.keyword.caseInsensitiveCompare(trimmed) == .orderedSame
        }
        guard !duplicate else {
            errorMessage = "Правило с таким словом уже есть."
            return
        }

        if let existing {
            CategoryRuleCatalog.shared.update(
                CategoryRule(id: existing.id, keyword: trimmed, category: category, priority: priority)
            )
        } else {
            CategoryRuleCatalog.shared.add(
                CategoryRule(keyword: trimmed, category: category, priority: priority)
            )
        }
        dismiss()
    }
}
