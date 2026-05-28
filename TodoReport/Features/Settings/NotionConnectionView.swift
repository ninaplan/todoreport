import SwiftUI

struct NotionConnectionView: View {
    let isConnected: Bool

    var body: some View {
        List {
            if isConnected {
                connectedSection
            } else {
                disconnectedSection
            }
        }
        .navigationTitle("노션 연결")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 연결됨

    private var connectedSection: some View {
        Group {
            Section("연결된 계정") {
                LabeledContent("이메일") {
                    Text("nina@notion.so")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("워크스페이스") {
                    Text("Nina's Workspace")
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Button("노션 연결 해제", role: .destructive) {
                    // TODO: Notion 연결 해제
                }
            }
        }
    }

    // MARK: - 미연결

    private var disconnectedSection: some View {
        Section {
            VStack(spacing: 20) {
                Image(systemName: "link.badge.plus")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.nockOrange)
                    .padding(.top, 8)

                VStack(spacing: 6) {
                    Text("노션 연결하기")
                        .font(.headline)
                    Text("노션 계정을 연결하면\n투두와 리포트가 노션에 자동으로 저장됩니다.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    // TODO: Notion OAuth (ASWebAuthenticationSession)
                } label: {
                    Text("노션으로 연결")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.nockOrange, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}
