import SwiftUI

/// 블록을 눌렀을 때: 시작·끝 시각을 분 단위로 고치거나 블록 삭제 (할 일은 지우지 않음).
struct TimeBlockEditSheet: View {
    let entry: TimeBlockEntry
    let onSave: (Date, Date) -> Void
    let onDelete: () -> Void
    let onClose: () -> Void

    @State private var start: Date
    @State private var end: Date

    init(
        entry: TimeBlockEntry,
        onSave: @escaping (Date, Date) -> Void,
        onDelete: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.entry = entry
        self.onSave = onSave
        self.onDelete = onDelete
        self.onClose = onClose
        _start = State(initialValue: TimeBlockLayout.date(day: entry.block.day, minute: entry.block.startMinute))
        _end = State(initialValue: TimeBlockLayout.date(day: entry.block.day, minute: entry.block.endMinute))
    }

    private var isValid: Bool { end > start }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(entry.title)
                        .font(.body.weight(.medium))
                        .lineLimit(3)
                }
                Section {
                    DatePicker("시작", selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker("종료", selection: $end, displayedComponents: .hourAndMinute)
                } footer: {
                    if !isValid {
                        Text("끝나는 시각은 시작 시각보다 늦어야 합니다.")
                            .foregroundStyle(Color(.systemRed))
                    }
                }
                Section {
                    Button("블록 삭제", role: .destructive, action: onDelete)
                } footer: {
                    Text("블록만 삭제되고 할 일은 그대로 남습니다.")
                }
            }
            .navigationTitle("시간 변경")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CloseButton(action: onClose)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        onSave(start, end)
                    }
                    .toolbarPrimaryActionStyle(isEnabled: isValid)
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
