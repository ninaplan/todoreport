import SwiftUI

/// 블록 팝업의 시각 알약: [종 | 시각].
/// 종(라인)을 누르면 그 시각 알림 켜기/끄기 (꺼지면 사선 그은 종, 연하게). 시각을 누르면 휠 펼치기/접기.
/// iOS 기본 시각 버튼 안에는 종을 넣을 수 없어 직접 그린다.
struct TimeBlockTimePill: View {
    let time: Date
    @Binding var isAlarmOn: Bool
    /// 이 시각의 휠이 펼쳐져 있는지 (알약 글자를 포인트 컬러로)
    let isExpanded: Bool
    let onTapTime: () -> Void

    private var accent: Color { AppTheme.shared.accent }
    private var showsAlarmOn: Bool { isAlarmOn }

    var body: some View {
        HStack(spacing: 0) {
            Button {
                isAlarmOn.toggle()
            } label: {
                Image(systemName: showsAlarmOn ? "bell" : "bell.slash")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(showsAlarmOn ? Color(.label) : Color(.tertiaryLabel))
                    .frame(width: 34, height: 32)
                    .contentShape(Rectangle())
                    .animation(.easeOut(duration: 0.15), value: showsAlarmOn)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("알림"))
            .accessibilityValue(showsAlarmOn ? Text("켜짐") : Text("꺼짐"))

            Button(action: onTapTime) {
                Text(time.formatted(date: .omitted, time: .shortened))
                    .monospacedDigit()
                    .foregroundStyle(isExpanded ? accent : Color(.label))
                    .padding(.trailing, 12)
                    .frame(height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(Color(.tertiarySystemFill), in: Capsule())
    }
}
