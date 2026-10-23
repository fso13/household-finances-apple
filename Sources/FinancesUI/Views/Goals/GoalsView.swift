import FinancesCore
import SwiftData
import SwiftUI

struct GoalsView: View {
    @Environment(\.modelContext) private var context

    @Query private var goals: [SavingsGoal]

    @State private var editor: EditorContext?
    @State private var pendingDelete: SavingsGoal?

    private struct EditorContext: Identifiable {
        let id = UUID()
        let goal: SavingsGoal?
    }

    private var progress: [GoalProgress] {
        GoalService.allProgress(goals: goals)
    }

    private var summary: GoalSummary {
        GoalService.summary(progress)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summaryRow

                if progress.isEmpty {
                    CardView {
                        EmptyStateView(
                            icon: "flag.checkered",
                            title: "Целей пока нет",
                            message:
                                "Добавьте цель накоплений — приложение покажет прогресс, остаток и сколько нужно откладывать в месяц.",
                            actionTitle: "Добавить цель"
                        ) {
                            editor = EditorContext(goal: nil)
                        }
                        .frame(height: 300)
                    }
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 350), spacing: 16, alignment: .top)],
                        alignment: .leading,
                        spacing: 16
                    ) {
                        ForEach(progress) { item in
                            GoalCard(
                                progress: item,
                                onEdit: { editor = EditorContext(goal: item.goal) },
                                onDelete: { pendingDelete = item.goal }
                            )
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Цели накоплений")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editor = EditorContext(goal: nil)
                } label: {
                    Label("Добавить", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("Добавить цель")
            }
        }
        .sheet(item: $editor) { editorContext in
            GoalEditorSheet(existing: editorContext.goal)
        }
        .alert(
            "Удалить цель?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { newValue in if !newValue { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { goal in
            Button("Удалить", role: .destructive) {
                do {
                    DeletionUndo.register(goal, in: context)
                    context.delete(goal)
                    try Persistence.save(context, operation: "goal.delete")
                    pendingDelete = nil
                } catch {
                    ErrorCenter.shared.report(error)
                }
            }
            Button("Отмена", role: .cancel) {
                pendingDelete = nil
            }
        } message: { goal in
            Text("«\(goal.name)» будет удалена. Действие можно отменить через ⌘Z.")
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Активные цели",
                value: "\(summary.count)",
                subtitle: Fmt.plural(progress.count, one: "цель", few: "цели", many: "целей"),
                icon: "flag.checkered",
                tint: .pink
            )
            StatCard(
                title: "Накоплено",
                value: Fmt.moneyRounded(summary.saved),
                subtitle: "из \(Fmt.moneyRounded(summary.target))",
                icon: "banknote.fill",
                tint: .green
            )
            StatCard(
                title: "Осталось",
                value: Fmt.moneyRounded(summary.remaining),
                subtitle: "до всех целей",
                icon: "hourglass",
                tint: .orange
            )
            StatCard(
                title: "Нужно в месяц",
                value: Fmt.moneyRounded(summary.monthlyNeeded),
                subtitle: "по целям со сроком",
                icon: "calendar.badge.clock",
                tint: .blue
            )
        }
    }
}

// MARK: - Карточка цели

private struct GoalCard: View {
    let progress: GoalProgress
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var goal: SavingsGoal { progress.goal }

    private var tint: Color {
        if progress.isComplete { return .green }
        if progress.isOverdue { return .red }
        return goal.isActive ? .pink : .gray
    }

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    IconTile(symbol: "flag.fill", tint: tint, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(goal.name)
                            .font(.headline)
                            .lineLimit(1)
                        Text("цель \(Fmt.money(goal.target))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if progress.isComplete {
                        TagBadge(text: "готово", color: .green, icon: "checkmark")
                    } else if progress.isOverdue {
                        TagBadge(text: "просрочено", color: .red)
                    } else if !goal.isActive {
                        TagBadge(text: "на паузе", color: .secondary)
                    } else {
                        TagBadge(text: Fmt.percent(progress.fraction), color: tint)
                    }
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(tint)
                            .frame(width: max(0, proxy.size.width * progress.fraction))
                    }
                }
                .frame(height: 8)

                HStack(alignment: .firstTextBaseline) {
                    Text(Fmt.money(goal.saved))
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("из \(Fmt.money(goal.target))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(progress.isComplete ? "цель достигнута" : "осталось \(Fmt.money(progress.remaining))")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(progress.isComplete ? .green : .secondary)
                }

                HStack(spacing: 12) {
                    if let deadline = goal.deadline {
                        Label(MonthFormat.day(deadline), systemImage: "calendar")
                            .font(.caption2)
                            .foregroundStyle(progress.isOverdue ? .red : .secondary)
                    } else {
                        Label("без срока", systemImage: "calendar")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    if let monthly = progress.monthlyNeeded, !progress.isComplete {
                        Text("≈ \(Fmt.moneyRounded(monthly)) / мес.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                if !goal.note.isEmpty {
                    Text(goal.note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Divider()

                HStack {
                    Button {
                        onEdit()
                    } label: {
                        Label("Изменить", systemImage: "pencil")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)

                    Spacer()

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Удалить цель")
                    .accessibilityLabel("Удалить цель")
                }
            }
            .opacity(goal.isActive ? 1 : 0.7)
        }
        .contextMenu {
            Button("Изменить") { onEdit() }
            Button("Удалить", role: .destructive) { onDelete() }
        }
    }
}
