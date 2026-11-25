import SwiftUI

/// 블록을 눌렀을 때 뜨는 간단한 팝업.
/// 위: ✕(닫기) · 할 일 이름(바로 고치기) · ✓(저장) / 가운데: 시작·종료 시각 + 옆 종(알림), 카테고리 / 아래: 블록 삭제 (할 일은 지우지 않음)
/// 이름·카테고리는 할 일 자체를 바꾼다 → 투두 탭·노션에도 반영
struct TimeBlockEditPopup: View {
    let entry: TimeBlockEntry
    /// 일과 시간. 고른 시각을 그날 화면의 분으로 바꿀 때 쓴다 (범위가 새벽까지면 01:00 = 다음 날)
    let dayRange: TimeBlockDayRange
    /// 메뉴 「블록 시작 알림」·「블록 종료 알림」 전체 설정. 꺼져 있으면 그 체크박스는 흐리게
    let isStartAlarmGloballyEnabled: Bool
    let isEndAlarmGloballyEnabled: Bool
    /// 고를 수 있는 카테고리 (이 플래너)
    let categories: [Category]
    let onSave: (TimeBlockEditResult) -> Void
    let onDelete: () -> Void
    let onClose: () -> Void

    @State private var start: Date
    @State private var end: Date
    @State private var startAlarm: Bool
    @State private var endAlarm: Bool
    @State private var title: String
    @State private var categoryId: String?

    init(
        entry: TimeBlockEntry,
        dayRange: TimeBlockDayRange,
        isStartAlarmGloballyEnabled: Bool,
        isEndAlarmGloballyEnabled: Bool,
        categories: [Category],
        onSave: @escaping (TimeBlockEditResult) -> Void,
        onDelete: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.entry = entry
        self.dayRange = dayRange
        self.isStartAlarmGloballyEnabled = isStartAlarmGloballyEnabled
        self.isEndAlarmGloballyEnabled = isEndAlarmGloballyEnabled
        self.categories = categories
        self.onSave = onSave
        self.onDelete = onDelete
        self.onClose = onClose
        _start = State(initialValue: TimeBlockLayout.date(day: entry.block.day, minute: entry.block.startMinute))
        _end = State(initialValue: TimeBlockLayout.date(day: entry.block.day, minute: entry.block.endMinute))
        _startAlarm = State(initialValue: entry.block.alarmEnabled)
        _endAlarm = State(initialValue: entry.block.endAlarmEnabled)
        _title = State(initialValue: entry.title)
        _categoryId = State(initialValue: entry.categoryId)
    }

    private var startMinute: Int { dayRange.pageMinute(of: start) }
    private var endMinute: Int { dayRange.pageEndMinute(of: end, start: startMinute) }

    /// 날짜 부분은 무시하고 시각만 비교 (종료 01:00이 다음 날일 수 있음)
    private var isTimeValid: Bool { endMinute > startMinute }
    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
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
                    // 시각 옆 종 = 그 시각 알림 (켜짐 bell.fill / 꺼짐 bell.slash)
                    timeRow(title: "시작", selection: $start, alarm: $startAlarm, isAlarmAvailable: isStartAlarmGloballyEnabled)
                    timeRow(title: "종료", selection: $end, alarm: $endAlarm, isAlarmAvailable: isEndAlarmGloballyEnabled)
                    if !isTimeValid {
                        Text("끝나는 시각은 시작 시각보다 늦어야 합니다.")
                            .font(.footnote)
                            .foregroundStyle(Color(.systemRed))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Divider()
                    categoryRow
                    if !isStartAlarmGloballyEnabled || !isEndAlarmGloballyEnabled {
                        Text("흐린 알림은 타임블록 오른쪽 위 메뉴에서 켤 수 있습니다.")
                            .font(.footnote)
                            .foregroundStyle(Color(.secondaryLabel))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
                Divider()
                Button(role: .destructive, action: onDelete) {
                    Text("블록 삭제")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(.systemRed))
            }
            .frame(maxWidth: 340)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                    categoryId: categoryId
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

    private func timeRow(
        title: LocalizedStringKey,
        selection: Binding<Date>,
        alarm: Binding<Bool>,
        isAlarmAvailable: Bool
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
            Spacer()
            DatePicker(title, selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
            alarmButton(isOn: alarm, isAvailable: isAlarmAvailable, timeTitle: title)
        }
    }

    /// 시각 옆 종. 탭하면 그 시각 알림 켜기/끄기. 메뉴 전체 알림이 꺼져 있으면 흐리게
    private func alarmButton(isOn: Binding<Bool>, isAvailable: Bool, timeTitle: LocalizedStringKey) -> some View {
        let showsOn = isOn.wrappedValue && isAvailable
        return Button {
            isOn.wrappedValue.toggle()
        } label: {
            Image(systemName: showsOn ? "bell.fill" : "bell.slash")
                .font(.system(size: 16))
                .foregroundStyle(showsOn ? accent : Color(.tertiaryLabel))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
                .animation(.easeOut(duration: 0.15), value: showsOn)
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.45)
        .accessibilityLabel(Text("알림"))
        .accessibilityValue(showsOn ? Text("켜짐") : Text("꺼짐"))
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
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .foregroundStyle(Color(.label))
            }
        }
    }
}
