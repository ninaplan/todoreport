import SwiftUI

// 플래너 아이콘 표시 컴포넌트 — SettingsView, TodoView, PlannerDetailView 공유
struct PlannerIconView: View {
    let iconType: String?
    let iconImageData: Data?
    let colorHex: String
    let size: CGFloat

    var body: some View {
        ZStack {
            if iconType == "photo", let data = iconImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if let symbol = iconType {
                Circle()
                    .fill(Color(.systemGray3))
                    .frame(width: size, height: size)
                Image(systemName: symbol)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.primary)
            } else {
                // 기본: 연회색 원 + 노트 아이콘
                Circle()
                    .fill(Color(.systemGray3))
                    .frame(width: size, height: size)
                Image(systemName: "checklist")
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
