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
    var notionOptionId: String?
    var notionOptionName: String?
    var isHidden: Bool

    var isLinkedToNotion: Bool {
        notionOptionId != nil || notionOptionName != nil
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        colorHex: String = "#FD6845",
        icon: String = "tag.fill",
        status: CategoryStatus = .active,
        plannerId: String? = nil,
        notionOptionId: String? = nil,
        notionOptionName: String? = nil,
        isHidden: Bool = false
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
        self.status = status
        self.plannerId = plannerId
        self.notionOptionId = notionOptionId
        self.notionOptionName = notionOptionName
        self.isHidden = isHidden
    }

    static let iconPalette: [String] = [
        // 업무/생산성
        "briefcase.fill", "desktopcomputer", "laptopcomputer", "doc.text.fill", "chart.line.uptrend.xyaxis",
        "clock.fill", "calendar", "tray.full.fill", "paperplane.fill", "flag.fill",
        // 학습
        "book.fill", "pencil", "graduationcap.fill", "brain.head.profile", "note.text",
        "magnifyingglass", "lightbulb.fill", "newspaper.fill",
        // 건강/운동
        "heart.fill", "figure.run", "dumbbell.fill", "bicycle", "leaf.fill",
        "cross.fill", "flame.fill", "drop.fill",
        // 식생활
        "fork.knife", "cup.and.saucer.fill", "cart.fill",
        // 생활/이동
        "house.fill", "car.fill", "airplane", "bag.fill", "creditcard.fill",
        // 취미/문화
        "music.note", "headphones", "camera.fill", "paintbrush.fill", "gamecontroller.fill",
        "tv.fill", "film.fill", "theatermasks.fill",
        // 소셜/기타
        "star.fill", "tag.fill", "gift.fill", "bell.fill", "person.2.fill",
        "globe", "map.fill", "location.fill", "lock.fill",
        // 집안일
        "flame", "refrigerator", "cup.and.saucer", "washer", "dryer",
        "bed.double", "trash", "arrow.3.trianglepath", "cart", "pawprint",
        "leaf", "shower", "lightbulb", "figure.and.child.holdinghands"
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
        let active = store.filter { $0.status == .active && !$0.isHidden }
        guard let pid else { return active }
        return active.filter { $0.plannerId == pid }
    }

    var archivedCategories: [Category] {
        let pid = PlannerService.shared.selectedPlanner?.id
        let archived = store.filter { $0.status == .archived }
        guard let pid else { return archived }
        return archived.filter { $0.plannerId == pid }
    }

    // MARK: - Fetch

    func fetchCategories() async -> [Category] {
        await refreshStore()
        return store.filter { $0.status == .active }
    }

    func fetchArchivedCategories() async -> [Category] {
        await refreshStore()
        return archivedCategories
    }

    func fetchCategories(for plannerId: String) async -> [Category] {
        await refreshStore()
        return store.filter { $0.status == .active && $0.plannerId == plannerId }
    }

    func fetchArchivedCategories(for plannerId: String) async -> [Category] {
        await refreshStore()
        return store.filter { $0.status == .archived && $0.plannerId == plannerId }
    }

    func refresh() async { await refreshStore() }

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
        let saved = cat
        await CategoryNotionSync.shared.onCategorySaved(saved)
    }

    func archiveCategory(id: String) async throws {
        let descriptor = FetchDescriptor<CategoryItem>(predicate: #Predicate { $0.id == id })
        guard let item = try context.fetch(descriptor).first else { return }
        item.statusRaw = CategoryStatus.archived.rawValue
        try context.save()
        await refreshStore()
    }

    private func clearTodoCategoryLinks(categoryId: String) {
        let todoDesc = FetchDescriptor<TodoItem>()
        guard let todos = try? context.fetch(todoDesc) else { return }
        for todo in todos where todo.categoryId == categoryId {
            todo.categoryId = nil
        }
    }

    func restoreCategory(id: String) async throws {
        let descriptor = FetchDescriptor<CategoryItem>(predicate: #Predicate { $0.id == id })
        guard let item = try context.fetch(descriptor).first else { return }
        item.statusRaw = CategoryStatus.active.rawValue
        try context.save()
        await refreshStore()
    }

    func deleteCategory(id: String) async throws {
        let catDesc = FetchDescriptor<CategoryItem>(predicate: #Predicate { $0.id == id })
        guard let item = try context.fetch(catDesc).first else { return }
        let category = item.toCategory()
        await CategoryNotionSync.shared.onCategoryDeleted(category)
        context.delete(item)

        let todoDesc = FetchDescriptor<TodoItem>()
        if let todos = try? context.fetch(todoDesc) {
            for todo in todos where todo.categoryId == id {
                todo.categoryName = category.name
                todo.categoryId = nil
            }
        }

        try context.save()
        await refreshStore()
    }

    func toggleHidden(id: String) async throws {
        let descriptor = FetchDescriptor<CategoryItem>(predicate: #Predicate { $0.id == id })
        guard let item = try context.fetch(descriptor).first else { return }
        item.isHidden.toggle()
        try context.save()
        await refreshStore()
    }

    /// 플래너 카테고리 colorHex만 일괄 갱신 (로컬 전용, Notion sync 없음).
    /// archived 제외, 활성·숨김 포함. sortOrder 순으로 세트 색 순환 배정.
    func recolorCategories(for plannerId: String, colors: [String]) async throws {
        guard !colors.isEmpty else { return }
        let descriptor = FetchDescriptor<CategoryItem>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let items = try context.fetch(descriptor).filter {
            $0.plannerId == plannerId && $0.status != .archived
        }
        for (index, item) in items.enumerated() {
            item.colorHex = colors[index % colors.count]
        }
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
