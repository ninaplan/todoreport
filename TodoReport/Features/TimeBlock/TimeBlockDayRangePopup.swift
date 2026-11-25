import SwiftUI

/// ⋯ 「일과 시간」 팝업. 타임블록에 보일 시간 범위를 1시간 단위로 고른다.
/// 끝은 다음 날 새벽까지 고를 수 있다 (최대 24시간). 위: ✕ · 제목 · ✓ (블록 편집 팝업과 같은 모양)
struct TimeBlockDayRangePopup: View {
    let range: TimeBlockDayRange
    let onSave: (TimeBlockDayRange) -> Void
    let onClose: () -> Void

    @State private var startMinute: Int
    @State private var endMinute: Int

    private static let startOptions: [Int] = Array(stride(from: 0, to: TimeBlockLayout.minutesPerDay, by: 60))

    init(
        range: TimeBlockDayRange,
        onSave: @escaping (TimeBlockDayRange) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.range = range
        self.onSave = onSave
        self.onClose = onClose
        _startMinute = State(initialValue: range.startMinute)
        _endMinute = State(initialValue: range.endMinute)
    }

    private var accent: Color { AppTheme.shared.accent }
    private var draft: TimeBlockDayRange { TimeBlockDayRange(startMinute: startMinute, endMinute: endMinute) }
    private var canSave: Bool { draft.isValid && draft != range }

    /// 끝 선택지: 시작 + 1시간 ... 시작 + 24시간
    private var endOptions: [Int] {
        Array(stride(from: startMinute + 60, through: startMinute + TimeBlockLayout.minutesPerDay, by: 60))
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
                VStack(spacing: 12) {
                    pickerRow(title: "시작", selection: startBinding, options: Self.startOptions)
                    pickerRow(title: "종료", selection: $endMinute, options: endOptions)
                    Text("자정을 넘기면 그날 화면 아래에 이어서 보입니다.")
                        .font(.footnote)
                        .foregroundStyle(Color(.secondaryLabel))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
            }
            .frame(maxWidth: 340)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
            .padding(.horizontal, 24)
        }
    }

    // MARK: - 시작을 바꾸면 종료가 1~24시간 안에 들도록 맞춘다

    private var startBinding: Binding<Int> {
        Binding(
            get: { startMinute },
            set: { newStart in
                startMinute = newStart
                let minimumEnd = newStart + 60
                let maximumEnd = newStart + TimeBlockLayout.minutesPerDay
                endMinute = min(max(endMinute, minimumEnd), maximumEnd)
            }
        )
    }

    private var header: some View {
        HStack(spacing: 12) {
            circleButton(systemName: "xmark", label: "닫기", isProminent: false, action: onClose)
            Text("일과 시간")
                .font(.headline)
                .frame(maxWidth: .infinity)
            circleButton(systemName: "checkmark", label: "저장", isProminent: canSave) {
                onSave(draft)
            }
            .disabled(!canSave)
            .animation(.easeOut(duration: 0.15), value: canSave)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func pickerRow(title: LocalizedStringKey, selection: Binding<Int>, options: [Int]) -> some View {
        HStack {
            Text(title)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { minute in
                    Text(verbatim: Self.timeLabel(minute)).tag(minute)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(.primary)
            // 「다음 날 오전 1:00」도 한 줄로 → 시작·종료의 오른쪽 끝이 맞는다
            .lineLimit(1)
            .fixedSize()
        }
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
                .foregroundStyle(isProminent ? Color.white : Color(.secondaryLabel))
                .frame(width: 32, height: 32)
                .background(isProminent ? accent : Color(.tertiarySystemFill), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }

    // MARK: - 표시 문구 (메뉴 부제목에도 씀)

    /// 0시부터 분 → 「오전 6:00」 / 1440 = 「자정」 / 그 뒤 = 「다음 날 오전 2:00」 (기기 시간 형식 따름)
    static func timeLabel(_ minute: Int) -> String {
        let minutesPerDay = TimeBlockLayout.minutesPerDay
        if minute == minutesPerDay { return String(localized: "자정") }
        let reference = Calendar.current.startOfDay(for: .now)
        let date = TimeBlockLayout.date(day: reference, minute: minute % minutesPerDay)
        let time = date.formatted(date: .omitted, time: .shortened)
        guard minute > minutesPerDay else { return time }
        return String(localized: "다음 날 \(time)")
    }

    /// 메뉴 한 줄용 짧은 표시: 「6시–24시」 / 자정을 넘으면 「10시–새벽 2시」
    static func compactSummary(of range: TimeBlockDayRange) -> String {
        let start = range.startMinute / 60
        let end = range.endMinute / 60
        guard range.spansMidnight else {
            return String(localized: "\(start)시–\(end)시")
        }
        return String(localized: "\(start)시–새벽 \(end - 24)시")
    }

    static func summary(of range: TimeBlockDayRange) -> String {
        "\(timeLabel(range.startMinute)) – \(timeLabel(range.endMinute))"
    }
}
