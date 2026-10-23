import Foundation

package enum QuickAddKind: String, Identifiable, Hashable {
    case income
    case expense

    package var id: String { rawValue }
}

package final class AppState: ObservableObject {
    @Published package var route: AppRoute? = .dashboard
    @Published package var pendingQuickAdd: QuickAddKind?

    package init() {}

    package func requestQuickAdd(_ kind: QuickAddKind) {
        route = .dashboard
        pendingQuickAdd = kind
    }
}
