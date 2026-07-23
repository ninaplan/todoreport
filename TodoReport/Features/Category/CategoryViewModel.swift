import Foundation
import SwiftUI

@Observable
final class CategoryViewModel {
    var categories: [Category] = []
    private(set) var isLoading: Bool = false
    private(set) var isNotionCategorySyncEnabled: Bool = false

    var isSheetPresented: Bool = false
    var isSaving: Bool = false
    var editName: String = ""
    var editColorHex: String = CategoryPaletteSet.set(id: CategoryPaletteSet.defaultId).colors[0]
    var editIcon: String = "tag.fill"
    private var userDidSelectIcon: Bool = false

    var showDeleteAlert: Bool = false
    private(set) var deletingCategory: Category? = nil

    var showNotionNameChangeAlert: Bool = false

    private(set) var storedPaletteSetId: String = CategoryPaletteSet.defaultId

    private var editingId: String? = nil
    private let service = CategoryService.shared
    private let plannerId: String?

    init(plannerId: String? = nil) {
        self.plannerId = plannerId
        updateNotionSyncVisibility()
        syncStoredPaletteSetId()
    }

    var isEditing: Bool { editingId != nil }

    var activePaletteSetId: String { storedPaletteSetId }

    var activePaletteColors: [String] {
        CategoryPaletteSet.set(id: activePaletteSetId).colors
    }

    private func currentPlanner() -> Planner? {
        let pid = plannerId ?? PlannerService.shared.selectedPlanner?.id
        guard let pid else { return nil }
        return PlannerService.shared.store.first(where: { $0.id == pid })
    }

    private func updateNotionSyncVisibility() {
        PlannerService.shared.reloadFromStore()
        let planner = currentPlanner()
        isNotionCategorySyncEnabled = planner.map { CategoryNotionSync.shared.isSelectSyncEnabled(for: $0) } ?? false
    }

    private func syncStoredPaletteSetId() {
        storedPaletteSetId = currentPlanner()?.categoryPaletteSetId ?? CategoryPaletteSet.defaultId
    }

    func selectPaletteSet(_ setId: String) {
        guard let set = CategoryPaletteSet.all.first(where: { $0.id == setId }) else { return }
        guard let pid = plannerId ?? PlannerService.shared.selectedPlanner?.id else { return }
        PlannerService.shared.updateCategoryPaletteSetId(setId, for: pid)
        storedPaletteSetId = setId
        Task {
            do {
                try await service.recolorCategories(for: pid, colors: set.colors)
                categories = await service.fetchCategories(for: pid)
            } catch {
                AppLogger.shared.warn(
                    "CategoryViewModel",
                    "팔레트 재배색 실패 - planner:\(pid) set:\(setId) \(error.localizedDescription)"
                )
            }
        }
    }

    /// 현재 플래너 카테고리가 쓰는 색만 모아 미사용 우선 랜덤.
    private func pickDefaultColor() -> String {
        let palette = CategoryPaletteSet.set(id: activePaletteSetId)
        let pid = plannerId ?? PlannerService.shared.selectedPlanner?.id
        let used: Set<String>
        if let pid {
            used = Set(service.store.filter { $0.plannerId == pid }.map(\.colorHex))
        } else {
            used = Set(categories.map(\.colorHex))
        }
        return palette.pickColor(used: used)
    }

    func deleteAlertMessage(for category: Category) -> String {
        let base = "'\(category.name)' 카테고리를 삭제할까요?\n이 카테고리를 사용하는 투두는 카테고리 없음으로 변경됩니다."
        if isNotionCategorySyncEnabled && category.isLinkedToNotion {
            return "'\(category.name)' 카테고리를 삭제할까요?\n노션 플래너의 카테고리 옵션도 함께 삭제됩니다.\n이 카테고리를 사용하는 투두는 카테고리 없음으로 변경됩니다."
        }
        return base
    }

    var editingCategory: Category? {
        guard let id = editingId else { return nil }
        return categories.first { $0.id == id }
    }

    // MARK: - Data

    func fetchCategories() async {
        updateNotionSyncVisibility()
        syncStoredPaletteSetId()
        isLoading = true
        let pid = plannerId ?? PlannerService.shared.selectedPlanner?.id
        if let pid {
            await CategoryNotionSync.shared.syncCategoriesByName(plannerId: pid)
            categories = await service.fetchCategories(for: pid)
        } else {
            categories = await service.fetchCategories()
        }
        isLoading = false
    }

    func moveCategory(from source: IndexSet, to destination: Int) {
        categories.move(fromOffsets: source, toOffset: destination)
        service.reorderActiveCategories(categories)
    }

    func toggleHidden(_ category: Category) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }
        categories[index].isHidden.toggle()
        Task { try? await service.toggleHidden(id: category.id) }
    }

    // MARK: - Sheet

    func openAddSheet() {
        editingId = nil
        editName = ""
        syncStoredPaletteSetId()
        editColorHex = pickDefaultColor()
        editIcon = "tag.fill"
        userDidSelectIcon = false
        isSheetPresented = true
    }

    func openEditSheet(_ category: Category) {
        editingId = category.id
        editName = category.name
        editColorHex = category.colorHex
        editIcon = category.icon
        userDidSelectIcon = true
        isSheetPresented = true
    }

    func selectIcon(_ symbol: String) {
        editIcon = symbol
        userDidSelectIcon = true
    }

    func selectColor(_ hex: String) {
        editColorHex = hex
    }

    func autoMatchIcon(for name: String) {
        guard !userDidSelectIcon else { return }
        let lowered = name.lowercased()
        guard let entry = Self.keywordIconMap.first(where: { entry in
            entry.keywords.contains(where: { lowered.contains($0) })
        }) else { return }
        editIcon = entry.icon
    }

    private static let keywordIconMap: [(keywords: [String], icon: String)] = [
        (["운동", "헬스", "달리기", "걷기", "exercise", "workout", "run", "gym"], "figure.run"),
        (["공부", "학습", "수업", "강의", "study", "learn", "class"], "book.fill"),
        (["업무", "회사", "일", "work", "office", "job"], "briefcase.fill"),
        (["식사", "밥", "음식", "요리", "meal", "food", "cook", "eat", "lunch", "dinner"], "fork.knife"),
        (["음악", "music", "song", "playlist"], "music.note"),
        (["독서", "책", "reading", "book"], "book.fill"),
        (["쇼핑", "shopping", "buy", "purchase"], "cart.fill"),
        (["집", "청소", "house", "home", "clean"], "house.fill"),
        (["여행", "travel", "trip", "vacation"], "airplane"),
        (["게임", "gaming", "game"], "gamecontroller.fill"),
        (["사진", "포토", "photo", "camera"], "camera.fill"),
        (["건강", "병원", "health", "hospital", "medical"], "heart.fill"),
        (["친구", "약속", "모임", "friend", "meeting", "social"], "person.2.fill"),
        (["취미", "hobby"], "star.fill"),
        (["자전거", "cycling", "bicycle", "bike"], "bicycle"),
        (["카페", "커피", "coffee", "cafe"], "cup.and.saucer.fill"),
        (["운전", "차", "drive", "driving"], "car.fill"),
        (["기록", "메모", "일기", "note", "memo", "journal", "diary"], "note.text"),
        (["그림", "미술", "art", "draw", "paint", "design"], "paintbrush.fill"),
        (["알림", "notification", "reminder", "bell"], "bell.fill"),
        (["목표", "goal", "target"], "flag.fill"),
        (["영화", "드라마", "movie", "film", "drama"], "film.fill"),
        (["tv", "티비", "television", "넷플릭스"], "tv.fill"),
        (["세탁", "빨래", "세탁기", "laundry", "wash"], "washer"),
        (["건조", "건조기", "dryer", "dry"], "dryer"),
        (["침대", "잠자리", "bed", "sleep", "bedding"], "bed.double"),
        (["쓰레기", "분리수거", "trash", "recycle", "garbage"], "trash"),
        (["반려동물", "강아지", "고양이", "dog", "cat", "pet", "animal"], "pawprint"),
        (["식물", "화분", "물주기", "plant", "garden", "flower"], "leaf"),
        (["욕실", "샤워", "청소", "bathroom", "shower", "toilet"], "shower"),
        (["집수리", "수리", "repair", "fix", "diy", "전구"], "lightbulb"),
        (["육아", "아이", "아기", "어린이", "child", "baby", "kids", "parenting"], "figure.and.child.holdinghands"),
        (["냉장고", "주방", "refrigerator", "fridge", "kitchen"], "refrigerator"),
        (["장보기", "마트", "슈퍼", "grocery", "mart", "supermarket"], "cart"),
    ]

    // MARK: - Save

    func requestNotionNameChangeAlert() {
        showNotionNameChangeAlert = true
    }

    func cancelNotionNameChange() {
        showNotionNameChangeAlert = false
    }

    func confirmNotionNameChange() {
        showNotionNameChangeAlert = false
    }

    func saveEdit() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        let trimmed = editName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if isEditing,
           isNotionCategorySyncEnabled,
           trimmed != editingCategory?.name {
            showNotionNameChangeAlert = true
            return
        }

        let updated: Category
        if let id = editingId,
           let existing = categories.first(where: { $0.id == id }) {
            var copy = existing
            copy.name = trimmed
            copy.colorHex = editColorHex
            copy.icon = editIcon
            updated = copy
        } else {
            updated = Category(name: trimmed, colorHex: editColorHex, icon: editIcon, plannerId: plannerId)
        }

        try? await service.saveCategory(updated)
        await fetchCategories()
        isSheetPresented = false
    }

    // MARK: - Delete

    func requestDelete(_ category: Category) {
        deletingCategory = category
        showDeleteAlert = true
    }

    func cancelDelete() {
        deletingCategory = nil
        showDeleteAlert = false
    }

    func confirmDelete() async {
        guard let category = deletingCategory else { return }
        withAnimation(.default) {
            categories.removeAll { $0.id == category.id }
        }
        try? await service.deleteCategory(id: category.id)
        deletingCategory = nil
        isSheetPresented = false
    }
}
