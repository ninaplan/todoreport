import Foundation

@Observable
final class CategoryViewModel {
    private(set) var categories: [Category] = []
    private(set) var isLoading: Bool = false

    var isSheetPresented: Bool = false
    var editName: String = ""
    var editColorHex: String = Category.colorPalette.first ?? "#FD6845"

    private var editingId: String? = nil
    private let service: CategoryService

    init(service: CategoryService = CategoryService()) {
        self.service = service
    }

    var isEditing: Bool { editingId != nil }

    // MARK: - Data

    func fetchCategories() async {
        isLoading = true
        categories = await service.fetchCategories()
        isLoading = false
    }

    // MARK: - Sheet

    func openAddSheet() {
        editingId = nil
        editName = ""
        editColorHex = Category.colorPalette.first ?? "#FD6845"
        isSheetPresented = true
    }

    func openEditSheet(_ category: Category) {
        editingId = category.id
        editName = category.name
        editColorHex = category.colorHex
        isSheetPresented = true
    }

    // MARK: - Actions

    func saveEdit() async {
        let trimmed = editName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let updated: Category
        if let id = editingId,
           let existing = categories.first(where: { $0.id == id }) {
            var copy = existing
            copy.name = trimmed
            copy.colorHex = editColorHex
            updated = copy
        } else {
            updated = Category(name: trimmed, colorHex: editColorHex)
        }

        try? await service.saveCategory(updated)
        await fetchCategories()
        isSheetPresented = false
    }

    func deleteCategory(_ category: Category) async {
        categories.removeAll { $0.id == category.id }
        try? await service.deleteCategory(id: category.id)
    }
}
