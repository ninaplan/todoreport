import SwiftUI

/// 블록을 눌렀을 때 뜨는 간단한 팝업: 시작·끝 시각, 시작 알림, 블록 삭제 (할 일은 지우지 않음).
struct TimeBlockEditPopup: View {
    let entry: TimeBlockEntry
    /// 메뉴 「블록 시작 알림」 전체 설정
    let isGlobalAlarmEnabled: Bool
    let onSave: (Date, Date, Bool) -> Void
    let onDelete: () -> Void
    let onClose: () -> Void

    @State private var start: Date
    @State private var end: Date
    @State private var alarmEnabled: Bool

    init(
        entry: TimeBlockEntry,
        isGlobalAlarmEnabled: Bool,
        onSave: @escaping (Date, Date, Bool) -> Void,
        onDelete: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.entry = entry
        self.isGlobalAlarmEnabled = isGlobalAlarmEnabled
        self.onSave = onSave
        self.onDelete = onDelete
        self.onClose = onClose
        _start = State(initialValue: TimeBlockLayout.date(day: entry.block.day, minute: entry.block.startMinute))
        _end = State(initialValue: TimeBlockLayout.date(day: entry.block.day, minute: entry.block.endMinute))
        _alarmEnabled = State(initialValue: entry.block.alarmEnabled)
    }

    private var isValid: Bool { end > start }

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
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
                    Toggle("시작 알림", isOn: $alarmEnabled)
                        .tint(AppTheme.shared.accent)
                        .disabled(!isGlobalAlarmEnabled)
                    if !isGlobalAlarmEnabled {
                        Text("블록 시작 알림이 모두 꺼져 있습니다. 타임라인 오른쪽 위 메뉴에서 켤 수 있습니다.")
                            .font(.footnote)
                            .foregroundStyle(Color(.secondaryLabel))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
                Divider()
                footer
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
        HStack(alignment: .top, spacing: 12) {
            Text(entry.title)
                .font(.headline)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
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

    private func timeRow(title: LocalizedStringKey, selection: Binding<Date>) -> some View {
        HStack {
            Text(title)
            Spacer()
            DatePicker(title, selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
        }
    }

    private var footer: some View {
        HStack {
            Button(role: .destructive, action: onDelete) {
                Text("블록 삭제")
            }
            .buttonStyle(.borderless)
            .tint(Color(.systemRed))
            Spacer()
            Button {
                onSave(start, end, alarmEnabled)
            } label: {
                Text("저장")
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.shared.accent)
            .disabled(!isValid)
        }
    }
}
