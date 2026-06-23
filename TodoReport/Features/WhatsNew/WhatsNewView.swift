import SwiftUI

private let defaultExpandedReleaseCount = 3
private let releaseIconSize: CGFloat = 32
private let releaseHeaderSpacing: CGFloat = 10

struct WhatsNewView: View {
    @State private var expandedReleaseIDs: Set<String>

    init() {
        _expandedReleaseIDs = State(
            initialValue: Set(whatsNewReleases.prefix(defaultExpandedReleaseCount).map(\.id))
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(whatsNewReleases.enumerated()), id: \.element.id) { index, release in
                    WhatsNewReleaseSection(
                        release: release,
                        index: index,
                        showsConnector: index < whatsNewReleases.count - 1,
                        isExpanded: expandedReleaseIDs.contains(release.id),
                        onToggle: { toggleRelease(release) }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .navigationTitle("업데이트 내역")
        .navigationBarTitleDisplayMode(.large)
    }

    private func toggleRelease(_ release: WhatsNewRelease) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if expandedReleaseIDs.contains(release.id) {
                expandedReleaseIDs.remove(release.id)
            } else {
                expandedReleaseIDs.insert(release.id)
            }
        }
    }
}

// MARK: - 버전 섹션

private struct WhatsNewReleaseSection: View {
    let release: WhatsNewRelease
    let index: Int
    let showsConnector: Bool
    let isExpanded: Bool
    let onToggle: () -> Void

    private var isCollapsible: Bool { index >= defaultExpandedReleaseCount }
    private var itemsLeadingInset: CGFloat { releaseIconSize + releaseHeaderSpacing }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: releaseHeaderSpacing) {
                releaseIcon
                releaseHeader
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(release.items, id: \.self) { item in
                        Text(item)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.leading, itemsLeadingInset)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, showsConnector ? 20 : 8)
        .background(alignment: .topLeading) {
            timelineConnector
        }
    }

    private var timelineConnector: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(width: releaseIconSize, height: releaseIconSize)

            if showsConnector {
                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: 1.5)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: releaseIconSize)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var releaseHeader: some View {
        Button(action: onToggle) {
            HStack(alignment: .center, spacing: 0) {
                Text("v\(release.id)")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                if isCollapsible {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(Color(.tertiaryLabel))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isCollapsible)
    }

    private var releaseIcon: some View {
        Image(systemName: release.symbolName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(AppTheme.shared.accent)
            .frame(width: releaseIconSize, height: releaseIconSize)
    }
}
