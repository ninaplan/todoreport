import SwiftUI

struct QuickCaptureView: View {
    let defaultCategoryId: String?
    @State private var viewModel: QuickCaptureViewModel
    @Environment(\.dismiss) private var dismiss
    let onSave: (String, String?, String?, Date, Date?, Int?, RecurrenceRule?, Date?, Int?) -> Void

    init(defaultCategoryId: String? = nil, initialDate: Date = .now, onSave: @escaping (String, String?, String?, Date, Date?, Int?, RecurrenceRule?, Date?, Int?) -> Void) {
        self.defaultCategoryId = defaultCategoryId
        self.onSave = onSave
        _viewModel = State(initialValue: QuickCaptureViewModel(initialDate: initialDate))
    }

    var body: some View {
        NavigationStack {
            Form {
                TodoEditFormView(
                    title: $viewModel.title,
                    memo: $viewModel.memo,
                    categoryId: $viewModel.selectedCategoryId,
                    date: $viewModel.selectedDate,
                    showDatePicker: $viewModel.showDatePicker,
                    scheduledTime: $viewModel.scheduledTime,
                    alarmOffset: $viewModel.alarmOffset,
                    categories: viewModel.categories
                )
            }
            .navigationTitle("할일 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소", role: .cancel) { dismiss() }
                        .toolbarSecondaryActionStyle()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        let memo = viewModel.memo.trimmingCharacters(in: .whitespaces)
                        onSave(
                            viewModel.title.trimmingCharacters(in: .whitespaces),
                            memo.isEmpty ? nil : memo,
                            viewModel.selectedCategoryId,
                            viewModel.selectedDate,
                            viewModel.scheduledTime,
                            viewModel.alarmOffset,
                            viewModel.recurrenceRule,
                            viewModel.recurrenceEndDate,
                            viewModel.recurrenceCount
                        )
                        dismiss()
                    }
                    .disabled(!viewModel.isSaveEnabled)
                    .toolbarPrimaryActionStyle(isEnabled: viewModel.isSaveEnabled)
                }
            }
            .task {
                await viewModel.fetchCategories()
                viewModel.selectedCategoryId = defaultCategoryId
            }
        }
        .presentationDetents([.large])
    }
}

