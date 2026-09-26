import SwiftUI

struct MoodOptionEditSheet: View {
    @Bindable var viewModel: MoodEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool

    private var trimmedName: String {
        viewModel.editName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("이름", text: Binding(
                        get: { viewModel.editName },
                        set: { viewModel.setEditName($0) }
                    ))
                    .font(.body)
                    .focused($isNameFocused)
                    .disabled(viewModel.isNotionNameLocked)
                    .overlay {
                        if viewModel.isNotionNameLocked {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.requestNotionNameChangeAlert()
                                }
                        }
                    }
                }

                Section("색상") {
                    MoodColorPicker(selectedHex: viewModel.editColorHex) { hex in
                        viewModel.selectColor(hex)
                    }
                }
            }
            .navigationTitle(viewModel.isEditingOption ? "기분 편집" : "기분 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                        .toolbarSecondaryActionStyle()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.saveEdit() }
                    } label: {
                        if viewModel.isSavingEdit {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("저장")
                        }
                    }
                    .toolbarPrimaryActionStyle(isEnabled: !trimmedName.isEmpty && !viewModel.isSavingEdit)
                    .disabled(trimmedName.isEmpty || viewModel.isSavingEdit)
                }
            }
            .onAppear {
                if !viewModel.isNotionNameLocked {
                    isNameFocused = true
                }
            }
            .alert("이름은 노션에서 변경해주세요", isPresented: $viewModel.showNotionNameChangeAlert) {
                Button("확인") { viewModel.confirmNotionNameChange() }
            } message: {
                Text("노션 연동 중에는 앱에서 이름을 바꿀 수 없습니다.")
            }
        }
    }
}
