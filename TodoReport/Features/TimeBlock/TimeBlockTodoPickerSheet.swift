import SwiftUI

/// 빈 칸을 눌렀을 때: 그날 할 일 고르기 / 새 할 일 추가.
/// 이미 넣은 할 일도 흐리게 하지 않고 시간 태그만 달아 「또 넣을 수 있음」을 보여준다.
struct TimeBlockTodoPickerSheet: View {
    let request: TimeBlockSlotRequest
    let options: [TimeBlockTodoOption]
    let onPick: (TimeBlockTodoOption) -> Void
    let onCreate: (String) -> Void
    let onClose: () -> Void

    @State private var newTitle = ""

    private var unplaced: [TimeBlockTodoOption] { options.filter { !$0.isPlaced } }
    private var placed: [TimeBlockTodoOption] { options.filter(\.isPlaced) }

    private var rangeTitle: String {
        let start = TimeBlockLayout.date(day: request.day, minute: request.startMinute)
        let end = TimeBlockLayout.date(day: request.day, minute: request.endMinute)
        return "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))"
    }

    var body: some View {
        NavigationStack {
            List {
                if !unplaced.isEmpty {
                    Section("아직 안 넣은 할 일") {
                        ForEach(unplaced) { option in
                            optionRow(option)
                        }
                    }
                }
                if !placed.isEmpty {
                    Section("이미 넣은 할 일") {
                        ForEach(placed) { option in
                            optionRow(option)
                        }
                    }
                }
                Section {
                    newTodoRow
                } footer: {
                    if options.isEmpty {
                        Text("이 날짜에 할 일이 없습니다. 새 할 일을 추가해 주세요.")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(rangeTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CloseButton(action: onClose)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func optionRow(_ option: TimeBlockTodoOption) -> some View {
        Button {
            onPick(option)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: option.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(option.isCompleted ? AppTheme.shared.accent.opacity(0.55) : Color(.tertiaryLabel))
                Text(option.title)
                    .foregroundStyle(Color(.label))
                    .strikethrough(option.isCompleted, color: Color(.secondaryLabel))
                    .lineLimit(2)
                Spacer(minLength: 8)
                ForEach(option.placedStartMinutes, id: \.self) { minute in
                    Text(TimeBlockLayout.date(day: request.day, minute: minute).formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Color(.secondaryLabel))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var newTodoRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(AppTheme.shared.accent)
            AutoFocusTextField(
                text: $newTitle,
                placeholder: String(localized: "새 할 일"),
                textStyle: .body,
                autoFocus: false,
                onReturn: {
                    submitNewTodo()
                    return false
                }
            )
            if !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button("추가") {
                    submitNewTodo()
                }
                .buttonStyle(.borderless)
                .tint(AppTheme.shared.accent)
            }
        }
    }

    private func submitNewTodo() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        newTitle = ""
        onCreate(trimmed)
    }
}
