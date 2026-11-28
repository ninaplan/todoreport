import SwiftUI

/// 별점 이름·아이콘·색. 설정 → 플래너 상세(push)와 하루 리포트 카드(시트) 두 곳에서 연다
struct RatingLabelEditView: View {
    @State private var viewModel: RatingLabelEditViewModel
    private let presentsAsSheet: Bool
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    /// 색 고르기 창 (화면 표시 상태라 View에 둔다)
    @State private var isPickingColor = false

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

            Section("아이콘") {
                // 미리보기 + 색 고르기. 색 창은 반만 올라와 바뀌는 모습을 보면서 고를 수 있다
                HStack {
                    PawRatingView(rating: 3, size: 20, spacing: 10, style: viewModel.previewStyle)
                        .accessibilityHidden(true)
                    Spacer()
                    colorButton
                }
                .padding(.vertical, 4)

                CategoryIconPagePicker(
                    selectedIcon: viewModel.pickerIcon,
                    colorHex: viewModel.colorButtonHex,
                    initiallyFilled: viewModel.isDefaultIcon ? true : nil,
                    onSelect: { viewModel.selectIcon($0) }
                )
                .padding(.vertical, 4)
            }

            if viewModel.canResetToDefault {
                Section {
                    Button {
                        viewModel.resetToDefault()
                    } label: {
                        Text("원래대로 되돌리기")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .navigationTitle("별점")
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
        .sheet(isPresented: $isPickingColor) {
            CategoryColorPickerSheet(
                onPick: { viewModel.selectColor($0) },
                onFinish: { isPickingColor = false },
                initialHex: viewModel.colorButtonHex
            )
            .presentationDetents([.medium])
        }
    }

    private var colorButton: some View {
        Button {
            isFocused = false
            isPickingColor = true
        } label: {
            Circle()
                .fill(Color(hex: viewModel.colorButtonHex))
                .frame(width: 28, height: 28)
                .overlay {
                    Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("색 고르기"))
    }

    private func saveAndDismiss() {
        viewModel.save()
        dismiss()
    }
}
