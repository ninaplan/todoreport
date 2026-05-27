import SwiftUI

struct TodoView: View {
    @State private var viewModel = TodoViewModel()
    @State private var dailyReportViewModel = DailyReportViewModel()
    @State private var newTodoTitle: String = ""
    @State private var isAddingTodo: Bool = false
    @State private var showDatePicker: Bool = false
    @State private var showViewOptions: Bool = false
    @State private var showPlannerSheet: Bool = false
    @State private var showQuickCapture: Bool = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                List {
                    // 날짜 + 완료율 + 데일리리포트 섹션
                    Section {
                        DateNavigationRow(viewModel: viewModel, showDatePicker: $showDatePicker)
                        CompletionRateRow(
                            rate: viewModel.filteredCompletionRate,
                            completed: viewModel.filteredCompletedCount,
                            total: viewModel.filteredTotalCount
                        )
                        DailyReportCard(
                            viewModel: dailyReportViewModel,
                            date: viewModel.selectedDate,
                            completionRate: viewModel.completionRate
                        )
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 24, bottom: 4, trailing: 24))

                    // 카테고리 필터 칩
                    if !viewModel.activeCategories.isEmpty {
                        Section {
                            CategoryFilterBar(
                                categories: viewModel.activeCategories,
                                selectedId: $viewModel.selectedCategoryFilter
                            )
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    }

                    // 투두 목록
                    Section {
                        todoRows(for: viewModel.filteredTodos)
                        addTodoRow
                    }
                }
                .listStyle(.plain)
                .onAppear { Task { await viewModel.fetchTodos() } }

                FloatingCaptureButton {
                    showQuickCapture = true
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showPlannerSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.plannerName)
                                .font(.headline)
                            Image(systemName: "chevron.down")
                                .font(.caption.bold())
                        }
                    }
                    .tint(.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showViewOptions.toggle()
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .tint(.primary)
                    .popover(isPresented: $showViewOptions) {
                        ViewOptionsPopover(viewModel: viewModel)
                            .presentationCompactAdaptation(.popover)
                    }
                }
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(selectedDate: Binding(
                    get: { viewModel.selectedDate },
                    set: { viewModel.selectedDate = $0 }
                ))
            }
            .sheet(isPresented: $showPlannerSheet) {
                PlannerSelectionSheet(currentName: viewModel.plannerName)
            }
            .sheet(isPresented: $showQuickCapture) {
                QuickCaptureView(defaultCategoryId: viewModel.selectedCategoryFilter) { title, memo, categoryId, date in
                    viewModel.addTodo(title: title, memo: memo, categoryId: categoryId, date: date)
                }
            }
        }
    }

    // MARK: - 투두 행 빌더 (공통 스와이프 액션 포함)

    @ViewBuilder
    private func todoRows(for todos: [Todo]) -> some View {
        ForEach(todos) { todo in
            TodoRow(todo: todo)
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    viewModel.toggleTodo(todo)
                } label: {
                    if todo.isCompleted {
                        Image(systemName: "arrow.counterclockwise")
                    } else {
                        Image(systemName: "checkmark")
                            .fontWeight(.bold)
                    }
                }
                .tint(todo.isCompleted ? Color.gray.opacity(0.3) : Color.nockOrange)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    viewModel.deleteTodo(todo)
                } label: {
                    Image(systemName: "trash")
                }
                Button {
                    // TODO: 날짜 변경 시트 오픈
                } label: {
                    Image(systemName: "calendar")
                }
                .tint(Color(red: 1, green: 0.584, blue: 0))
                Button {
                    viewModel.moveToTomorrow(todo)
                } label: {
                    Image(systemName: "arrow.forward.folder")
                }
                .tint(.blue)
            }
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 24, bottom: 4, trailing: 24))
        }
    }

    private var addTodoRow: some View {
        AddTodoRow(
            newTodoTitle: $newTodoTitle,
            isAdding: $isAddingTodo
        ) {
            viewModel.addTodo(title: newTodoTitle, categoryId: viewModel.selectedCategoryFilter)
            newTodoTitle = ""
            isAddingTodo = false
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 24, bottom: 4, trailing: 24))
    }
}

// MARK: - 카테고리 필터 바

private struct CategoryFilterBar: View {
    let categories: [Category]
    @Binding var selectedId: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "전체", isSelected: selectedId == nil) {
                    selectedId = nil
                }
                ForEach(categories) { category in
                    FilterChip(
                        label: category.name,
                        color: Color(hex: category.colorHex),
                        isSelected: selectedId == category.id
                    ) {
                        selectedId = category.id
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 4)
        }
    }
}

private struct FilterChip: View {
    let label: String
    var color: Color = Color.nockOrange
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : color)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? color : color.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - 날짜 이동 행

private struct DateNavigationRow: View {
    let viewModel: TodoViewModel
    @Binding var showDatePicker: Bool

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월 d일 EEEE"
        return f
    }()

    var body: some View {
        HStack(spacing: 0) {
            Button { viewModel.goToPreviousDay() } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline)
                    .foregroundStyle(.secondary.opacity(0.4))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }

            Button { showDatePicker = true } label: {
                Text(Self.dateFormatter.string(from: viewModel.selectedDate))
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Button { viewModel.goToNextDay() } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.secondary.opacity(0.4))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 완료율 바

private struct CompletionRateRow: View {
    let rate: Double
    let completed: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("완료율")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(completed)/\(total)개  \(Int(rate * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(Color.nockOrange)
            }
            ProgressView(value: rate)
                .tint(Color.nockOrange)
                .scaleEffect(y: 1.4)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 투두 행

private struct TodoRow: View {
    let todo: Todo

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(todo.isCompleted ? Color.nockOrange : Color(.tertiaryLabel))
                .animation(.easeInOut(duration: 0.15), value: todo.isCompleted)

            Text(todo.title)
                .font(.body)
                .strikethrough(todo.isCompleted)
                .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                .animation(.easeInOut(duration: 0.15), value: todo.isCompleted)

            Spacer()
        }
    }
}

// MARK: - 투두 추가 행

private struct AddTodoRow: View {
    @Binding var newTodoTitle: String
    @Binding var isAdding: Bool
    @FocusState private var isFocused: Bool
    let onAdd: () -> Void

    var body: some View {
        if isAdding {
            HStack(spacing: 12) {
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundStyle(Color(.tertiaryLabel))

                TextField("새 투두", text: $newTodoTitle)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        if newTodoTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                            isAdding = false
                        } else {
                            onAdd()
                        }
                    }
                    .onAppear { isFocused = true }
            }
        } else {
            Button {
                isAdding = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.nockOrange)
                    Text("투두 추가")
                        .font(.body)
                        .foregroundStyle(Color.nockOrange)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - 보기 옵션 팝오버

private struct ViewOptionsPopover: View {
    @Bindable var viewModel: TodoViewModel
    @State private var sortExpanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            optionRow(icon: "eye.slash", label: "완료된 할일 숨기기", isOn: viewModel.hideCompleted) {
                viewModel.hideCompleted.toggle()
            }
            Divider()
            optionRow(icon: "text.alignleft", label: "할일 메모 보기", isOn: viewModel.showMemo) {
                viewModel.showMemo.toggle()
            }
            Divider()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    sortExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: AppConstants.IconSize.menu))
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text("정렬 옵션")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: sortExpanded ? "chevron.up" : "chevron.right")
                        .font(.system(size: AppConstants.IconSize.menu).bold())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if sortExpanded {
                Divider()
                ForEach(TodoSortOrder.allCases, id: \.self) { order in
                    Button {
                        viewModel.sortOrder = order
                    } label: {
                        HStack(spacing: 12) {
                            Color.clear.frame(width: 20)
                            Text(order.rawValue)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Spacer()
                            checkmark(visible: viewModel.sortOrder == order)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    if order != TodoSortOrder.allCases.last {
                        Divider().padding(.leading, 52)
                    }
                }
            }
        }
        .frame(minWidth: 260)
    }

    private func optionRow(icon: String, label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: AppConstants.IconSize.menu))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                checkmark(visible: isOn)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func checkmark(visible: Bool) -> some View {
        Image(systemName: "checkmark")
            .font(.system(size: AppConstants.IconSize.menu).bold())
            .foregroundStyle(Color.nockOrange)
            .opacity(visible ? 1 : 0)
            .frame(width: 16)
    }
}

// MARK: - 플래너 선택 시트

private struct PlannerSelectionSheet: View {
    let currentName: String
    @Environment(\.dismiss) private var dismiss
    @State private var showProAlert: Bool = false

    private let planners: [String] = ["내 플래너"]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(planners, id: \.self) { planner in
                        HStack {
                            Text(planner)
                            Spacer()
                            if planner == currentName {
                                Image(systemName: "checkmark")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color.nockOrange)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { dismiss() }
                    }
                }
                Section {
                    Button {
                        showProAlert = true
                    } label: {
                        Text("플래너 추가하기 🔒")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("플래너")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") { dismiss() }
                        .tint(Color.nockOrange)
                }
            }
        }
        .presentationDetents([.medium])
        .alert("Pro 기능", isPresented: $showProAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("멀티 플래너는 Pro 구독 기능입니다.")
        }
    }
}

// MARK: - 날짜 피커 시트

private struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DatePicker("날짜 선택", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(Color.nockOrange)
                .padding(.horizontal)
                .navigationTitle("날짜 선택")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("완료") { dismiss() }
                            .tint(Color.nockOrange)
                    }
                }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 플로팅 캡처 버튼

private struct FloatingCaptureButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.nockOrange)
                .clipShape(Circle())
                .shadow(color: Color.nockOrange.opacity(0.4), radius: 8, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }
}
