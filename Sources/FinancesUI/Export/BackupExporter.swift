import AppKit
import FinancesCore
import SwiftData
import UniformTypeIdentifiers

@MainActor
enum BackupExporter {
    static func export(context: ModelContext, appVersion: String) throws {
        let envelope = try BackupCodec.makeEnvelope(context: context, appVersion: appVersion)
        let data = try BackupCodec.encode(envelope)

        let panel = NSSavePanel()
        panel.title = "Экспорт резервной копии"
        panel.nameFieldStringValue = "финансы-\(fileStamp()).json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            AppLog.export.error("backup write failed: \(error.localizedDescription, privacy: .public)")
            throw AppError.exportFailed
        }
    }

    static func chooseBackup() throws -> BackupEnvelope? {
        let panel = NSOpenPanel()
        panel.title = "Импорт резервной копии"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            return try BackupCodec.decode(data)
        } catch let error as AppError {
            throw error
        } catch {
            AppLog.import.error("backup read failed: \(error.localizedDescription, privacy: .public)")
            throw AppError.importFailed
        }
    }

    static func openBackupsFolder() {
        do {
            try FileManager.default.createDirectory(
                at: StoreLocation.backupsFolder,
                withIntermediateDirectories: true
            )
            NSWorkspace.shared.open(StoreLocation.backupsFolder)
        } catch {
            AppLog.storage.error("open backups failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func fileStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return formatter.string(from: Date())
    }
}
