import FinancesCore
import Foundation
import SwiftUI

// MARK: - Единая точка показа ошибок

@MainActor
package final class ErrorCenter: ObservableObject {
    package static let shared = ErrorCenter()

    @Published package var error: AppError?

    private init() {}

    package func report(_ error: Error) {
        if let appError = error as? AppError {
            report(appError)
            return
        }

        AppLog.ui.error("unhandled error: \(error.localizedDescription, privacy: .public)")
        self.error = .saveFailed
    }

    package func report(_ error: AppError) {
        AppLog.ui.error("reported error: \(error.id, privacy: .public)")
        self.error = error
    }

    package func dismiss() {
        error = nil
    }
}
