import SwiftUI

struct CategoryView: View {
    @State private var viewModel: CategoryViewModel
    @State private var allChipColorHex: String
    @State private var showAllChipColorSheet = false
    @Environment(\.editMode) private var editMode
    private let plannerId: String?

    init(plannerId: String? = nil) {
        self.plannerId = plannerId
        _viewModel = State(initialValue: CategoryViewModel(plannerId: plannerId))
        let pid = plannerId ?? PlannerService.shared.selectedPlanner?.id
        _allChipColorHex = State(initialValue: AllChipColorStore.hex(for: pid))
    }

    private var resolvedPlannerId: String? {
        plannerId ?? PlannerService.shared.selectedPlanner?.id
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
                    allChipRow
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard !isEditing else { return }
                            showAllChipColorSheet = true
                        }

                    ForEach(viewModel.categories) { category in
                        categoryListRow(category)
                    }
                    .onMove { viewModel.moveCategory(from: $0, to: $1) }
                }
            }
        }
        .navigationTitle("카테고리 관리")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: allChipColorHex)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                EditButton()
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
        .sheet(isPresented: $showAllChipColorSheet) {
            AllChipColorSheet(
                selectedHex: allChipColorHex,
                onSelect: { hex in
                    allChipColorHex = hex
                    AllChipColorStore.set(hex, for: resolvedPlannerId)
                }
            )
            .presentationDetents([.medium, .large])
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
    }

    private var allChipRow: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: allChipColorHex))
                .frame(width: 32, height: 32)
            Text("전체")
                .font(.body)
                .foregroundStyle(.primary)
            Spacer()
            if !isEditing {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
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

// MARK: - 전체 칩 색상 시트

private struct AllChipColorSheet: View {
    @State private var selectedHex: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    init(selectedHex: String, onSelect: @escaping (String) -> Void) {
        _selectedHex = State(initialValue: selectedHex)
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("색상") {
                    ColorSwatchPicker(selectedHex: selectedHex) { hex in
                        selectedHex = hex
                        onSelect(hex)
                    }
                }
            }
            .navigationTitle("전체 칩 색상")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("확인") { dismiss() }
                        .toolbarPrimaryActionStyle()
                }
            }
            .sensoryFeedback(.selection, trigger: selectedHex)
        }
    }
}

// MARK: - 색상 스와치 + ColorPicker

private struct ColorSwatchPicker: View {
    let selectedHex: String
    let onSelect: (String) -> Void

    private let columns = Array(repeating: GridItem(.flexible()), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Category.baseColors, id: \.self) { hex in
                    Button {
                        onSelect(hex)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 36, height: 36)
                            if selectedHex.uppercased() == hex.uppercased() {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color(hex: hex).readableForeground)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)

            Divider()
                .padding(.top, 16)
                .padding(.bottom, 12)

            ColorPicker(
                "직접 선택",
                selection: Binding(
                    get: { Color(hex: selectedHex) },
                    set: { onSelect($0.hexString) }
                ),
                supportsOpacity: false
            )
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
            Image(systemName: category.icon)
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(.white)
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

    private let iconColumns  = Array(repeating: GridItem(.flexible()), count: 5)

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
                    ColorSwatchPicker(selectedHex: viewModel.editColorHex) { hex in
                        viewModel.selectColor(hex)
                    }
                }

                Section("아이콘") {
                    LazyVGrid(columns: iconColumns, spacing: 12) {
                        ForEach(Category.iconPalette, id: \.self) { symbol in
                            Button {
                                viewModel.selectIcon(symbol)
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(
                                            viewModel.editIcon == symbol
                                                ? Color(hex: viewModel.editColorHex)
                                                : Color(hex: viewModel.editColorHex).opacity(0.12)
                                        )
                                        .frame(width: 44, height: 44)
                                    Image(systemName: symbol)
                                        .font(.system(size: 18))
                                        .foregroundStyle(
                                            viewModel.editIcon == symbol
                                                ? .white
                                                : Color(hex: viewModel.editColorHex)
                                        )
                                }
                            }
                            .buttonStyle(.plain)
                            .animation(.easeInOut(duration: 0.15), value: viewModel.editColorHex)
                        }
                    }
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
            .alert("이름은 노션에서 변경해주세요", isPresented: $viewModel.showNotionNameChangeAlert) {
                Button("확인") { viewModel.confirmNotionNameChange() }
            } message: {
                Text("노션에서 이름을 변경한 후 카테고리 관리 화면에 다시 들어오면 자동 반영돼요.")
            }
        }
    }
}
