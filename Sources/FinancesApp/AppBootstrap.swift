import AppKit
import FinancesCore
import FinancesLegacy
import SwiftData
import SwiftUI

// MARK: - Запуск хранилища с восстановлением

@MainActor
final class AppBootstrap: ObservableObject {
    @Published private(set) var container: ModelContainer?
    @Published private(set) var error: AppError?

    init() {
        load()
    }

    func load() {
        do {
            try StoreLocation.prepareFolder()

            do {
                let migrated = try LegacyMigration.migrateIfNeeded(
                    legacyURL: StoreLocation.legacyStoreURL,
                    newURL: StoreLocation.storeURL
                )
                if migrated {
                    AppLog.storage.info("V1 data migrated to kopeck store")
                }
            } catch {
                AppLog.storage.error(
                    "V1 migration failed: \(error.localizedDescription, privacy: .public)"
                )
                container = nil
                self.error = .migrationFailed
                return
            }

            let schema = Schema(versionedSchema: FinancesSchemaV4.self)
            let configuration = ModelConfiguration("FinancesV2", schema: schema, url: StoreLocation.storeURL)
            let newContainer = try ModelContainer(
                for: schema,
                migrationPlan: FinancesMigrationPlan.self,
                configurations: configuration
            )
            newContainer.mainContext.autosaveEnabled = true
            DataUndo.shared.removeAllActions()
            container = newContainer
            error = nil
            AppLog.storage.info("store opened at \(StoreLocation.storeURL.path, privacy: .public)")
        } catch {
            AppLog.storage.error("container failed: \(error.localizedDescription, privacy: .public)")
            container = nil
            self.error = .storageUnavailable
        }
    }

    var canUndo: Bool { DataUndo.shared.canUndo }
    var canRedo: Bool { DataUndo.shared.canRedo }

    func undo() {
        DataUndo.shared.undo()
    }

    func redo() {
        DataUndo.shared.redo()
    }

    func openDataFolder() {
        do {
            try StoreLocation.prepareFolder()
            NSWorkspace.shared.open(StoreLocation.folder)
        } catch {
            AppLog.storage.error("open folder failed: \(error.localizedDescription, privacy: .public)")
            self.error = .storageUnavailable
        }
    }

    func resetStore() {
        do {
            try StoreLocation.prepareFolder()
            try backupCurrentStore()
            try LegacyMigration.archiveLegacyStore(
                legacyURL: StoreLocation.legacyStoreURL,
                backupFolder: StoreLocation.backupsFolder
            )
            try removeStoreFiles()
            load()
        } catch {
            AppLog.storage.error("reset failed: \(error.localizedDescription, privacy: .public)")
            self.error = .storageUnavailable
        }
    }

    private func backupCurrentStore() throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: StoreLocation.storeURL.path) else { return }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: Date())

        let backups = StoreLocation.folder.appendingPathComponent("Backups", isDirectory: true)
        let destination = backups.appendingPathComponent("Corrupted-\(stamp)", isDirectory: true)
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: StoreLocation.storeURL.path + suffix)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            let target = destination.appendingPathComponent("Finances.store" + suffix)
            try fileManager.copyItem(at: source, to: target)
        }

        AppLog.storage.info("corrupted store backed up to \(destination.path, privacy: .public)")
    }

    private func removeStoreFiles() throws {
        let fileManager = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let url = URL(fileURLWithPath: StoreLocation.storeURL.path + suffix)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
    }
}
