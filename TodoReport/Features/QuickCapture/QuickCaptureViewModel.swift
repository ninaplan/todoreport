import Foundation

@Observable
final class QuickCaptureViewModel {
    var title: String = ""
    var memo: String = ""
    var selectedCategoryId: String? = nil
    var selectedDate: Date
    var showDatePicker: Bool = false
    var showProAlert: Bool = false
    var scheduledTime: Date? = nil
    var alarmOffset: Int? = nil
    var recurrenceRule: RecurrenceRule? = nil
    var recurrenceEndDate: Date? = nil
    var recurrenceCount: Int? = nil
    private(set) var categories: [Category] = []

    private let categoryService = CategoryService.shared

    init(initialDate: Date = .now) {
        self.selectedDate = initialDate
    }

    var isSaveEnabled: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func fetchCategories() async {
        categories = await categoryService.fetchCategories()
    }
}
