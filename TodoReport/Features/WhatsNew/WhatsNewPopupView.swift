import SwiftUI

struct WhatsNewPopupView: View {
    let release: WhatsNewRelease
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if release.showsTodoRowPreview {
                    Text("v\(release.id) 업데이트")
                        .font(.title2.weight(.bold))
                        .padding(.top, 8)

                    WhatsNewTodoRowPreview()
                } else {
                    Image(systemName: release.symbolName)
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(AppTheme.shared.accent)
                        .padding(.top, 8)

                    Text("v\(release.id) 업데이트")
                        .font(.title2.weight(.bold))
                }

                VStack(alignment: .leading, spacing: 18) {
                    ForEach(release.items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 16, alignment: .center)
                                .padding(.top, 3)
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
                        .foregroundStyle(Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.primary)
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
