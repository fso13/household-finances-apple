import XCTest
@testable import FinancesCore

final class GoalTests: XCTestCase {
    private func goal(
        _ name: String = "Отпуск",
        target: Double = 150_000,
        saved: Double = 45_000,
        deadline: Date? = nil,
        active: Bool = true
    ) -> SavingsGoal {
        SavingsGoal(name: name, target: target, saved: saved, deadline: deadline, isActive: active)
    }

    func testGoalProgressWithDeadline() {
        let progress = GoalService.progress(
            for: goal(target: 500_000, saved: 180_000, deadline: makeDate(2027, 10, 1)),
            now: makeDate(2026, 10, 1)
        )

        XCTAssertEqual(progress.remaining, 320_000)
        XCTAssertEqual(progress.fraction, 0.36, accuracy: 0.001)
        XCTAssertEqual(progress.monthsLeft, 13)
        XCTAssertEqual(progress.monthlyNeeded ?? -1, 320_000 / 13, accuracy: 0.01)
        XCTAssertFalse(progress.isOverdue)
        XCTAssertFalse(progress.isComplete)
    }

    func testGoalWithoutDeadline() {
        let progress = GoalService.progress(for: goal(), now: makeDate(2026, 10, 1))
        XCTAssertNil(progress.monthsLeft)
        XCTAssertNil(progress.monthlyNeeded)
        XCTAssertEqual(progress.remaining, 105_000)
    }

    func testCompletedGoal() {
        let progress = GoalService.progress(
            for: goal(target: 100_000, saved: 100_000),
            now: makeDate(2026, 10, 1)
        )
        XCTAssertTrue(progress.isComplete)
        XCTAssertEqual(progress.remaining, 0)
        XCTAssertEqual(progress.fraction, 1)
    }

    func testOverdueGoal() {
        let progress = GoalService.progress(
            for: goal(deadline: makeDate(2026, 1, 1)),
            now: makeDate(2026, 10, 1)
        )
        XCTAssertTrue(progress.isOverdue)
    }

    func testSummary() {
        let goals = [
            goal("Отпуск", target: 150_000, saved: 45_000, deadline: makeDate(2027, 4, 1)),
            goal("Подушка", target: 500_000, saved: 180_000, deadline: makeDate(2027, 10, 1)),
            goal("Готово", target: 100_000, saved: 100_000),
        ]
        let progress = GoalService.allProgress(goals: goals, now: makeDate(2026, 10, 1))
        let summary = GoalService.summary(progress)

        XCTAssertEqual(summary.target, 750_000)
        XCTAssertEqual(summary.saved, 325_000)
        XCTAssertEqual(summary.count, 2)
        XCTAssertEqual(summary.remaining, 425_000)
        XCTAssertGreaterThan(summary.monthlyNeeded, 0)
        XCTAssertEqual(progress.last?.goal.name, "Готово")
    }
}
