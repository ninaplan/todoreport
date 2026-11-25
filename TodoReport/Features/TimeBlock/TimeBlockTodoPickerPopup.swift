import SwiftUI

/// 빈 칸을 눌렀을 때 뜨는 간단한 팝업: 그날 할 일 고르기 / 새 할 일 추가.
/// 한 목록으로 보여주고, 이미 넣은 할 일은 아래로 내리고 시간 태그만 단다 (다시 넣을 수 있음).
struct TimeBlockTodoPickerPopup: View {
    let request: TimeBlockSlotRequest
    let options: [TimeBlockTodoOption]
    let onPick: (TimeBlockTodoOption) -> Void
    let onCreate: (String) -> Void
    let onClose: () -> Void

    @State private var newTitle = ""

    private static let rowHeight: CGFloat = 44
    private static let maxListHeight: CGFloat = 300

    /// 안 넣은 할 일 먼저, 이미 넣은 할 일은 아래로
    private var sortedOptions: [TimeBlockTodoOption] {
        options.filter { !$0.isPlaced } + options.filter(\.isPlaced)
    }

    private var rangeTitle: String {
        let start = TimeBlockLayout.date(day: request.day, minute: request.startMinute)
        let end = TimeBlockLayout.date(day: request.day, minute: request.endMinute)
        return "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))"
    }

    /// 목록이 짧으면 팝업도 짧게
    private var listHeight: CGFloat {
        let content = CGFloat(options.count) * Self.rowHeight + 8
        return min(max(content, 60), Self.maxListHeight)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                header
                Divider()
                list
                Divider()
                newTodoRow
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .frame(maxWidth: 340)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
            .padding(.horizontal, 24)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("이 시간에 할 일")
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
                Text(rangeTitle)
                    .font(.headline)
                    .monospacedDigit()
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(.secondaryLabel))
                    .frame(width: 28, height: 28)
                    .background(Color(.tertiarySystemFill), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("닫기"))
        }
        .padding(16)
    }

    @ViewBuilder
    private var list: some View {
        if options.isEmpty {
            Text("이 날짜에 할 일이 없습니다. 새 할 일을 추가해 주세요.")
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(sortedOptions) { optionRow($0) }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .frame(height: listHeight)
        }
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
                    .lineLimit(1)
                Spacer(minLength: 8)
                // 이미 넣은 할 일: 시작 시각 대신 그날 블록 시간 합계 하나 (블록이 여러 개여도 한 칸)
                if option.isPlaced {
                    Text(verbatim: option.placedTotalText)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Color(.secondaryLabel))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .fixedSize()
                }
            }
            .frame(height: Self.rowHeight)
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
            .frame(height: 30)
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
