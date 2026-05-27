import Foundation
import SwiftUI

@Observable
final class CategoryViewModel {
    var categories: [Category] = []
    var archivedCategories: [Category] = []
    private(set) var isLoading: Bool = false

    var isSheetPresented: Bool = false
    var editName: String = ""
    var editColorHex: String = Category.colorPalette.first ?? "#FD6845"
    var editIcon: String = Category.iconPalette.first ?? "tag.fill"

    var showArchiveAlert: Bool = false
    private(set) var archivingCategory: Category? = nil
    private(set) var pendingArchiveCount: Int = 0

    var showRestoreAlert: Bool = false
    private(set) var restoringCategory: Category? = nil

    private var editingId: String? = nil
    private let service = CategoryService.shared
    private let todoService = TodoService.shared

    var isEditing: Bool { editingId != nil }

    var editingCategory: Category? {
        guard let id = editingId else { return nil }
        return categories.first { $0.id == id }
    }

    // MARK: - Data

    func fetchCategories() async {
        isLoading = true
        async let active = service.fetchCategories()
        async let archived = service.fetchArchivedCategories()
        categories = await active
        archivedCategories = await archived
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
        editColorHex = Category.colorPalette.first ?? "#FD6845"
        editIcon = Category.iconPalette.first ?? "tag.fill"
        isSheetPresented = true
    }

    func openEditSheet(_ category: Category) {
        editingId = category.id
        editName = category.name
        editColorHex = category.colorHex
        editIcon = category.icon
        isSheetPresented = true
    }

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
            updated = Category(name: trimmed, colorHex: editColorHex, icon: editIcon)
        }

        try? await service.saveCategory(updated)
        await fetchCategories()
        isSheetPresented = false
    }

    // MARK: - Archive

    func requestArchive(_ category: Category) async {
        let count = await todoService.incompleteTodoCount(for: category.id)
        if count > 0 {
            archivingCategory = category
            pendingArchiveCount = count
            showArchiveAlert = true
        } else {
            await confirmArchive(category)
        }
    }

    func confirmArchive(_ category: Category) async {
        categories.removeAll { $0.id == category.id }
        var archived = category
        archived.status = .archived
        archivedCategories.append(archived)
        try? await service.archiveCategory(id: category.id)
        archivingCategory = nil
        pendingArchiveCount = 0
        isSheetPresented = false
    }

    func cancelArchive() {
        archivingCategory = nil
        pendingArchiveCount = 0
    }

    // MARK: - Restore

    func requestRestore(_ category: Category) {
        restoringCategory = category
        showRestoreAlert = true
    }

    func cancelRestore() {
        restoringCategory = nil
        showRestoreAlert = false
    }

    func confirmRestore() async {
        guard let category = restoringCategory else { return }
        archivedCategories.removeAll { $0.id == category.id }
        var restored = category
        restored.status = .active
        categories.append(restored)
        try? await service.restoreCategory(id: category.id)
        restoringCategory = nil
    }
}
