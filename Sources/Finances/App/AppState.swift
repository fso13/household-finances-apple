import SwiftUI

/// Общее состояние навигации. Вынесено отдельно, чтобы служебный режим
/// снимков экрана мог переключать разделы приложения.
@MainActor
final class AppState: ObservableObject {
    @Published var route: AppRoute? = .dashboard
}
