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
    var editColorHex: String = Category.baseColors[0]
    var editIcon: String = "tag.fill"
    private var userDidSelectIcon: Bool = false

    var showDeleteAlert: Bool = false
    private(set) var deletingCategory: Category? = nil

    var showOfflineCategoryAlert: Bool = false
    var showNotionNameChangeAlert: Bool = false

    private var editingId: String? = nil
    private let service = CategoryService.shared
    private let plannerId: String?

    init(plannerId: String? = nil) {
        self.plannerId = plannerId
        updateNotionSyncVisibility()
    }

    var isEditing: Bool { editingId != nil }

    private func currentPlanner() -> Planner? {
        let pid = plannerId ?? PlannerService.shared.selectedPlanner?.id
        guard let pid else { return nil }
        return PlannerService.shared.store.first(where: { $0.id == pid })
    }

    private var isOfflineNotionSelect: Bool {
        isNotionCategorySyncEnabled && !NetworkMonitor.shared.isConnected
    }

    private func updateNotionSyncVisibility() {
        PlannerService.shared.reloadFromStore()
        let planner = currentPlanner()
        isNotionCategorySyncEnabled = planner.map { CategoryNotionSync.shared.isSelectSyncEnabled(for: $0) } ?? false
    }

    /// 현재 플래너 카테고리가 쓰는 색만 모아 미사용 우선 랜덤.
    private func pickDefaultColor() -> String {
        let pid = plannerId ?? PlannerService.shared.selectedPlanner?.id
        let used: Set<String>
        if let pid {
            used = Set(service.store.filter { $0.plannerId == pid }.map(\.colorHex))
        } else {
            used = Set(categories.map(\.colorHex))
        }
        return Category.pickColor(used: used)
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
        guard !isOfflineNotionSelect else {
            showOfflineCategoryAlert = true
            return
        }
        editingId = nil
        editName = ""
        editColorHex = pickDefaultColor()
        editIcon = Category.randomIcon(excluding: Set(categories.map(\.icon)))
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

    /// 새 카테고리 이름을 치는 동안 이름에 맞는 아이콘으로 바꾼다 (직접 고른 뒤에는 그대로).
    /// 낱말 사전은 `CategoryIconGuesser` (노션에서 가져올 때도 같은 사전)
    func autoMatchIcon(for name: String) {
        guard !userDidSelectIcon else { return }
        guard let icon = CategoryIconGuesser.icon(for: name) else { return }
        // 지금 고른 모양(채움·라인)은 그대로
        editIcon = CategoryIconName.make(base: icon, filled: CategoryIconName.isFilled(editIcon))
    }

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

        let trimmed = editName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if !isEditing, isOfflineNotionSelect {
            showOfflineCategoryAlert = true
            return
        }

        isSaving = true
        defer { isSaving = false }

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
        guard !isOfflineNotionSelect else {
            showOfflineCategoryAlert = true
            return
        }
        deletingCategory = category
        showDeleteAlert = true
    }

    func cancelDelete() {
        deletingCategory = nil
        showDeleteAlert = false
    }

    func cancelOfflineCategoryAlert() {
        showOfflineCategoryAlert = false
    }

    func confirmOfflineCategoryAlert() {
        showOfflineCategoryAlert = false
    }

    func confirmDelete() async {
        guard let category = deletingCategory else { return }
        guard !isOfflineNotionSelect else {
            cancelDelete()
            showOfflineCategoryAlert = true
            return
        }
        withAnimation(.default) {
            categories.removeAll { $0.id == category.id }
        }
        try? await service.deleteCategory(id: category.id)
        deletingCategory = nil
        isSheetPresented = false
    }
}
