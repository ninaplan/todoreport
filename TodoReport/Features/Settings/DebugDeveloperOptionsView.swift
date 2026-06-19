#if DEBUG
import SwiftUI

struct DebugDeveloperOptionsSection: View {
    @State private var inputURL = BackendBaseURL.overrideValue ?? ""

    var body: some View {
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
}
#endif
