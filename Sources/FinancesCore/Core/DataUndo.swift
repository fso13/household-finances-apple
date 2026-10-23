import Foundation

// MARK: - Undo-стек приложения

/// Отдельный `UndoManager`, не привязанный к `ModelContext`.
/// SwiftData-интеграция undo для удаления записей не восстанавливает объект,
/// поэтому удаления регистрируются вручную через `DeletionUndo`.
@MainActor
package final class DataUndo {
    package static let shared = DataUndo()

    package let manager = UndoManager()

    private init() {}

    package var canUndo: Bool { manager.canUndo }
    package var canRedo: Bool { manager.canRedo }

    package func undo() {
        manager.undo()
    }

    package func redo() {
        manager.redo()
    }

    package func removeAllActions() {
        manager.removeAllActions()
    }
}
