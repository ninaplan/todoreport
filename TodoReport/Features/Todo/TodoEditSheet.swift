import SwiftUI

/// 투두 편집 시트 (일별 목록·인박스 공용).
struct TodoEditSheet: View {
    let categories: [Category]
    let onSave: (Todo) -> Void
    let onDeleteTapped: ((Todo) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Todo
    @State private var showDatePicker = false

    init(
        todo: Todo,
        categories: [Category],
        onSave: @escaping (Todo) -> Void,
        onDeleteTapped: ((Todo) -> Void)? = nil
    ) {
        self.categories = categories
        self.onSave = onSave
        self.onDeleteTapped = onDeleteTapped
        _draft = State(initialValue: RecurringTodoManager.shared.attachingSeries(to: todo))
    }

    private var isSaveEnabled: Bool {
        !draft.title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                Form {
                    TodoEditFormView(
                        title: $draft.title,
                        memo: Binding(
                            get: { draft.memo ?? "" },
                            set: { draft.memo = $0.isEmpty ? nil : $0 }
                        ),
                        categoryId: $draft.categoryId,
                        date: $draft.date,
                        showDatePicker: $showDatePicker,
                        scheduledTime: $draft.scheduledTime,
                        alarmOffset: $draft.alarmOffset,
                        recurrenceRule: $draft.recurrenceRule,
                        recurrenceEndDate: $draft.recurrenceEndDate,
                        recurrenceCount: $draft.recurrenceCount,
                        categories: categories,
                        autoFocus: false,
                        scrollToAnchor: { id in
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(80))
                                withAnimation {
                                    proxy.scrollTo(id, anchor: .bottom)
                                }
                            }
                        }
                    )

                    if onDeleteTapped != nil {
                        Section {
                            Button("삭제") {
                                onDeleteTapped?(draft)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소", role: .cancel) { dismiss() }
                        .toolbarSecondaryActionStyle()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        let trimmed = draft.title.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        var saved = draft
                        saved.title = trimmed
                        if let date = draft.date {
                            TodoScheduledTime.applyingDateChange(to: &saved, newDate: date)
                        }
                        onSave(saved)
                        dismiss()
                    }
                    .disabled(!isSaveEnabled)
                    .toolbarPrimaryActionStyle(isEnabled: isSaveEnabled)
                }
            }
        }
        .presentationDetents([.large])
    }
}
