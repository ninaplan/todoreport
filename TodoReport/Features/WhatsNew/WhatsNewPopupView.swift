import SwiftUI

struct WhatsNewPopupView: View {
    let release: WhatsNewRelease
    let onDismiss: () -> Void

    var body: some View {
        Group {
            if release.usesFeaturedPopup {
                featuredContent
            } else {
                legacyContent
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var featuredContent: some View {
        VStack(spacing: 0) {
            Text(release.popupTitle ?? String(localized: "이번 업데이트 소식"))
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 16 + oneBodyLineSpacing)
                .padding(.bottom, threeBodyLineSpacing)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(release.popupItems) { item in
                        featuredItemRow(item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }

            dismissButton
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
    }

    private var oneBodyLineSpacing: CGFloat {
        UIFont.preferredFont(forTextStyle: .body).lineHeight
    }

    private var threeBodyLineSpacing: CGFloat {
        oneBodyLineSpacing * 3
    }

    private func featuredItemRow(_ item: WhatsNewRelease.PopupItem) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.symbolName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 6) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if item.isPro {
                            ProBadge()
                        }
                    }
                    Text(item.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let previewImageName = item.previewImageName {
                    Image(previewImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var legacyContent: some View {
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

                if let notice = release.notice {
                    WhatsNewNoticeBanner(text: notice)
                }

                Spacer(minLength: 0)

                dismissButton
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기", action: onDismiss)
                }
            }
        }
    }

    private var dismissButton: some View {
        Button(action: onDismiss) {
            Text(release.popupButtonTitle ?? String(localized: "확인"))
                .font(.headline)
                .foregroundStyle(Color(.systemBackground))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
