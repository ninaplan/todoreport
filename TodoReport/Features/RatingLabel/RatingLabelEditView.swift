import SwiftUI

/// 「별점」 대신 쓸 이름 입력. 설정 → 플래너 상세(push)와 하루 리포트 카드(시트) 두 곳에서 연다
struct RatingLabelEditView: View {
    @State private var viewModel: RatingLabelEditViewModel
    private let presentsAsSheet: Bool
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    init(plannerId: String, presentsAsSheet: Bool = false) {
        _viewModel = State(initialValue: RatingLabelEditViewModel(plannerId: plannerId))
        self.presentsAsSheet = presentsAsSheet
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("예: 기분, 에너지, 집중력", text: $viewModel.text)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit { saveAndDismiss() }
                    Text(verbatim: viewModel.countText)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            } footer: {
                Text("하루 리포트와 리포트 탭에 이 이름으로 표시됩니다. 비워 두면 「별점」으로 표시됩니다. 노션에는 그대로 「별점」 속성에 저장됩니다.")
            }

            if viewModel.canResetToDefault {
                Section {
                    Button("기본으로 되돌리기") {
                        viewModel.resetToDefault()
                    }
                }
            }
        }
        .navigationTitle("기록 항목 이름")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if presentsAsSheet {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("저장") { saveAndDismiss() }
                    .disabled(!viewModel.hasChanges)
            }
        }
        .onAppear { isFocused = true }
    }

    private func saveAndDismiss() {
        viewModel.save()
        dismiss()
    }
}
