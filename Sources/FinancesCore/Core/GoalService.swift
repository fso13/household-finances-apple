import Foundation

// MARK: - Прогресс целей

package struct GoalProgress: Identifiable {
    package let id: UUID
    package let goal: SavingsGoal
    package let remaining: Double
    package let fraction: Double
    package let monthsLeft: Int?
    package let monthlyNeeded: Double?
    package let isOverdue: Bool

    package var isComplete: Bool { remaining <= 0 }
}

package struct GoalSummary {
    package let target: Double
    package let saved: Double
    package let count: Int
    package let monthlyNeeded: Double

    package var remaining: Double { max(0, target - saved) }
}

package enum GoalService {
    package static func progress(
        for goal: SavingsGoal,
        now: Date = Date()
    ) -> GoalProgress {
        let remaining = max(0, goal.target - goal.saved)
        let fraction = goal.target > 0 ? min(goal.saved / goal.target, 1) : 0

        var monthsLeft: Int?
        var monthlyNeeded: Double?
        var isOverdue = false

        if let deadline = goal.deadline {
            let today = now.startOfDay
            isOverdue = deadline < today && remaining > 0
            let months =
                Calendar.current.dateComponents(
                    [.month],
                    from: now.startOfMonth,
                    to: deadline.startOfMonth
                ).month ?? 0
            let periods = max(1, months + 1)
            monthsLeft = periods
            monthlyNeeded = remaining / Double(periods)
        }

        return GoalProgress(
            id: goal.uid,
            goal: goal,
            remaining: remaining,
            fraction: fraction,
            monthsLeft: monthsLeft,
            monthlyNeeded: monthlyNeeded,
            isOverdue: isOverdue
        )
    }

    package static func allProgress(
        goals: [SavingsGoal],
        now: Date = Date()
    ) -> [GoalProgress] {
        goals
            .map { progress(for: $0, now: now) }
            .sorted { lhs, rhs in
                if lhs.isComplete != rhs.isComplete { return !lhs.isComplete }
                if lhs.goal.isActive != rhs.goal.isActive { return lhs.goal.isActive }
                return lhs.goal.name.localizedCaseInsensitiveCompare(rhs.goal.name) == .orderedAscending
            }
    }

    package static func summary(
        _ progress: [GoalProgress]
    ) -> GoalSummary {
        GoalSummary(
            target: progress.reduce(0) { $0 + $1.goal.target },
            saved: progress.reduce(0) { $0 + $1.goal.saved },
            count: progress.filter { !$0.isComplete }.count,
            monthlyNeeded: progress.reduce(0) { $0 + ($1.monthlyNeeded ?? 0) }
        )
    }
}
