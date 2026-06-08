import Foundation
import SwiftUI

@Observable
final class CategoryViewModel {
    var categories: [Category] = []
    var archivedCategories: [Category] = []
    private(set) var isLoading: Bool = false

    var isSheetPresented: Bool = false
    var editName: String = ""
    var editColorHex: String = "#FD6845"
    var editIcon: String = "tag.fill"
    private var userDidSelectIcon: Bool = false

    var showArchiveAlert: Bool = false
    private(set) var archivingCategory: Category? = nil
    private(set) var pendingArchiveCount: Int = 0

    // showRestoreAlert, restoringCategory 제거 — 복원은 팝업 없이 즉시 실행

    var showDeleteAlert: Bool = false
    private(set) var deletingCategory: Category? = nil

    private var editingId: String? = nil
    private let service = CategoryService.shared
    private let todoService = TodoService.shared
    private let plannerId: String?

    init(plannerId: String? = nil) {
        self.plannerId = plannerId
    }

    var isEditing: Bool { editingId != nil }

    /// 노션 투두 DB 카테고리(select) 동기화가 켜진 플래너인지
    var isNotionCategorySyncEnabled: Bool {
        let pid = plannerId ?? PlannerService.shared.selectedPlanner?.id
        guard let pid,
              let planner = PlannerService.shared.store.first(where: { $0.id == pid }) else { return false }
        return CategoryNotionSync.shared.isSelectSyncEnabled(for: planner)
    }

    func deleteAlertMessage(for category: Category) -> String {
        let base = "'\(category.name)' 카테고리를 삭제할까요?\n이 카테고리를 사용하는 투두는 카테고리 없음으로 변경됩니다."
        if isNotionCategorySyncEnabled && category.isLinkedToNotion {
            return "'\(category.name)' 카테고리를 삭제할까요?\n노션 플래너의 카테고리 옵션도 함께 삭제됩니다.\n이 카테고리를 사용하는 투두는 카테고리 없음으로 변경됩니다."
        }
        return base
    }

    func archiveAlertMessage(for category: Category) -> String {
        var lines: [String] = []
        if pendingArchiveCount > 0 {
            lines.append("\(category.name) 카테고리에 미완료 할일 \(pendingArchiveCount)개가 있어요.")
        }
        if isNotionCategorySyncEnabled {
            lines.append("보관하면 앱에서만 카테고리가 숨겨집니다. 노션 플래너에는 그대로 유지돼요.")
        } else {
            lines.append("보관하면 앱에서만 카테고리가 숨겨집니다.")
        }
        return lines.joined(separator: "\n")
    }

    var editingCategory: Category? {
        guard let id = editingId else { return nil }
        return categories.first { $0.id == id }
    }

    // MARK: - Data

    func fetchCategories() async {
        isLoading = true
        let pid = plannerId ?? PlannerService.shared.selectedPlanner?.id
        if let pid {
            await CategoryNotionSync.shared.syncCategoriesByName(plannerId: pid)
            async let active = service.fetchCategories(for: pid)
            async let archived = service.fetchArchivedCategories(for: pid)
            categories = await active
            archivedCategories = await archived
        } else {
            async let active = service.fetchCategories()
            async let archived = service.fetchArchivedCategories()
            categories = await active
            archivedCategories = await archived
        }
        isLoading = false
    }

    func moveCategory(from source: IndexSet, to destination: Int) {
        categories.move(fromOffsets: source, toOffset: destination)
        service.reorderActiveCategories(categories)
    }

    // MARK: - Sheet

    func openAddSheet() {
        editingId = nil
        editName = ""
        editColorHex = "#FD6845"
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
        // 집안일
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

    func saveEdit() async {
        let trimmed = editName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

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

    // MARK: - Archive

    func requestArchive(_ category: Category) async {
        let count = await todoService.incompleteTodoCount(for: category.id)
        archivingCategory = category
        pendingArchiveCount = count
        if count > 0 || isNotionCategorySyncEnabled {
            showArchiveAlert = true
        } else {
            await confirmArchive(category)
        }
    }

    func confirmArchive(_ category: Category) async {
        withAnimation(.easeOut(duration: 0.25)) {
            categories.removeAll { $0.id == category.id }
        }
        try? await Task.sleep(nanoseconds: 280_000_000)
        withAnimation(.easeOut(duration: 0.25)) {
            var archived = category
            archived.status = .archived
            archivedCategories.append(archived)
        }
        try? await service.archiveCategory(id: category.id)
        archivingCategory = nil
        pendingArchiveCount = 0
        showArchiveAlert = false
        isSheetPresented = false
    }

    func cancelArchive() {
        archivingCategory = nil
        pendingArchiveCount = 0
        showArchiveAlert = false
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
            archivedCategories.removeAll { $0.id == category.id }
        }
        try? await service.deleteCategory(id: category.id)
        deletingCategory = nil
        isSheetPresented = false
    }

    // MARK: - Restore

    func confirmRestore(_ category: Category) async {
        withAnimation(.easeOut(duration: 0.25)) {
            archivedCategories.removeAll { $0.id == category.id }
        }
        try? await Task.sleep(nanoseconds: 280_000_000)
        withAnimation(.easeOut(duration: 0.25)) {
            var restored = category
            restored.status = .active
            categories.append(restored)
        }
        try? await service.restoreCategory(id: category.id)
    }
}
