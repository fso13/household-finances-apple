import Foundation

// MARK: - Пользовательские ошибки

package enum AppError: LocalizedError, Identifiable, Sendable {
    case storageUnavailable
    case migrationFailed
    case saveFailed
    case deleteFailed
    case exportFailed
    case importFailed
    case validation(String)

    package var id: String {
        switch self {
        case .storageUnavailable: "storageUnavailable"
        case .migrationFailed: "migrationFailed"
        case .saveFailed: "saveFailed"
        case .deleteFailed: "deleteFailed"
        case .exportFailed: "exportFailed"
        case .importFailed: "importFailed"
        case .validation(let message): "validation:\(message)"
        }
    }

    package var errorDescription: String? {
        switch self {
        case .storageUnavailable:
            "Не удалось открыть локальное хранилище."
        case .migrationFailed:
            "Не удалось перенести данные из предыдущей версии."
        case .saveFailed:
            "Не удалось сохранить изменения."
        case .deleteFailed:
            "Не удалось удалить запись."
        case .exportFailed:
            "Не удалось экспортировать данные."
        case .importFailed:
            "Не удалось импортировать данные."
        case .validation(let message):
            message
        }
    }

    package var recoverySuggestion: String? {
        switch self {
        case .storageUnavailable:
            "Откройте папку данных, сделайте копию store и попробуйте восстановить базу. Если не помогает — создайте новую базу: повреждённый файл будет сохранён рядом."
        case .migrationFailed:
            "Старый файл Finances.store не изменён. Откройте папку данных, сделайте копию и повторите запуск. Если не помогает — создайте новую базу и восстановите JSON-бэкап."
        case .saveFailed, .deleteFailed:
            "Попробуйте ещё раз. Если ошибка повторяется, проверьте свободное место на диске и права на папку данных."
        case .exportFailed:
            "Проверьте, что выбрана доступная папка и у приложения есть права на запись."
        case .importFailed:
            "Проверьте формат файла и попробуйте снова. Текущие данные не изменены."
        case .validation:
            "Исправьте значение и повторите попытку."
        }
    }
}
