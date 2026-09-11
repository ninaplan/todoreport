import SwiftUI

/// 투두 날짜 변경 시트 (일별 목록·인박스 공용).
struct TodoDateChangeSheet: View {
    let initialDate: Date
    var navigationTitleKey: String = "날짜 변경"
    let onConfirm: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date

    private var localizedCalendar: Calendar { AppCalendar.localized }

    init(
        initialDate: Date,
        navigationTitleKey: String = "날짜 변경",
        onConfirm: @escaping (Date) -> Void
    ) {
        self.initialDate = initialDate
        self.navigationTitleKey = navigationTitleKey
        self.onConfirm = onConfirm
        _selectedDate = State(initialValue: Calendar.current.startOfDay(for: initialDate))
    }

    var body: some View {
        NavigationStack {
            DatePicker(
                String(localized: "날짜 선택"),
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(AppTheme.shared.accent)
            .environment(\.calendar, localizedCalendar)
            .padding(.horizontal)
            .navigationTitle(String(localized: String.LocalizationValue(navigationTitleKey)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                        .toolbarSecondaryActionStyle()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") {
                        onConfirm(selectedDate)
                        dismiss()
                    }
                    .toolbarPrimaryActionStyle()
                }
            }
        }
        .presentationDetents([.medium])
    }
}
