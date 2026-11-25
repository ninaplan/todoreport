import SwiftUI

/// 블록을 눌렀을 때 뜨는 팝업 (B안).
/// 위: ✕ · 할 일 이름(바로 고치기) · ✓ / 시작·종료 줄: [종 | 시각] 알약, 시각을 누르면 아래에 휠
/// / 카테고리 칩 / 메모 (여러 줄) / 삭제 (블록만 또는 할 일까지)
/// 이름·카테고리·메모는 할 일 자체를 바꾼다 → 투두 탭·노션에도 반영
struct TimeBlockEditPopup: View {
    let entry: TimeBlockEntry
    /// 일과 시간. 고른 시각을 그날 화면의 분으로 바꿀 때 쓴다 (범위가 새벽까지면 01:00 = 다음 날)
    let dayRange: TimeBlockDayRange
    /// 고를 수 있는 카테고리 (이 플래너)
    let categories: [Category]
    /// 블록의 메모·「+ 메모 추가」로 열었으면 메모 칸에 바로 커서
    var focusesMemo: Bool = false
    let onSave: (TimeBlockEditResult) -> Void
    let onDelete: () -> Void
    /// 할 일까지 삭제 (반복이면 이번 것만 / 이후 모두)
    let onDeleteTodo: (TimeBlockTodoDeleteScope) -> Void
    let onClose: () -> Void

    @State private var start: Date
    @State private var end: Date
    @State private var startAlarm: Bool
    @State private var endAlarm: Bool
    @State private var title: String
    @State private var categoryId: String?
    @State private var memo: String
    /// 휠이 펼쳐진 시각 (한 번에 하나)
    @State private var expandedTime: TimeField?
    @FocusState private var isMemoFocused: Bool
    /// 삭제 선택 창 (블록만 / 할 일까지)
    @State private var showDeleteOptions = false

    private enum TimeField {
        case start
        case end
    }

    init(
        entry: TimeBlockEntry,
        dayRange: TimeBlockDayRange,
        categories: [Category],
        focusesMemo: Bool = false,
        onSave: @escaping (TimeBlockEditResult) -> Void,
        onDelete: @escaping () -> Void,
        onDeleteTodo: @escaping (TimeBlockTodoDeleteScope) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.entry = entry
        self.dayRange = dayRange
        self.categories = categories
        self.focusesMemo = focusesMemo
        self.onSave = onSave
        self.onDelete = onDelete
        self.onDeleteTodo = onDeleteTodo
        self.onClose = onClose
        _start = State(initialValue: TimeBlockLayout.date(day: entry.block.day, minute: entry.block.startMinute))
        _end = State(initialValue: TimeBlockLayout.date(day: entry.block.day, minute: entry.block.endMinute))
        _startAlarm = State(initialValue: entry.block.alarmEnabled)
        _endAlarm = State(initialValue: entry.block.endAlarmEnabled)
        _title = State(initialValue: entry.title)
        _categoryId = State(initialValue: entry.categoryId)
        _memo = State(initialValue: entry.memo ?? "")
    }

    private var startMinute: Int { dayRange.pageMinute(of: start) }
    private var endMinute: Int { dayRange.pageEndMinute(of: end, start: startMinute) }

    /// 날짜 부분은 무시하고 시각만 비교 (종료 01:00이 다음 날일 수 있음)
    private var isTimeValid: Bool { endMinute > startMinute }
    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedMemo: String { memo.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isValid: Bool { isTimeValid && !trimmedTitle.isEmpty }
    private var accent: Color { AppTheme.shared.accent }

    /// 처음 연 값과 달라졌는지 → 저장 ✓를 진하게
    private var hasChanges: Bool {
        startMinute != entry.block.startMinute
            || endMinute != entry.block.endMinute
            || startAlarm != entry.block.alarmEnabled
            || endAlarm != entry.block.endAlarmEnabled
            || trimmedTitle != entry.title
            || categoryId != entry.categoryId
            || trimmedMemo != (entry.memo ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool { isValid && hasChanges }

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                header
                Divider()
                VStack(spacing: 12) {
                    timeRow(title: "시작", field: .start, selection: $start, alarm: $startAlarm)
                    timeRow(title: "종료", field: .end, selection: $end, alarm: $endAlarm)
                    if !isTimeValid {
                        Text("끝나는 시각은 시작 시각보다 늦어야 합니다.")
                            .font(.footnote)
                            .foregroundStyle(Color(.systemRed))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Divider()
                    categoryRow
                        // 휠이 열려 있을 때 카테고리 줄을 누르면 메뉴 대신 휠만 닫는다
                        .overlay {
                            if expandedTime != nil {
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture { expandedTime = nil }
                            }
                        }
                    memoField
                }
                .padding(16)
                // 휠 밖 빈 곳·글자를 누르면 휠 닫기 (휠·알약·입력칸은 자기 탭을 먼저 받는다)
                .contentShape(Rectangle())
                .onTapGesture {
                    if expandedTime != nil { expandedTime = nil }
                }
                .animation(.easeInOut(duration: 0.2), value: expandedTime)
                deleteButton
            }
            .frame(maxWidth: 340)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
            .padding(.horizontal, 24)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            circleButton(systemName: "xmark", label: "닫기", isProminent: false, action: onClose)
            // 탭하면 바로 이름을 고칠 수 있다 (할 일 이름 = 투두 탭과 같음)
            TextField("할 일 이름", text: $title, axis: .vertical)
                .font(.headline)
                .lineLimit(1...2)
                .multilineTextAlignment(.center)
                .submitLabel(.done)
                .frame(maxWidth: .infinity)
            circleButton(systemName: "checkmark", label: "저장", isProminent: canSave) {
                onSave(TimeBlockEditResult(
                    start: start,
                    end: end,
                    startAlarm: startAlarm,
                    endAlarm: endAlarm,
                    title: trimmedTitle,
                    categoryId: categoryId,
                    memo: trimmedMemo
                ))
            }
            .disabled(!canSave)
            .animation(.easeOut(duration: 0.15), value: canSave)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func circleButton(
        systemName: String,
        label: LocalizedStringKey,
        isProminent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                // 평소엔 연한 회색 원, 저장할 변화가 생기면(isProminent) 포인트 컬러로 채움
                .foregroundStyle(isProminent ? Color.white : Color(.secondaryLabel))
                .frame(width: 32, height: 32)
                .background(isProminent ? accent : Color(.tertiarySystemFill), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }

    /// 시작·종료 줄: 왼쪽 이름, 오른쪽 [종 | 시각] 알약. 시각을 누르면 줄 아래에 휠
    @ViewBuilder
    private func timeRow(
        title: LocalizedStringKey,
        field: TimeField,
        selection: Binding<Date>,
        alarm: Binding<Bool>
    ) -> some View {
        let isExpanded = expandedTime == field
        VStack(spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                TimeBlockTimePill(
                    time: selection.wrappedValue,
                    isAlarmOn: alarm,
                    isExpanded: isExpanded,
                    onTapTime: {
                        isMemoFocused = false
                        expandedTime = isExpanded ? nil : field
                    }
                )
            }
            if isExpanded {
                // 높이를 잘라 쓰면 안 보이는 윗부분이 위 알약의 터치를 가로채 한 칸 이른 시각이 골라졌다
                // → 휠 기본 높이 그대로 쓴다
                DatePicker(title, selection: selection, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.wheel)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - 삭제 (블록만 / 할 일까지)

    /// 작은 「삭제」 글자 → iOS 선택 창에서 블록만 / 할 일까지 고른다 (선택 창이 실수 방지 확인 역할도 함)
    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteOptions = true
        } label: {
            Text("삭제")
                .font(.subheadline)
                .foregroundStyle(Color(.systemRed))
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
        .confirmationDialog("무엇을 삭제할까요?", isPresented: $showDeleteOptions, titleVisibility: .visible) {
            Button("블록만 삭제", role: .destructive) { onDelete() }
            if entry.recurrenceId != nil {
                Button("이 할 일만 삭제", role: .destructive) { onDeleteTodo(.single) }
                Button("이후 반복 모두 삭제", role: .destructive) { onDeleteTodo(.allFuture) }
            } else {
                Button("할 일까지 삭제", role: .destructive) { onDeleteTodo(.single) }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("할 일을 삭제하면 투두 탭과 노션에서도 지워집니다.")
        }
    }

    // MARK: - 메모 (할 일 메모 = 투두 탭·노션과 같음)

    private var memoField: some View {
        TextField("메모 추가", text: $memo, axis: .vertical)
            .lineLimit(2...6)
            .font(.subheadline)
            .focused($isMemoFocused)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onChange(of: isMemoFocused) { _, focused in
                if focused { expandedTime = nil }
            }
            .task {
                guard focusesMemo else { return }
                // 팝업이 뜨는 애니메이션이 끝난 뒤 포커스해야 키보드가 안정적으로 뜬다
                try? await Task.sleep(for: .milliseconds(250))
                isMemoFocused = true
            }
    }

    // MARK: - 카테고리

    private var selectedCategory: Category? {
        categories.first { $0.id == categoryId }
    }

    private var categoryRow: some View {
        HStack {
            Text("카테고리")
            Spacer()
            Menu {
                Picker("카테고리", selection: $categoryId) {
                    Label("미분류", systemImage: "tag.slash")
                        .tag(String?.none)
                    ForEach(categories) { category in
                        Label(category.name, systemImage: CategoryIconName.resolved(category.icon))
                            .tag(Optional(category.id))
                    }
                }
            } label: {
                // 칩: 색 점 + 이름 (시각 알약과 같은 모양)
                HStack(spacing: 6) {
                    if let selectedCategory {
                        Circle()
                            .fill(Color(hex: selectedCategory.colorHex))
                            .frame(width: 8, height: 8)
                        Text(selectedCategory.name)
                            .lineLimit(1)
                    } else {
                        Text("미분류")
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
                .foregroundStyle(Color(.label))
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Color(.tertiarySystemFill), in: Capsule())
            }
        }
    }
}
