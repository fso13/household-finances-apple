import SwiftUI

/// Общее состояние навигации. Вынесено отдельно, чтобы служебный режим
/// снимков экрана мог переключать разделы приложения.
@MainActor
package final class AppState: ObservableObject {
    @Published package var route: AppRoute? = .dashboard

    package init() {}
}
