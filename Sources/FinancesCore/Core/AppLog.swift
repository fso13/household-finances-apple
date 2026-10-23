import Foundation
import OSLog

// MARK: - Логирование

package enum AppLog {
    private static let subsystem = "com.rudenko.finances"

    package static let storage = Logger(subsystem: subsystem, category: "storage")
    package static let `import` = Logger(subsystem: subsystem, category: "import")
    package static let export = Logger(subsystem: subsystem, category: "export")
    package static let ui = Logger(subsystem: subsystem, category: "ui")
}
