import SwiftUI

struct NotionDBPickerView: View {
    let subtitle: String
    let databases: [NotionDatabase]
    let selectedId: String?
    let isLoading: Bool
    let onSelect: (String) -> Void
    let onRefresh: () async -> Void
    var onBack: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if isLoading && databases.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        ProgressView()
                        Text("데이터베이스를 불러오는 중이에요...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if databases.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        VStack(spacing: 6) {
                            Text("데이터베이스를 찾을 수 없어요")
                                .foregroundStyle(.secondary)
                            Text("새로고침하면 불러올 수 있습니다\n(처음엔 시간이 걸릴 수 있어요)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        Button {
                            Task { await onRefresh() }
                        } label: {
                            Label("다시 불러오기", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.shared.accent)
                        .disabled(isLoading)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 24)
                                .padding(.top, 8)

                            VStack(spacing: 0) {
                                ForEach(databases) { db in
                                    Button {
                                        onSelect(db.id)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: "tablecells")
                                                .font(.system(size: 22))
                                                .foregroundStyle(AppTheme.shared.accent)
                                                .frame(width: 36, height: 36)
                                            Text(db.title)
                                                .font(.body)
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)
                                            Spacer()
                                            if selectedId == db.id {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(AppTheme.shared.accent)
                                            }
                                        }
                                        .padding(14)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    if db.id != databases.last?.id {
                                        Divider()
                                            .padding(.leading, 62)
                                    }
                                }
                            }
                            .background(
                                Color(.systemBackground),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                            .padding(.horizontal, 24)
                            .padding(.bottom, 16)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let onBack {
                Button("뒤로가기", action: onBack)
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                    .padding(.vertical, 16)
            }
        }
        .task {
            if databases.isEmpty {
                await onRefresh()
            }
        }
    }
}
