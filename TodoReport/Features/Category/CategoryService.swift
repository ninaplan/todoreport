import Foundation
import SwiftData
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
    private init() {
        // 앱 시작 시 SwiftData에서 즉시 동기 로드 — 카테고리 칩 첫 렌더링에 반영
        store = (try? PersistenceController.shared.context.fetch(
            FetchDescriptor<CategoryItem>(sortBy: [SortDescriptor(\.sortOrder)])
        ))?.map { $0.toCategory() } ?? []
    }

    private var context: ModelContext { PersistenceController.shared.context }

    // 반응형 스토어 — SwiftData 패치 후 갱신
    private(set) var store: [Category] = []

    var activeCategories: [Category] {
        store.filter { $0.status == .active }
    }

    var archivedCategories: [Category] {
        store.filter { $0.status == .archived }
    }

    // MARK: - Fetch

    func fetchCategories() async -> [Category] {
        await refreshStore()
        return activeCategories
    }

    func fetchArchivedCategories() async -> [Category] {
        await refreshStore()
        return archivedCategories
    }

    private func refreshStore() async {
        do {
            let descriptor = FetchDescriptor<CategoryItem>(
                sortBy: [SortDescriptor(\.sortOrder)]
            )
            store = try context.fetch(descriptor).map { $0.toCategory() }
        } catch {
            // store 유지 (패치 실패 시 기존 상태 보존)
        }
    }

    // MARK: - Write

    func saveCategory(_ category: Category) async throws {
        let id = category.id
        let descriptor = FetchDescriptor<CategoryItem>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: category)
        } else {
            let sortOrder = store.count
            context.insert(CategoryItem.from(category, sortOrder: sortOrder))
        }
        try context.save()
        await refreshStore()
    }

    func archiveCategory(id: String) async throws {
        let descriptor = FetchDescriptor<CategoryItem>(predicate: #Predicate { $0.id == id })
        guard let item = try context.fetch(descriptor).first else { return }
        item.statusRaw = CategoryStatus.archived.rawValue
        try context.save()
        await refreshStore()
    }

    func restoreCategory(id: String) async throws {
        let descriptor = FetchDescriptor<CategoryItem>(predicate: #Predicate { $0.id == id })
        guard let item = try context.fetch(descriptor).first else { return }
        item.statusRaw = CategoryStatus.active.rawValue
        try context.save()
        await refreshStore()
    }

    func reorderActiveCategories(_ ordered: [Category]) {
        Task {
            do {
                for (index, category) in ordered.enumerated() {
                    let id = category.id
                    let descriptor = FetchDescriptor<CategoryItem>(predicate: #Predicate { $0.id == id })
                    if let item = try context.fetch(descriptor).first {
                        item.sortOrder = index
                    }
                }
                try context.save()
                await refreshStore()
            } catch {
                // 순서 변경 실패 — UI에서 이미 reorder 반영됐으므로 다음 패치 시 복구
            }
        }
    }
}
