import Foundation
import SwiftData

// MARK: - Автоматические бэкапы

package enum BackupStore {
    package static let maxAutomaticBackups = 10

    @discardableResult
    package static func createAutomaticBackup(
        context: ModelContext,
        reason: String,
        in folder: URL = StoreLocation.backupsFolder,
        appVersion: String = "1.0"
    ) throws -> URL {
        let envelope = try BackupCodec.makeEnvelope(context: context, appVersion: appVersion)
        let data = try BackupCodec.encode(envelope)

        let fileManager = FileManager.default
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)

        let stamp = fileStamp()
        let url = folder.appendingPathComponent("auto-\(stamp)-\(reason).json")
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            AppLog.storage.error("auto backup write failed: \(error.localizedDescription, privacy: .public)")
            throw AppError.exportFailed
        }

        prune(in: folder, fileManager: fileManager)
        AppLog.storage.info("auto backup created: \(url.lastPathComponent, privacy: .public)")
        return url
    }

    package static func prune(in folder: URL = StoreLocation.backupsFolder, fileManager: FileManager = .default) {
        guard
            let files = try? fileManager.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return
        }

        let backups =
            files
            .filter { $0.lastPathComponent.hasPrefix("auto-") && $0.pathExtension == "json" }
            .sorted { lhs, rhs in
                let left =
                    (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                    ?? .distantPast
                let right =
                    (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                    ?? .distantPast
                return left > right
            }

        for url in backups.dropFirst(maxAutomaticBackups) {
            try? fileManager.removeItem(at: url)
        }
    }

    private static func fileStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}
