import Foundation
import Observation

// MARK: - Status

enum CategoryStatus: String, Codable {
    case active
    case archived
    case completed
}

// MARK: - Model

struct Category: Identifiable, Codable {
    let id: String
    var name: String
    var colorHex: String
    var icon: String
    var status: CategoryStatus

    init(
        id: String = UUID().uuidString,
        name: String,
        colorHex: String = "#FD6845",
        icon: String = "tag.fill",
        status: CategoryStatus = .active
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
        self.status = status
    }

    static let colorPalette: [String] = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759",
        "#00C7BE", "#007AFF", "#5856D6", "#AF52DE",
        "#FF2D55", "#A2845E", "#8E8E93", "#FD6845"
    ]

    static let iconPalette: [String] = [
        // 공부/학습
        "book.fill", "pencil", "graduationcap.fill", "brain.head.profile", "note.text",
        // 운동/건강
        "figure.run", "dumbbell.fill", "heart.fill", "bicycle", "leaf.fill",
        // 업무/생산성
        "briefcase.fill", "doc.text.fill", "chart.line.uptrend.xyaxis", "clock.fill", "flag.fill",
        // 생활
        "house.fill", "cart.fill", "fork.knife", "car.fill", "creditcard.fill",
        // 취미/기타
        "music.note", "paintbrush.fill", "camera.fill", "star.fill", "gamecontroller.fill"
    ]
}

// MARK: - Service

@Observable
final class CategoryService {
    static let shared = CategoryService()
    private init() {}

    // 인메모리 저장소 — SwiftData 연동 전 더미 구현
    private(set) var store: [Category] = [
        Category(id: "cat-1", name: "수학",  colorHex: "#007AFF", icon: "pencil"),
        Category(id: "cat-2", name: "영어",  colorHex: "#34C759", icon: "note.text"),
        Category(id: "cat-3", name: "독서",  colorHex: "#FF9500", icon: "book.fill"),
        Category(id: "cat-4", name: "운동",  colorHex: "#FF3B30", icon: "figure.run"),
    ]

    var activeCategories: [Category] {
        store.filter { $0.status == .active }
    }

    var archivedCategories: [Category] {
        store.filter { $0.status == .archived }
    }

    func fetchCategories() async -> [Category] {
        // TODO: SwiftData context.fetch — status == .active 필터
        return activeCategories
    }

    func fetchArchivedCategories() async -> [Category] {
        // TODO: SwiftData context.fetch — status == .archived 필터
        return archivedCategories
    }

    func saveCategory(_ category: Category) async throws {
        // TODO: SwiftData context.insert / context.save()
        if let index = store.firstIndex(where: { $0.id == category.id }) {
            store[index] = category
        } else {
            store.append(category)
        }
    }

    func archiveCategory(id: String) async throws {
        // TODO: SwiftData context.save()
        guard let index = store.firstIndex(where: { $0.id == id }) else { return }
        store[index].status = .archived
    }

    func restoreCategory(id: String) async throws {
        // TODO: SwiftData context.save()
        guard let index = store.firstIndex(where: { $0.id == id }) else { return }
        store[index].status = .active
    }

    func reorderActiveCategories(_ ordered: [Category]) {
        let orderedIds = ordered.map(\.id)
        let archived = store.filter { $0.status != .active }
        let reordered = orderedIds.compactMap { id in store.first { $0.id == id } }
        store = reordered + archived
    }
}
