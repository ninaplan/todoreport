import Foundation

// MARK: - Model

struct Category: Identifiable, Codable {
    let id: String
    var name: String
    var colorHex: String

    init(id: String = UUID().uuidString, name: String, colorHex: String = "#FD6845") {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }

    static let colorPalette: [String] = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759",
        "#00C7BE", "#007AFF", "#5856D6", "#AF52DE",
        "#FF2D55", "#A2845E", "#8E8E93", "#FD6845"
    ]
}

// MARK: - Service

final class CategoryService {
    // 인메모리 저장소 — SwiftData 연동 전 더미 구현
    private var store: [Category] = [
        Category(id: "cat-1", name: "수학", colorHex: "#007AFF"),
        Category(id: "cat-2", name: "영어", colorHex: "#34C759"),
        Category(id: "cat-3", name: "독서", colorHex: "#FF9500"),
    ]

    func fetchCategories() async -> [Category] {
        // TODO: SwiftData context.fetch(FetchDescriptor<Category>())
        return store
    }

    func saveCategory(_ category: Category) async throws {
        // Offline-First (앱 전용 — SyncQueue 불필요):
        // TODO: SwiftData context.insert / context.save()
        if let index = store.firstIndex(where: { $0.id == category.id }) {
            store[index] = category
        } else {
            store.append(category)
        }
    }

    func deleteCategory(id: String) async throws {
        // TODO: SwiftData context.delete(...)
        store.removeAll { $0.id == id }
    }
}
