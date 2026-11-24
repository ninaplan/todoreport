import SwiftUI

/// 블록을 눌렀을 때 뜨는 간단한 팝업.
/// 위: ✕(닫기) · 할 일 제목 · ✓(저장) / 가운데: 시작·종료 시각, 시작·종료 알림 / 아래: 블록 삭제 (할 일은 지우지 않음)
struct TimeBlockEditPopup: View {
    let entry: TimeBlockEntry
    /// 메뉴 「블록 시작 알림」·「블록 종료 알림」 전체 설정. 꺼져 있으면 그 체크박스는 흐리게
    let isStartAlarmGloballyEnabled: Bool
    let isEndAlarmGloballyEnabled: Bool
    /// (시작, 종료, 시작 알림, 종료 알림)
    let onSave: (Date, Date, Bool, Bool) -> Void
    let onDelete: () -> Void
    let onClose: () -> Void

    @State private var start: Date
    @State private var end: Date
    @State private var startAlarm: Bool
    @State private var endAlarm: Bool

    init(
        entry: TimeBlockEntry,
        isStartAlarmGloballyEnabled: Bool,
        isEndAlarmGloballyEnabled: Bool,
        onSave: @escaping (Date, Date, Bool, Bool) -> Void,
        onDelete: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.entry = entry
        self.isStartAlarmGloballyEnabled = isStartAlarmGloballyEnabled
        self.isEndAlarmGloballyEnabled = isEndAlarmGloballyEnabled
        self.onSave = onSave
        self.onDelete = onDelete
        self.onClose = onClose
        _start = State(initialValue: TimeBlockLayout.date(day: entry.block.day, minute: entry.block.startMinute))
        _end = State(initialValue: TimeBlockLayout.date(day: entry.block.day, minute: entry.block.endMinute))
        _startAlarm = State(initialValue: entry.block.alarmEnabled)
        _endAlarm = State(initialValue: entry.block.endAlarmEnabled)
    }

    private var isValid: Bool { end > start }
    private var accent: Color { AppTheme.shared.accent }

    /// 처음 연 값과 달라졌는지 → 저장 ✓를 진하게
    private var hasChanges: Bool {
        TimeBlockLayout.minute(of: start, day: entry.block.day) != entry.block.startMinute
            || TimeBlockLayout.minute(of: end, day: entry.block.day) != entry.block.endMinute
            || startAlarm != entry.block.alarmEnabled
            || endAlarm != entry.block.endAlarmEnabled
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
                    timeRow(title: "시작", selection: $start)
                    timeRow(title: "종료", selection: $end)
                    if !isValid {
                        Text("끝나는 시각은 시작 시각보다 늦어야 합니다.")
                            .font(.footnote)
                            .foregroundStyle(Color(.systemRed))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Divider()
                    // 시작·종료 줄과 같은 모양: 왼쪽 「알림」, 오른쪽 시작 ☐ 종료 ☐
                    HStack(spacing: 16) {
                        Text("알림")
                        Spacer(minLength: 8)
                        checkbox(title: "시작", isOn: $startAlarm, isAvailable: isStartAlarmGloballyEnabled)
                        checkbox(title: "종료", isOn: $endAlarm, isAvailable: isEndAlarmGloballyEnabled)
                    }
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
            Text(entry.title)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            circleButton(systemName: "checkmark", label: "저장", isProminent: canSave) {
                onSave(start, end, startAlarm, endAlarm)
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

    private func timeRow(title: LocalizedStringKey, selection: Binding<Date>) -> some View {
        HStack {
            Text(title)
            Spacer()
            DatePicker(title, selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
        }
    }

    private func checkbox(title: LocalizedStringKey, isOn: Binding<Bool>, isAvailable: Bool) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .foregroundStyle(Color(.label))
                    .fixedSize()
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    // 연한 색은 "꺼진 것"처럼 보여서 진하게 (라이트 = 검정, 다크 = 흰색)
                    .foregroundStyle(isOn.wrappedValue ? Color(.label) : Color(.tertiaryLabel))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.45)
        .accessibilityAddTraits(isOn.wrappedValue ? .isSelected : [])
    }
}
