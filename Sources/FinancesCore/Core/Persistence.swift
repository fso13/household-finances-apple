import Foundation
import SwiftData

// MARK: - Расположение данных

package enum StoreLocation {
    package static var folder: URL {
        URL.applicationSupportDirectory
            .appendingPathComponent("Finances", isDirectory: true)
    }

    package static var storeURL: URL {
        folder.appendingPathComponent("Finances.store")
    }

    package static var backupsFolder: URL {
        folder.appendingPathComponent("Backups", isDirectory: true)
    }

    package static func prepareFolder() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }
}

// MARK: - Сохранение с обработкой ошибок

package enum Persistence {
    package static func save(_ context: ModelContext, operation: String) throws {
        do {
            try context.save()
        } catch {
            AppLog.storage.error(
                "save failed [\(operation, privacy: .public)]: \(error.localizedDescription, privacy: .public)"
            )
            throw AppError.saveFailed
        }
    }
}
