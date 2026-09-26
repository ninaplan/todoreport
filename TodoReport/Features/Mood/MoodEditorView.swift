import SwiftUI

struct MoodEditorView: View {
    @State private var viewModel: MoodEditorViewModel
    @Environment(\.editMode) private var editMode
    @Environment(\.dismiss) private var dismiss

    private let presentsAsSheet: Bool

    init(plannerId: String, presentsAsSheet: Bool = false) {
        self.presentsAsSheet = presentsAsSheet
        _viewModel = State(initialValue: MoodEditorViewModel(plannerId: plannerId))
    }

    var body: some View {
        List {
            Section {
                Toggle("기분 사용", isOn: Binding(
                    get: { viewModel.isUsageEnabled },
                    set: { viewModel.setUsageEnabled($0) }
                ))
            } footer: {
                Text(viewModel.modeDescription)
            }

            Section {
                ForEach(viewModel.options) { option in
                    optionRow(option)
                }
                .onMove(perform: viewModel.moveOptions)
                if editMode?.wrappedValue.isEditing != true {
                    Button {
                        viewModel.openAdd()
                    } label: {
                        Text("+ 기분 추가")
                    }
                }
            }
        }
        .navigationTitle("기분")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if presentsAsSheet {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(String(localized: "닫기"))
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.isEditSheetPresented },
            set: { isPresented in
                if !isPresented { viewModel.dismissEditSheet() }
            }
        )) {
            MoodOptionEditSheet(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .task { viewModel.load() }
        .alert("기분 삭제", isPresented: $viewModel.showDeleteAlert) {
            Button("취소", role: .cancel) { viewModel.cancelDelete() }
            Button("삭제", role: .destructive) { viewModel.confirmDelete() }
        } message: {
            Text("과거 기록에는 이름만 남아요")
        }
        .alert("저장 실패", isPresented: $viewModel.showSaveErrorAlert) {
            Button("확인") { viewModel.confirmSaveError() }
        } message: {
            Text("기분을 저장하지 못했습니다. 다시 시도해 주세요.")
        }
        .alert("읽기 전용 플래너", isPresented: $viewModel.showReadOnlyAlert) {
            Button("확인") { viewModel.confirmReadOnly() }
        } message: {
            Text("이 플래너는 읽기 전용입니다. Pro 구독 시 다시 활성화됩니다.")
        }
    }

    private func optionRow(_ option: MoodOption) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: option.colorHex))
                .frame(width: 12, height: 12)
                .accessibilityHidden(true)
            Text(viewModel.displayName(for: option))
                .font(.body)
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard editMode?.wrappedValue.isEditing != true else { return }
            viewModel.openEdit(option)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                viewModel.requestDelete(option)
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
    }
}
