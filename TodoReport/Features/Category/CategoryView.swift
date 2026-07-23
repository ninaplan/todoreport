import SwiftUI

struct CategoryView: View {
    @State private var viewModel: CategoryViewModel

    init(plannerId: String? = nil) {
        _viewModel = State(initialValue: CategoryViewModel(plannerId: plannerId))
    }

    var body: some View {
        List {
            Section("색상 팔레트") {
                CategoryPaletteSetPicker(
                    selectedSetId: viewModel.storedPaletteSetId,
                    onSelect: { viewModel.selectPaletteSet($0) }
                )
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            }

            if viewModel.categories.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "카테고리 없음",
                    systemImage: "tag.slash",
                    description: Text("+ 버튼을 눌러 카테고리를 추가하세요.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.categories) { category in
                    CategoryRow(category: category)
                        .contentShape(Rectangle())
                        .onTapGesture { viewModel.openEditSheet(category) }
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
                .onMove { viewModel.moveCategory(from: $0, to: $1) }
            }
        }
        .navigationTitle("카테고리 관리")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
    }
}

// MARK: - 팔레트 세트 선택

private struct CategoryPaletteSetPicker: View {
    let selectedSetId: String
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(CategoryPaletteSet.all) { set in
                    let isSelected = set.id == selectedSetId
                    Button {
                        onSelect(set.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 3) {
                                ForEach(set.colors.prefix(6), id: \.self) { hex in
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 10, height: 10)
                                }
                            }
                            Text(set.displayName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(isSelected ? Color.nockOrange : .primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    isSelected ? Color.nockOrange : Color.clear,
                                    lineWidth: 2
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
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
            Image(systemName: category.icon)
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - 활성 카테고리 행

private struct CategoryRow: View {
    let category: Category

    var body: some View {
        HStack(spacing: 12) {
            CategoryBadge(category: category, size: 32)
                .grayscale(category.isHidden ? 1.0 : 0)
                .opacity(category.isHidden ? 0.4 : 1.0)
            Text(category.name)
                .font(.body)
                .foregroundStyle(category.isHidden ? .secondary : .primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 추가/편집 시트

private struct CategoryEditSheet: View {
    @Bindable var viewModel: CategoryViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool

    private let colorColumns = Array(repeating: GridItem(.flexible()), count: 6)
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
                    LazyVGrid(columns: colorColumns, spacing: 14) {
                        ForEach(viewModel.activePaletteColors, id: \.self) { hex in
                            Button {
                                viewModel.selectColor(hex)
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 36, height: 36)
                                    if viewModel.editColorHex.uppercased() == hex.uppercased() {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
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
