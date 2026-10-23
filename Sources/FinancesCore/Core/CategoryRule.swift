import Foundation

// MARK: - Правила автокатегоризации

package struct CategoryRule: Codable, Identifiable, Hashable, Sendable {
    package var id: UUID
    package var keyword: String
    package var categoryRaw: String
    package var priority: Int

    package init(
        id: UUID = UUID(),
        keyword: String,
        category: ExpenseCategory,
        priority: Int = 0
    ) {
        self.id = id
        self.keyword = keyword
        self.categoryRaw = category.rawValue
        self.priority = priority
    }

    package var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}

package final class CategoryRuleCatalog: @unchecked Sendable {
    package static let shared = CategoryRuleCatalog()

    private let lock = NSLock()
    private let defaultsKey = "categoryRules"
    private var stored: [CategoryRule] = []

    private init() {
        load()
    }

    package var rules: [CategoryRule] {
        lock.lock()
        defer { lock.unlock() }
        return stored.sorted {
            $0.priority == $1.priority
                ? $0.keyword.localizedCaseInsensitiveCompare($1.keyword) == .orderedAscending
                : $0.priority > $1.priority
        }
    }

    package func add(_ rule: CategoryRule) {
        lock.lock()
        stored.append(rule)
        let snapshot = stored
        lock.unlock()
        persist(snapshot)
    }

    package func update(_ rule: CategoryRule) {
        lock.lock()
        if let index = stored.firstIndex(where: { $0.id == rule.id }) {
            stored[index] = rule
        } else {
            stored.append(rule)
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

    package func replaceAll(_ rules: [CategoryRule]) {
        lock.lock()
        stored = rules
        let snapshot = stored
        lock.unlock()
        persist(snapshot)
    }

    package func merge(_ rules: [CategoryRule]) {
        lock.lock()
        for rule in rules where !stored.contains(where: { $0.id == rule.id }) {
            stored.append(rule)
        }
        let snapshot = stored
        lock.unlock()
        persist(snapshot)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        stored = (try? JSONDecoder().decode([CategoryRule].self, from: data)) ?? []
    }

    private func persist(_ rules: [CategoryRule]) {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}

// MARK: - Движок правил

package enum CategoryRuleEngine {
    package static func category(
        for text: String,
        rules: [CategoryRule]? = nil
    ) -> ExpenseCategory? {
        let normalized =
            text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
        guard !normalized.isEmpty else { return nil }

        let source = rules ?? CategoryRuleCatalog.shared.rules
        return
            source
            .sorted {
                $0.priority == $1.priority
                    ? $0.keyword.count > $1.keyword.count
                    : $0.priority > $1.priority
            }
            .first {
                normalized.contains(
                    $0.keyword
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .lowercased()
                        .replacingOccurrences(of: "ё", with: "е")
                )
            }?
            .category
    }
}
