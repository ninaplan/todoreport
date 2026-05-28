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
    @State private var changingDateTodo: Todo? = nil
    @State private var editingTodo: Todo? = nil
    @State private var showCategorySheet: Bool = false

    @State private var hapticImpactTrigger = false
    @State private var hapticSuccessTrigger = false
    @State private var hapticWarningTrigger = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                List {
                    // 날짜 + 완료율 + 데일리리포트 카드
                    Section {
                        DateNavigationRow(viewModel: viewModel, showDatePicker: $showDatePicker)
                        DailyReportCard(
                            viewModel: dailyReportViewModel,
                            date: viewModel.selectedDate,
                            completionRate: viewModel.completionRate,
                            displayRate: viewModel.filteredCompletionRate,
                            displayCompleted: viewModel.filteredCompletedCount,
                            displayTotal: viewModel.filteredTotalCount
                        )
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

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
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .onAppear { Task { await viewModel.fetchTodos() } }

                FloatingCaptureButton {
                    showQuickCapture = true
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showPlannerSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(PlannerService.shared.selectedPlanner?.name ?? "내 플래너")
                                .font(.headline)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .thin))
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
                        ViewOptionsPopover(viewModel: viewModel) {
                            showViewOptions = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showCategorySheet = true
                            }
                        }
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
                PlannerSelectionSheet()
            }
            .sheet(isPresented: $showQuickCapture) {
                QuickCaptureView(defaultCategoryId: viewModel.selectedCategoryFilter) { title, memo, categoryId, date in
                    viewModel.addTodo(title: title, memo: memo, categoryId: categoryId, date: date)
                    hapticSuccessTrigger.toggle()
                }
            }
            .sheet(item: $changingDateTodo) { todo in
                TodoDateChangeSheet(initialDate: todo.date) { newDate in
                    viewModel.changeTodoDate(todo, to: newDate)
                    hapticSuccessTrigger.toggle()
                }
            }
            .sheet(item: $editingTodo, onDismiss: { showCategorySheet = false }) { todo in
                TodoEditSheet(
                    todo: todo,
                    categories: viewModel.activeCategories
                ) { updated in
                    viewModel.saveTodoEdit(updated)
                    hapticSuccessTrigger.toggle()
                }
            }
            .sheet(isPresented: $showCategorySheet) {
                NavigationStack {
                    CategoryView()
                }
                .presentationDragIndicator(.visible)
            }
            .sensoryFeedback(.impact, trigger: hapticImpactTrigger)
            .sensoryFeedback(.success, trigger: hapticSuccessTrigger)
            .sensoryFeedback(.warning, trigger: hapticWarningTrigger)
        }
    }

    // MARK: - 투두 행 빌더 (공통 스와이프 액션 포함)

    @ViewBuilder
    private func todoRows(for todos: [Todo]) -> some View {
        ForEach(todos) { todo in
            TodoRow(todo: todo, showMemo: viewModel.showMemo)
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.toggleTodo(todo)
                hapticImpactTrigger.toggle()
            }
            .onLongPressGesture(minimumDuration: 0.4) {
                editingTodo = todo
                hapticImpactTrigger.toggle()
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    viewModel.pinTodo(todo)
                    hapticImpactTrigger.toggle()
                } label: {
                    Image(systemName: todo.isPinned ? "pin.slash" : "pin")
                }
                .tint(todo.isPinned ? .gray : Color(red: 1, green: 0.584, blue: 0))
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    viewModel.deleteTodo(todo)
                    hapticWarningTrigger.toggle()
                } label: {
                    Image(systemName: "trash")
                }
                Button {
                    changingDateTodo = todo
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
            .listRowInsets(EdgeInsets(top: 4, leading: 24, bottom: 4, trailing: 24))
        }
    }

    private var addTodoRow: some View {
        AddTodoRow(newTodoTitle: $newTodoTitle, isAdding: $isAddingTodo) {
            viewModel.addTodo(title: newTodoTitle, categoryId: viewModel.selectedCategoryFilter)
            newTodoTitle = ""
            isAddingTodo = false
            hapticSuccessTrigger.toggle()
        }
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
                FilterChip(label: "전체", color: .nockOrange, isSelected: selectedId == nil) {
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
            .padding(.leading, 24)
            .padding(.trailing, 48)  // 그라데이션 영역 확보
            .padding(.vertical, 4)
        }
        // 우측 페이드 아웃 (스크롤 힌트)
        .overlay(alignment: .trailing) {
            LinearGradient(
                colors: [.clear, Color(.systemGroupedBackground)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 48)
            .allowsHitTesting(false)
        }
        .sensoryFeedback(.selection, trigger: selectedId)
    }
}

private struct FilterChip: View {
    let label: String
    let color: Color
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

// MARK: - 투두 행

private struct TodoRow: View {
    let todo: Todo
    let showMemo: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(todo.isCompleted ? Color.nockOrange : Color(.tertiaryLabel))
                .animation(.easeInOut(duration: 0.15), value: todo.isCompleted)
                .padding(.top, (showMemo && todo.memo != nil) ? 2 : 0)

            VStack(alignment: .leading, spacing: 3) {
                Text(todo.title)
                    .font(.body)
                    .strikethrough(todo.isCompleted)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                    .animation(.easeInOut(duration: 0.15), value: todo.isCompleted)

                if showMemo, let memo = todo.memo, !memo.isEmpty {
                    Text(memo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Spacer()

            if todo.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(Color(red: 1, green: 0.584, blue: 0).opacity(0.8))
                    .rotationEffect(.degrees(45))
                    .padding(.top, (showMemo && todo.memo != nil) ? 2 : 0)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showMemo)
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
                        guard !newTodoTitle.trimmingCharacters(in: .whitespaces).isEmpty else {
                            isAdding = false
                            return
                        }
                        onAdd()
                    }
                    .onAppear { isFocused = true }
            }
        } else {
            Button { isAdding = true } label: {
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
    let onShowCategorySheet: () -> Void
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

            Divider()

            Button(action: onShowCategorySheet) {
                HStack(spacing: 12) {
                    Image(systemName: "tag")
                        .font(.system(size: AppConstants.IconSize.menu))
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text("카테고리 설정")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: AppConstants.IconSize.menu).bold())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(minWidth: 260)
        .fixedSize(horizontal: false, vertical: true)
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
    @Environment(\.dismiss) private var dismiss
    @State private var showProAlert = false
    #if DEBUG
    private let isPro = true
    #else
    private let isPro = false
    #endif

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(PlannerService.shared.store) { planner in
                        Button {
                            PlannerService.shared.selectPlanner(planner)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(hex: planner.colorHex))
                                    .frame(width: 10, height: 10)
                                Text(planner.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if planner.id == PlannerService.shared.selectedPlannerId {
                                    Image(systemName: "checkmark")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(Color.nockOrange)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button {
                        guard isPro else { showProAlert = true; return }
                    } label: {
                        Label("플래너 추가", systemImage: "plus")
                            .foregroundStyle(isPro ? Color.nockOrange : .secondary)
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

// MARK: - 투두 날짜 변경 시트

private struct TodoDateChangeSheet: View {
    let initialDate: Date
    let onConfirm: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date

    init(initialDate: Date, onConfirm: @escaping (Date) -> Void) {
        self.initialDate = initialDate
        self.onConfirm = onConfirm
        _selectedDate = State(initialValue: Calendar.current.startOfDay(for: initialDate))
    }

    var body: some View {
        NavigationStack {
            DatePicker("날짜 선택", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(Color.nockOrange)
                .padding(.horizontal)
                .navigationTitle("날짜 변경")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("취소") { dismiss() }
                            .foregroundStyle(.secondary)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("완료") {
                            onConfirm(selectedDate)
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .tint(Color.nockOrange)
                    }
                }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 투두 편집 시트

private struct TodoEditSheet: View {
    let categories: [Category]
    let onSave: (Todo) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Todo
    @State private var showDatePicker = false

    init(todo: Todo, categories: [Category], onSave: @escaping (Todo) -> Void) {
        self.categories = categories
        self.onSave = onSave
        _draft = State(initialValue: todo)
    }

    private var isSaveEnabled: Bool {
        !draft.title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AutoFocusTextField(
                        text: $draft.title,
                        placeholder: "할일",
                        font: .systemFont(ofSize: 20, weight: .medium)
                    )
                    .frame(height: 44)

                    TextField("메모", text: Binding(
                        get: { draft.memo ?? "" },
                        set: { draft.memo = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(3...6)
                }

                Section {
                    Picker("카테고리", selection: $draft.categoryId) {
                        Text("없음").tag(Optional<String>.none)
                        ForEach(categories) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)

                    Button {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation { showDatePicker.toggle() }
                    } label: {
                        HStack {
                            Text("날짜").foregroundStyle(.primary)
                            Spacer()
                            Text(draft.date.formatted(date: .abbreviated, time: .omitted))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    if showDatePicker {
                        DatePicker("", selection: $draft.date, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                            .tint(Color.nockOrange)
                    }
                }
            }
            .navigationTitle("편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소", role: .cancel) { dismiss() }
                        .tint(.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        let trimmed = draft.title.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        var saved = draft
                        saved.title = trimmed
                        onSave(saved)
                        dismiss()
                    }
                    .disabled(!isSaveEnabled)
                    .tint(isSaveEnabled ? Color.nockOrange : Color(.tertiaryLabel))
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
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
