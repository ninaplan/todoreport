import SwiftUI

struct QuickCaptureView: View {
    let defaultCategoryId: String?
    @State private var viewModel = QuickCaptureViewModel()
    @Environment(\.dismiss) private var dismiss
    let onSave: (String, String?, String?, Date, Date?, Int?, RecurrenceRule?, Date?, Int?) -> Void

    init(defaultCategoryId: String? = nil, onSave: @escaping (String, String?, String?, Date, Date?, Int?, RecurrenceRule?, Date?, Int?) -> Void) {
        self.defaultCategoryId = defaultCategoryId
        self.onSave = onSave
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
                    recurrence: $viewModel.recurrenceRule,
                    recurrenceEndDate: $viewModel.recurrenceEndDate,
                    recurrenceCount: $viewModel.recurrenceCount,
                    categories: viewModel.categories,
                    isPro: UserDefaults.standard.bool(forKey: "debugIsPro"),
                    onRepeatTap: { viewModel.showProAlert = true }
                )
            }
            .navigationTitle("할일 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소", role: .cancel) { dismiss() }
                        .foregroundStyle(.secondary)
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
                    .tint(viewModel.isSaveEnabled ? AppTheme.shared.accent : Color(.tertiaryLabel))
                    .fontWeight(.semibold)
                }
            }
            .alert("Pro 기능", isPresented: $viewModel.showProAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text("반복 투두는 Pro 구독 기능입니다.")
            }
            .task {
                await viewModel.fetchCategories()
                viewModel.selectedCategoryId = defaultCategoryId
            }
        }
        .presentationDetents([.large])
    }
}

