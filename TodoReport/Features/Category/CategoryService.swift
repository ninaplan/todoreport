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
    var plannerId: String?

    init(
        id: String = UUID().uuidString,
        name: String,
        colorHex: String = "#FD6845",
        icon: String = "tag.fill",
        status: CategoryStatus = .active,
        plannerId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
        self.status = status
        self.plannerId = plannerId
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
        store = (try? PersistenceController.shared.context.fetch(
            FetchDescriptor<CategoryItem>(sortBy: [SortDescriptor(\.sortOrder)])
        ))?.map { $0.toCategory() } ?? []
    }

    private var context: ModelContext { PersistenceController.shared.context }

    private(set) var store: [Category] = []

    var activeCategories: [Category] {
        let pid = PlannerService.shared.selectedPlanner?.id
        let active = store.filter { $0.status == .active }
        guard let pid else { return active }
        return active.filter { $0.plannerId == pid || $0.plannerId == nil }
    }

    var archivedCategories: [Category] {
        let pid = PlannerService.shared.selectedPlanner?.id
        let archived = store.filter { $0.status == .archived }
        guard let pid else { return archived }
        return archived.filter { $0.plannerId == pid || $0.plannerId == nil }
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
            // store 유지
        }
    }

    // MARK: - Write

    func saveCategory(_ category: Category) async throws {
        var cat = category
        let id = cat.id
        let descriptor = FetchDescriptor<CategoryItem>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: cat)
        } else {
            if cat.plannerId == nil {
                cat.plannerId = PlannerService.shared.selectedPlanner?.id
            }
            let sortOrder = store.count
            context.insert(CategoryItem.from(cat, sortOrder: sortOrder))
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
                // 순서 변경 실패
            }
        }
    }
}
