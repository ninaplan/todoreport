#if DEBUG
import SwiftUI

struct DebugDeveloperOptionsSection: View {
    @State private var inputURL = BackendBaseURL.overrideValue ?? ""
    @State private var queueCounts: (pending: Int, processing: Int, failed: Int) = (0, 0, 0)

    var body: some View {
        Group {
            Section {
                LabeledContent("pending") {
                    Text("\(queueCounts.pending)")
                }
                LabeledContent("processing") {
                    Text("\(queueCounts.processing)")
                }
                LabeledContent("failed") {
                    Text("\(queueCounts.failed)")
                }
                Button("새로고침") {
                    refreshQueueCounts()
                }
                Button("큐 상세 로그 출력") {
                    SyncQueueManager.shared.debugDumpQueueItems()
                }
            } header: {
                Text("동기화 큐 상태")
            }

            Section {
                LabeledContent("현재 URL") {
                    Text(BackendBaseURL.resolved)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }

                TextField("백엔드 URL", text: $inputURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                Button("적용") {
                    BackendBaseURL.applyOverride(inputURL)
                }

                Button("프로덕션으로 초기화") {
                    BackendBaseURL.resetToProduction()
                    inputURL = ""
                }
                .foregroundStyle(.secondary)
            } header: {
                Text("개발자 옵션")
            } footer: {
                Text("URL을 변경한 뒤에는 앱을 완전히 종료한 후 다시 실행해야 적용됩니다.")
            }
        }
        .onAppear {
            refreshQueueCounts()
        }
    }

    private func refreshQueueCounts() {
        queueCounts = SyncQueueManager.shared.pendingQueueCounts
    }
}
#endif
