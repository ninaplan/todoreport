import SwiftUI

struct CategoryView: View {
    @State private var viewModel: CategoryViewModel
    @Environment(\.editMode) private var editMode
    /// 투두탭 시트만 true. 설정 네비게이션 push는 기본값(false) 유지.
    private let presentsAsSheet: Bool

    init(plannerId: String? = nil, presentsAsSheet: Bool = false) {
        self.presentsAsSheet = presentsAsSheet
        _viewModel = State(initialValue: CategoryViewModel(plannerId: plannerId))
    }

    private var isEditing: Bool { editMode?.wrappedValue.isEditing == true }

    var body: some View {
        List {
            if viewModel.categories.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "카테고리 없음",
                    systemImage: "tag.slash",
                    description: Text("+ 버튼을 눌러 카테고리를 추가하세요.")
                )
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(viewModel.categories) { category in
                        categoryListRow(category)
                    }
                    .onMove { viewModel.moveCategory(from: $0, to: $1) }
                }
            }
        }
        .navigationTitle("카테고리 관리")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: presentsAsSheet ? .topBarLeading : .topBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.openAddSheet()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $viewModel.isSheetPresented) {
            CategoryEditSheet(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .task { await viewModel.fetchCategories() }
        .alert("카테고리 삭제", isPresented: $viewModel.showDeleteAlert) {
            Button("취소", role: .cancel) { viewModel.cancelDelete() }
            Button("삭제", role: .destructive) {
                Task { await viewModel.confirmDelete() }
            }
        } message: {
            if let category = viewModel.deletingCategory {
                Text(viewModel.deleteAlertMessage(for: category))
            }
        }
        .alert("인터넷 연결이 필요해요", isPresented: $viewModel.showOfflineCategoryAlert) {
            Button("확인") { viewModel.confirmOfflineCategoryAlert() }
        } message: {
            Text("노션과 연동된 카테고리는 인터넷에 연결된 상태에서 추가하거나 삭제할 수 있어요.")
        }
        // 다른 색 세트의 색으로 저장했을 때: 이 플래너 카테고리 색을 모두 그 세트로?
        .alert("이 플래너 카테고리 색을 모두 이 세트로 바꿀까요?", isPresented: recolorAlertBinding) {
            Button("바꾸기") { Task { await viewModel.confirmRecolor() } }
            Button("이 카테고리만", role: .cancel) { viewModel.cancelRecolor() }
        } message: {
            Text("이전 세트 색을 쓰던 카테고리만 같은 자리 색으로 바뀌고, 직접 고른 색은 그대로입니다.")
        }
    }

    private var recolorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.showRecolorAlert },
            // 창만 닫는다 (버튼 동작보다 먼저 불려도 「바꾸기」가 쓸 값을 지우지 않게)
            set: { if !$0 { viewModel.dismissRecolorAlert() } }
        )
    }

    @ViewBuilder
    private func categoryListRow(_ category: Category) -> some View {
        HStack(spacing: 10) {
            if isEditing {
                Button {
                    viewModel.requestDelete(category)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

            CategoryRow(
                category: category,
                isEditing: isEditing,
                onToggleHidden: { viewModel.toggleHidden(category) }
            )
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isEditing else { return }
                viewModel.openEditSheet(category)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                viewModel.requestDelete(category)
            } label: {
                Label("삭제", systemImage: "trash")
            }
            if category.isHidden {
                Button {
                    viewModel.toggleHidden(category)
                } label: {
                    Label("활성화", systemImage: "eye")
                }
                .tint(.blue)
            } else {
                Button {
                    viewModel.toggleHidden(category)
                } label: {
                    Label("숨기기", systemImage: "eye.slash")
                }
                .tint(.gray)
            }
        }
    }
}

// MARK: - 카테고리 배지 (TodoView에서도 사용)

struct CategoryBadge: View {
    let category: Category
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: category.colorHex))
                .frame(width: size, height: size)
            Image(systemName: CategoryIconName.resolved(category.icon))
                .font(.system(size: size * 0.44, weight: .semibold))
                // 파스텔처럼 밝은 색 위에서도 보이게 배경에 맞춰 흰색/진한 색
                .foregroundStyle(Color(hex: category.colorHex).readableForeground)
        }
    }
}

// MARK: - 활성 카테고리 행

private struct CategoryRow: View {
    let category: Category
    let isEditing: Bool
    let onToggleHidden: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            CategoryBadge(category: category, size: 32)
                .grayscale(category.isHidden ? 1.0 : 0)
                .opacity(category.isHidden ? 0.4 : 1.0)
            Text(category.name)
                .font(.body)
                .foregroundStyle(category.isHidden ? .secondary : .primary)
            Spacer()
            if isEditing {
                Button(action: onToggleHidden) {
                    Image(systemName: category.isHidden ? "eye.slash" : "eye")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 추가/편집 시트

private struct CategoryEditSheet: View {
    @Bindable var viewModel: CategoryViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        CategoryBadge(
                            category: Category(
                                name: viewModel.editName.isEmpty ? "카테고리" : viewModel.editName,
                                colorHex: viewModel.editColorHex,
                                icon: viewModel.editIcon
                            ),
                            size: 40
                        )
                        TextField("카테고리 이름", text: $viewModel.editName)
                            .font(.body)
                            .focused($isNameFocused)
                            .disabled(viewModel.isNotionCategorySyncEnabled && viewModel.isEditing)
                            .overlay {
                                if viewModel.isNotionCategorySyncEnabled && viewModel.isEditing {
                                    Color.clear
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            viewModel.requestNotionNameChangeAlert()
                                        }
                                }
                            }
                    }
                    .padding(.vertical, 4)
                }

                Section("색상") {
                    CategoryColorSetPicker(
                        selectedHex: viewModel.editColorHex,
                        setId: viewModel.editColorSetTab,
                        onSelectSet: { viewModel.selectColorSetTab($0) },
                        onSelect: { viewModel.selectColor($0) },
                        onAddCustom: { viewModel.addCustomColor($0) },
                        onRemoveCustom: { viewModel.removeCustomColor($0) },
                        removedHexes: viewModel.removedCustomHexes
                    )
                }

                Section("아이콘") {
                    CategoryIconPagePicker(
                        selectedIcon: viewModel.editIcon,
                        colorHex: viewModel.editColorHex,
                        onSelect: { viewModel.selectIcon($0) }
                    )
                    .padding(.vertical, 4)
                }

                if viewModel.isEditing {
                    Section {
                        Button {
                            if let category = viewModel.editingCategory {
                                viewModel.requestDelete(category)
                            }
                        } label: {
                            Label("영구 삭제", systemImage: "trash")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.red, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .navigationTitle(viewModel.isEditing ? "카테고리 편집" : "카테고리 추가")
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
                        if viewModel.isSaving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("저장")
                        }
                    }
                    .toolbarPrimaryActionStyle(
                        isEnabled: !viewModel.editName.trimmingCharacters(in: .whitespaces).isEmpty && !viewModel.isSaving
                    )
                    .disabled(
                        viewModel.editName.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSaving
                    )
                }
            }
            .onAppear { isNameFocused = true }
            .onChange(of: viewModel.editName) { _, name in viewModel.autoMatchIcon(for: name) }
            .sensoryFeedback(.selection, trigger: viewModel.editColorHex)
            .sensoryFeedback(.selection, trigger: viewModel.editIcon)
            .alert("카테고리 삭제", isPresented: $viewModel.showDeleteAlert) {
                Button("취소", role: .cancel) { viewModel.cancelDelete() }
                Button("삭제", role: .destructive) {
                    Task { await viewModel.confirmDelete() }
                }
            } message: {
                if let category = viewModel.deletingCategory {
                    Text(viewModel.deleteAlertMessage(for: category))
                }
            }
            .alert("인터넷 연결이 필요해요", isPresented: $viewModel.showOfflineCategoryAlert) {
                Button("확인") { viewModel.confirmOfflineCategoryAlert() }
            } message: {
                Text("노션과 연동된 카테고리는 인터넷에 연결된 상태에서 추가하거나 삭제할 수 있어요.")
            }
            .alert("이름은 노션에서 변경해주세요", isPresented: $viewModel.showNotionNameChangeAlert) {
                Button("확인") { viewModel.confirmNotionNameChange() }
            } message: {
                Text("노션에서 이름을 변경한 후 카테고리 관리 화면에 다시 들어오면 자동 반영돼요.")
            }
        }
    }
}
