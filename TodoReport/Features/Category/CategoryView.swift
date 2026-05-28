import SwiftUI

struct CategoryView: View {
    @State private var viewModel = CategoryViewModel()

    var body: some View {
        List {
            // 활성 카테고리
            ForEach(viewModel.categories) { category in
                CategoryRow(category: category)
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.openEditSheet(category) }
            }
            .onMove { viewModel.moveCategory(from: $0, to: $1) }

            // 보관된 카테고리
            if !viewModel.archivedCategories.isEmpty {
                Section("보관된 카테고리") {
                    ForEach(viewModel.archivedCategories) { category in
                        ArchivedCategoryRow(category: category)
                            .contentShape(Rectangle())
                            .onTapGesture { viewModel.requestRestore(category) }
                    }
                }
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
        }
        .task { await viewModel.fetchCategories() }
        .overlay {
            if viewModel.categories.isEmpty && viewModel.archivedCategories.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "카테고리 없음",
                    systemImage: "tag.slash",
                    description: Text("+ 버튼을 눌러 카테고리를 추가하세요.")
                )
            }
        }
        .alert("복원", isPresented: $viewModel.showRestoreAlert) {
            Button("취소", role: .cancel) { viewModel.cancelRestore() }
            Button("복원") {
                Task { await viewModel.confirmRestore() }
            }
        } message: {
            if let category = viewModel.restoringCategory {
                Text("'\(category.name)' 카테고리를 다시 활성화할까요?")
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
            Text(category.name)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 보관된 카테고리 행

private struct ArchivedCategoryRow: View {
    let category: Category

    var body: some View {
        HStack(spacing: 12) {
            CategoryBadge(category: category, size: 32)
                .grayscale(1.0)
                .opacity(0.5)
            Text(category.name)
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "arrow.counterclockwise")
                Text("복원")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
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
                // 미리보기
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
                        Text(viewModel.editName.isEmpty ? "카테고리 이름" : viewModel.editName)
                            .font(.body)
                            .foregroundStyle(viewModel.editName.isEmpty ? .tertiary : .primary)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                // 이름
                Section("이름") {
                    TextField("카테고리 이름", text: $viewModel.editName)
                        .focused($isNameFocused)
                }

                // 색상
                Section("색상") {
                    LazyVGrid(columns: colorColumns, spacing: 14) {
                        ForEach(Category.colorPalette, id: \.self) { hex in
                            Button {
                                viewModel.editColorHex = hex
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 36, height: 36)
                                    if viewModel.editColorHex == hex {
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

                // 아이콘
                Section("아이콘") {
                    LazyVGrid(columns: iconColumns, spacing: 12) {
                        ForEach(Category.iconPalette, id: \.self) { symbol in
                            Button {
                                viewModel.editIcon = symbol
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

                // 보관 버튼 (편집 시에만 표시)
                if viewModel.isEditing {
                    Section {
                        Button {
                            if let category = viewModel.editingCategory {
                                Task { await viewModel.requestArchive(category) }
                            }
                        } label: {
                            Text("이 카테고리 보관")
                                .foregroundStyle(Color(.systemRed))
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .navigationTitle(viewModel.isEditing ? "카테고리 편집" : "카테고리 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        Task { await viewModel.saveEdit() }
                    }
                    .fontWeight(.semibold)
                    .tint(Color.nockOrange)
                    .disabled(viewModel.editName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { isNameFocused = true }
            .sensoryFeedback(.selection, trigger: viewModel.editColorHex)
            .sensoryFeedback(.selection, trigger: viewModel.editIcon)
            .sensoryFeedback(.warning, trigger: viewModel.showArchiveAlert)
            .alert("보관하시겠어요?", isPresented: $viewModel.showArchiveAlert) {
                Button("취소", role: .cancel) { viewModel.cancelArchive() }
                Button("보관", role: .destructive) {
                    if let category = viewModel.archivingCategory {
                        Task { await viewModel.confirmArchive(category) }
                    }
                }
            } message: {
                if let category = viewModel.archivingCategory {
                    Text("\(category.name) 카테고리에 미완료 할일 \(viewModel.pendingArchiveCount)개가 있어요.\n보관하면 전체 탭에서만 표시됩니다.")
                }
            }
        }
    }
}
