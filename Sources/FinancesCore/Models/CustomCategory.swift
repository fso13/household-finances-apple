import Foundation

// MARK: - Пользовательские категории

package struct CustomExpenseCategory: Codable, Identifiable, Hashable, Sendable {
    package var id: UUID
    package var name: String
    package var icon: String
    package var tint: TintColor
    package var isMandatory: Bool

    package init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        tint: TintColor,
        isMandatory: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.tint = tint
        self.isMandatory = isMandatory
    }
}

/// Каталог пользовательских категорий хранится в UserDefaults,
/// чтобы raw-значения записей оставались строками и не ломали старые данные.
package final class CustomCategoryCatalog: @unchecked Sendable {
    package static let shared = CustomCategoryCatalog()

    private let lock = NSLock()
    private let defaultsKey = "customExpenseCategories"
    private var stored: [CustomExpenseCategory] = []

    private init() {
        load()
    }

    package var categories: [CustomExpenseCategory] {
        lock.lock()
        defer { lock.unlock() }
        return stored.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    package func category(id: UUID) -> CustomExpenseCategory? {
        lock.lock()
        defer { lock.unlock() }
        return stored.first { $0.id == id }
    }

    package func add(_ category: CustomExpenseCategory) {
        lock.lock()
        stored.append(category)
        let snapshot = stored
        lock.unlock()
        persist(snapshot)
    }

    package func update(_ category: CustomExpenseCategory) {
        lock.lock()
        if let index = stored.firstIndex(where: { $0.id == category.id }) {
            stored[index] = category
        } else {
            stored.append(category)
        }
        let snapshot = stored
        lock.unlock()
        persist(snapshot)
    }

    package func remove(id: UUID) {
        lock.lock()
        stored.removeAll { $0.id == id }
        let snapshot = stored
        lock.unlock()
        persist(snapshot)
    }

    package func replaceAll(_ categories: [CustomExpenseCategory]) {
        lock.lock()
        stored = categories
        let snapshot = stored
        lock.unlock()
        persist(snapshot)
    }

    package func merge(_ categories: [CustomExpenseCategory]) {
        lock.lock()
        for category in categories {
            if let index = stored.firstIndex(where: { $0.id == category.id }) {
                stored[index] = category
            } else if !stored.contains(where: { $0.name.caseInsensitiveCompare(category.name) == .orderedSame }) {
                stored.append(category)
            }
        }
        let snapshot = stored
        lock.unlock()
        persist(snapshot)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        stored = (try? JSONDecoder().decode([CustomExpenseCategory].self, from: data)) ?? []
    }

    private func persist(_ categories: [CustomExpenseCategory]) {
        guard let data = try? JSONEncoder().encode(categories) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
