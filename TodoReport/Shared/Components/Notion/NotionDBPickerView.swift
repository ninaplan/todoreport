import SwiftUI

enum NotionDBPickerHint {
    static let missingDatabaseRefresh =
        "찾는 데이터베이스가 목록에 없으면 우상단 새로고침 버튼을 눌러 다시 불러오세요."
}

struct NotionDBPickerView: View {
    let subtitle: String
    let databases: [NotionDatabase]
    let selectedId: String?
    let isLoading: Bool
    let onSelect: (String) -> Void
    let onRefresh: () async -> Void
    var onBack: (() -> Void)? = nil
    var onSkip: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if isLoading && databases.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        ProgressView()
                        VStack(spacing: 6) {
                            Text("데이터베이스를 불러오는 중입니다.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("처음 연결할 때는 시간이 걸릴 수 있습니다.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
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
                            Text("데이터베이스를 찾을 수 없습니다.")
                                .foregroundStyle(.secondary)
                            Text("처음 불러올 때는 1분 정도 걸릴 수 있습니다. 잠시 후 다시 시도해 주세요.")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        Button {
                            Task { await onRefresh() }
                        } label: {
                            Label("다시 시도", systemImage: "arrow.clockwise")
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

                            Text(NotionDBPickerHint.missingDatabaseRefresh)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 24)
                                .padding(.top, 4)

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

            if onSkip != nil || onBack != nil {
                VStack(spacing: 0) {
                    if let onSkip {
                        Button("건너뛰기", action: onSkip)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .padding(.vertical, 14)
                    }
                    if let onBack {
                        Button("뒤로가기", action: onBack)
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                            .padding(.vertical, 14)
                    }
                }
            }
        }
        .task {
            if databases.isEmpty {
                await onRefresh()
            }
        }
    }
}
