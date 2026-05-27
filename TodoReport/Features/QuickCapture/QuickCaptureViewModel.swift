import Foundation

@Observable
final class QuickCaptureViewModel {
    var title: String = ""
    var memo: String = ""
    var selectedCategoryId: String? = nil
    var selectedDate: Date = .now
    var showDatePicker: Bool = false
    var showProAlert: Bool = false

    var isSaveEnabled: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
