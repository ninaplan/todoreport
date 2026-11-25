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

    // MARK: 색 세트
    /// 편집 시트의 색 세트 탭 (보기만. 탭을 바꿔도 플래너 세트는 그대로)
    private(set) var editColorSetTab: String = CategoryColorSet.basicId
    /// 이번 편집에서 칩을 고른 세트. 저장할 때 플래너 세트가 된다 (nil = 색을 안 바꿈)
    private var pickedColorSetId: String?
    /// 이번 편집에서 커스텀에서 뺀 색 (대문자). 지금 카테고리 색이어도 커스텀 첫 칸에 다시 보이거나 저장 때 다시 들어가지 않게
    private(set) var removedCustomHexes: Set<String> = []
    /// 저장 후 「이 플래너 카테고리 색을 모두 이 세트로 바꿀까요?」
    private(set) var showRecolorAlert = false
    private var recolorFromSetId: String?
    private var recolorToSetId: String?

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
        return Category.pickColor(used: used, setId: plannerColorSetId)
    }

    private var resolvedPlannerId: String? { plannerId ?? PlannerService.shared.selectedPlanner?.id }

    /// 이 플래너가 고른 색 세트
    private var plannerColorSetId: String {
        PlannerService.shared.categoryColorSetId(plannerId: resolvedPlannerId)
    }

    /// 편집을 열 때 탭: 지금 색이 들어 있는 세트, 없으면 커스텀
    private func initialColorSetTab(for hex: String) -> String {
        CategoryColorSet.setId(containing: hex) ?? CategoryColorSet.customId
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
        editColorSetTab = plannerColorSetId
        pickedColorSetId = nil
        removedCustomHexes = []
        editIcon = Category.randomIcon(excluding: Set(categories.map(\.icon)))
        userDidSelectIcon = false
        isSheetPresented = true
    }

    func openEditSheet(_ category: Category) {
        editingId = category.id
        editName = category.name
        editColorHex = category.colorHex
        editColorSetTab = initialColorSetTab(for: category.colorHex)
        pickedColorSetId = nil
        removedCustomHexes = []
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
        pickedColorSetId = editColorSetTab
        removedCustomHexes.remove(hex.uppercased())
    }

    func selectColorSetTab(_ setId: String) {
        editColorSetTab = setId
    }

    /// 커스텀 「＋ 추가」: 팔레트에만 넣는다 (이 카테고리 색은 그대로)
    func addCustomColor(_ hex: String) {
        CategoryCustomColorStore.shared.add(hex)
        removedCustomHexes.remove(hex.uppercased())
    }

    func removeCustomColor(_ hex: String) {
        CategoryCustomColorStore.shared.remove(hex)
        removedCustomHexes.insert(hex.uppercased())
    }

    // MARK: - 색 세트 일괄 변경 (저장 후 물음)

    /// 「바꾸기」: 옛 세트 색을 쓰던 카테고리를 새 세트 같은 자리 색으로 (직접 고른 색은 그대로)
    func confirmRecolor() async {
        let from = recolorFromSetId
        let to = recolorToSetId
        clearRecolor()
        guard let from, let to, let pid = resolvedPlannerId else { return }
        await service.recolorCategories(
            plannerId: pid,
            from: CategoryColorSet.colors(for: from),
            to: CategoryColorSet.colors(for: to)
        )
        await fetchCategories()
    }

    func dismissRecolorAlert() {
        showRecolorAlert = false
    }

    /// 「이 카테고리만」: 이 카테고리만 바뀐 채로
    func cancelRecolor() {
        clearRecolor()
    }

    private func clearRecolor() {
        showRecolorAlert = false
        recolorFromSetId = nil
        recolorToSetId = nil
    }

    /// 칩을 고른 세트가 플래너 세트와 다르면 플래너 세트로 정하고, 옛 세트 색을 쓰는 다른 카테고리가 있으면 물어본다
    private func applyPickedColorSet(savedCategoryId: String) {
        // 커스텀 칩을 골랐거나, 어느 세트에도 없는 색(커스텀 탭 첫 칸에 잠깐 보이던 색)이면 커스텀에 넣는다
        if !removedCustomHexes.contains(editColorHex.uppercased()),
           pickedColorSetId == CategoryColorSet.customId
            || CategoryColorSet.setId(containing: editColorHex) == nil {
            CategoryCustomColorStore.shared.add(editColorHex)
        }
        guard let picked = pickedColorSetId, let pid = resolvedPlannerId else { return }
        let current = plannerColorSetId
        guard picked != current else { return }
        PlannerService.shared.setCategoryColorSetId(picked, plannerId: pid)
        let oldColors = Set(CategoryColorSet.colors(for: current).map { $0.uppercased() })
        let hasOthers = service.store.contains {
            $0.plannerId == pid && $0.id != savedCategoryId && oldColors.contains($0.colorHex.uppercased())
        }
        guard hasOthers else { return }
        recolorFromSetId = current
        recolorToSetId = picked
        // 편집 시트가 닫히는 중에 알림을 띄우면 안 뜰 수 있어 잠깐 기다린다
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            showRecolorAlert = true
        }
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
        applyPickedColorSet(savedCategoryId: updated.id)
        pickedColorSetId = nil
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
