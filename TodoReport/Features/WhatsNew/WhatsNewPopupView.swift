import SwiftUI

struct WhatsNewPopupView: View {
    let release: WhatsNewRelease
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: release.symbolName)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(AppTheme.shared.accent)
                    .padding(.top, 8)

                Text("v\(release.id) 업데이트")
                    .font(.title2.weight(.bold))

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(release.items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.body)
                                .foregroundStyle(AppTheme.shared.accent)
                            Text(item)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                Button(action: onDismiss) {
                    Text("확인")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.shared.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기", action: onDismiss)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}
