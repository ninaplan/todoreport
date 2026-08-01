import SwiftUI

/// 업데이트 팝업용 할일 행 미리보기 — 실제 `TodoRow`와 분리 (스와이프·메뉴·탭 없음).
struct WhatsNewTodoRowPreview: View {
    private var firstLineHeight: CGFloat {
        UIFont.preferredFont(forTextStyle: .body).lineHeight
    }

    private var sampleTime: Date {
        Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "circle")
                .font(.title3)
                .foregroundStyle(Color(.tertiaryLabel))
                .frame(height: firstLineHeight)

            HStack(alignment: .top, spacing: 6) {
                Text(String(localized: "블로그 글 쓰기"))
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .layoutPriority(0)

                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.shared.accent)
                    .frame(height: firstLineHeight)
                    .layoutPriority(1)
                    .accessibilityHidden(true)

                Spacer(minLength: 0)

                sampleTimeTag
                    .frame(height: firstLineHeight)
                    .layoutPriority(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color(.secondarySystemFill),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(.separator), lineWidth: 0.5)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "블로그 글 쓰기"))
    }

    private var sampleTimeTag: some View {
        HStack(spacing: 3) {
            Image(systemName: "clock")
                .font(.caption2)
                .accessibilityHidden(true)
            Text(sampleTime, format: .dateTime.hour().minute())
                .font(.caption2)
                .monospacedDigit()
            Image(systemName: "bell")
                .font(.caption2)
                .accessibilityHidden(true)
        }
        .foregroundStyle(Color.primary.opacity(0.62))
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 5, style: .continuous)
        )
    }
}
