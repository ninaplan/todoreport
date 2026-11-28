import Foundation
import SwiftData
import Observation

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

    static let baseColors: [String] = [
        "#FF3B30", "#FFCC00", "#34C759", "#00C7BE",
        "#007AFF", "#5856D6", "#AF52DE", "#FF2D55",
        "#A2845E", "#8E8E93", "#FD6845", "#000000"
    ]

    /// 같은 플래너에서 아직 안 쓴 아이콘 중 랜덤. 모두 쓰였으면 전체에서 랜덤.
    /// 새 카테고리가 전부 태그 모양으로 보이지 않게 하기 위함. 채움·라인은 같은 아이콘으로 본다 (`house` = `house.fill`)
    /// 새 카테고리 기본 모양은 채움
    static func randomIcon(excluding used: Set<String>) -> String {
        let usedBase = Set(used.map(CategoryIconName.baseName))
        let unused = iconPalette.filter { !usedBase.contains($0) && $0 != "tag" }
        let base = unused.randomElement() ?? iconPalette.randomElement() ?? "tag"
        return CategoryIconName.make(base: base, filled: true)
    }

    /// 미사용 색 우선. 세트 색이 모두 쓰이면 세트 안에서 랜덤. 세트가 비어 있으면(커스텀이 빈 경우) 기본 세트
    static func pickColor(used: Set<String>, setId: String = CategoryColorSet.defaultId) -> String {
        var palette = CategoryColorSet.colors(for: setId)
        if palette.isEmpty { palette = CategoryColorSet.colors(for: CategoryColorSet.defaultId) }
        let usedNormalized = Set(used.map { $0.uppercased() })
        let unused = palette.filter { !usedNormalized.contains($0.uppercased()) }
        if let pick = unused.randomElement() {
            return pick
        }
        return palette.randomElement() ?? baseColors[0]
    }

    /// 이름으로 추정한 아이콘, 없으면 겹치지 않는 무작위 (추정한 아이콘은 겹쳐도 그대로 쓴다)
    static func suggestedIcon(for name: String, excluding used: Set<String>) -> String {
        if let guessed = CategoryIconGuesser.icon(for: name) {
            return CategoryIconName.make(base: guessed, filled: true)
        }
        return randomIcon(excluding: used)
    }

    /// 아이콘 고르기 페이지 (분야별, 한 페이지 최대 18개 = 3줄 × 6칸).
    /// 이름은 라인 기본 이름. 채움·라인은 카테고리마다 고른다 (`CategoryIconName`).
    static let iconGroups: [CategoryIconGroup] = [
        CategoryIconGroup(id: "study", title: "공부", icons: [
            "book", "books.vertical", "text.book.closed", "character.book.closed", "pencil", "pencil.and.ruler",
            "graduationcap", "brain.head.profile", "note.text", "function", "magnifyingglass", "lightbulb",
        ]),
        CategoryIconGroup(id: "work", title: "업무", icons: [
            "briefcase", "desktopcomputer", "laptopcomputer", "keyboard", "doc.text", "folder",
            "list.clipboard", "checklist", "tray.full", "paperplane", "envelope", "phone",
            "bubble.left.and.bubble.right", "printer", "chart.line.uptrend.xyaxis", "newspaper",
        ]),
        CategoryIconGroup(id: "health", title: "운동·건강", icons: [
            "figure.run", "figure.walk", "figure.yoga", "figure.pool.swim", "figure.strengthtraining.traditional", "dumbbell",
            "bicycle", "soccerball", "tennis.racket", "heart", "cross", "pills",
            "drop", "moon.zzz", "figure.mind.and.body",
        ]),
        CategoryIconGroup(id: "food", title: "식생활", icons: [
            "fork.knife", "frying.pan", "carrot", "takeoutbag.and.cup.and.straw", "cup.and.saucer", "mug",
            "birthday.cake", "refrigerator", "cart",
        ]),
        CategoryIconGroup(id: "home", title: "집안일", icons: [
            "house", "sofa", "bubbles.and.sparkles", "washer", "dryer", "basket",
            "shower", "bathtub", "bed.double", "trash", "wrench.and.screwdriver",
        ]),
        CategoryIconGroup(id: "family", title: "육아·가족", icons: [
            "figure.and.child.holdinghands", "figure.2.and.child.holdinghands", "stroller", "teddybear", "person.2", "gift",
        ]),
        CategoryIconGroup(id: "money", title: "돈", icons: [
            "wonsign.circle", "banknote", "creditcard", "chart.pie", "building.columns", "bag",
        ]),
        CategoryIconGroup(id: "nature", title: "반려동물·자연", icons: [
            "pawprint", "dog", "cat", "fish", "bird", "leaf",
            "tree", "sun.max",
        ]),
        CategoryIconGroup(id: "travel", title: "이동", icons: [
            "car", "bus", "tram", "airplane", "suitcase", "map",
            "location", "globe",
        ]),
        CategoryIconGroup(id: "hobby", title: "휴식·취미", icons: [
            "music.note", "headphones", "music.mic", "guitars", "camera", "paintbrush",
            "gamecontroller", "puzzlepiece", "tv", "film", "theatermasks", "face.smiling",
        ]),
        CategoryIconGroup(id: "goal", title: "목표·시간", icons: [
            "target", "flag", "trophy", "star", "flame", "arrow.3.trianglepath",
            "timer", "hourglass", "clock", "calendar", "bell",
        ]),
        CategoryIconGroup(id: "etc", title: "기타", icons: [
            "tag", "lock",
        ]),
    ]

    /// 전체 아이콘 (무작위 배정용)
    static let iconPalette: [String] = iconGroups.flatMap(\.icons)
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

    /// 선택된 플래너의 활성 카테고리 (할 일 추가·수집함 등). 다른 플래너 카테고리가 섞이지 않게 거른다
    func fetchCategories() async -> [Category] {
        await refreshStore()
        let active = store.filter { $0.status == .active }
        guard let pid = PlannerService.shared.selectedPlanner?.id else { return active }
        return active.filter { $0.plannerId == pid }
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

    /// 세트를 바꿀 때 「모두 이 세트로」: 옛 세트 색을 쓰던 카테고리를 새 세트의 같은 자리 색으로 (직접 고른 색은 그대로).
    /// 새 세트 색이 더 적으면(커스텀) 돌려 가며 쓴다. 바뀐 개수를 돌려준다
    @discardableResult
    func recolorCategories(plannerId: String, from oldColors: [String], to newColors: [String]) async -> Int {
        guard !newColors.isEmpty else { return 0 }
        let upperOld = oldColors.map { $0.uppercased() }
        let items = (try? context.fetch(FetchDescriptor<CategoryItem>())) ?? []
        var changed = 0
        for item in items where item.plannerId == plannerId {
            guard let index = upperOld.firstIndex(of: item.colorHex.uppercased()) else { continue }
            let newHex = newColors[index % newColors.count]
            guard newHex.uppercased() != item.colorHex.uppercased() else { continue }
            item.colorHex = newHex
            changed += 1
        }
        guard changed > 0 else { return 0 }
        try? context.save()
        await refreshStore()
        return changed
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
