import AppKit
import FinancesCore
import SwiftUI

// MARK: - Восстановление хранилища

package struct RecoveryView: View {
    package let error: AppError?
    package let onRetry: () -> Void
    package let onOpenFolder: () -> Void
    package let onReset: () -> Void

    @State private var confirmReset = false

    package init(
        error: AppError?,
        onRetry: @escaping () -> Void,
        onOpenFolder: @escaping () -> Void,
        onReset: @escaping () -> Void
    ) {
        self.error = error
        self.onRetry = onRetry
        self.onOpenFolder = onOpenFolder
        self.onReset = onReset
    }

    package var body: some View {
        VStack(spacing: 22) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.orange, .pink.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 82, height: 82)
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                Text("Не удалось открыть данные")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text("Повреждён store или к нему нет доступа. Текущие данные не удалены.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 470)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(error?.errorDescription ?? "Неизвестная ошибка хранилища.")
                    .font(.callout.weight(.medium))
                Text("Файл данных")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                Text(StoreLocation.storeURL.path)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            .padding(16)
            .frame(maxWidth: 500, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 10) {
                Button("Повторить") {
                    onRetry()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Открыть папку данных") {
                    onOpenFolder()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button("Создать новую базу", role: .destructive) {
                    confirmReset = true
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Text("Перед созданием новой базы повреждённый store будет сохранён в папке Backups.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Создать новую базу?", isPresented: $confirmReset) {
            Button("Создать", role: .destructive) {
                onReset()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Текущий файл будет сохранён в Backups, после чего приложение создаст пустую базу.")
        }
    }
}
