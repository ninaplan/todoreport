import SwiftUI

/// What's New 강조 안내 — 팝업·업데이트 내역 공통.
struct WhatsNewNoticeBanner: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.body)
                .foregroundStyle(AppTheme.shared.accent)
                .padding(.top, 1)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            AppTheme.shared.accent.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}
