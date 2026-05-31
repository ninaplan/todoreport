import SwiftUI

struct TodoView: View {
    @State private var viewModel = TodoViewModel()
    @State private var dailyReportViewModel = DailyReportViewModel()
    @State private var newTodoTitle: String = ""
    @State private var isAddingTodo: Bool = false
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
        @Bindable var vm = viewModel
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollViewReader { proxy in
                List {
                    // 날짜 + 완료율 + 데일리리포트 카드
                    Section {
                        DateNavigationRow(viewModel: viewModel)
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
                        if viewModel.isNotionSyncing {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("노션에서 자료를 읽어오고 있습니다.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
                        }
                        todoRows(for: viewModel.filteredTodos)
                        addTodoRow
                            .id("addTodoRow")
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                    guard isAddingTodo else { return }
                    withAnimation { proxy.scrollTo("addTodoRow", anchor: .bottom) }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable {
                    await viewModel.fetchTodos()
                    await dailyReportViewModel.fetchReport(for: viewModel.selectedDate, completionRate: viewModel.completionRate)
                }
                .onAppear { Task { await viewModel.fetchTodos() } }
                .onChange(of: PlannerService.shared.selectedPlannerId) { _, _ in
                    dailyReportViewModel.switchReport()
                    Task {
                        await viewModel.switchPlanner()
                        await dailyReportViewModel.fetchReport(
                            for: viewModel.selectedDate,
                            completionRate: viewModel.completionRate
                        )
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    Task { await viewModel.fetchTodos() }
                }
                } // ScrollViewReader

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
                        HStack(spacing: 6) {
                            if let planner = PlannerService.shared.selectedPlanner {
                                PlannerIconView(
                                    iconType: planner.iconType,
                                    iconImageData: planner.iconImageData,
                                    colorHex: planner.colorHex,
                                    size: 22
                                )
                            }
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
            .sheet(isPresented: $vm.showDatePicker) {
                DatePickerSheet(selectedDate: Binding(
                    get: { viewModel.selectedDate },
                    set: { viewModel.selectedDate = $0 }
                ))
            }
            .sheet(isPresented: $vm.showDatePaywall) {
                ProPaywallSheet(
                    message: viewModel.datePaywallMessage,
                    onDismiss: { viewModel.dismissDatePaywall() }
                )
                .presentationDetents([.medium])
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
                FilterChip(label: "전체", color: AppTheme.shared.accent, isSelected: selectedId == nil) {
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

            Button { viewModel.requestDatePicker() } label: {
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
                .foregroundStyle(todo.isCompleted ? AppTheme.shared.accent : Color(.tertiaryLabel))
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
    let onAdd: () -> Void

    var body: some View {
        if isAdding {
            HStack(spacing: 12) {
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundStyle(Color(.tertiaryLabel))
                // AutoFocusTextField(UITextField 기반) — SwiftUI TextField 사용 시 한글 자모음 분리 버그 방지
                AutoFocusTextField(
                    text: $newTodoTitle,
                    placeholder: "새 투두",
                    font: .systemFont(ofSize: 17),
                    onReturn: {
                        let trimmed = newTodoTitle.trimmingCharacters(in: .whitespaces)
                        if trimmed.isEmpty { return false }
                        onAdd()
                        return true  // 포커스 유지 → textFieldShouldReturn이 tf.text="" 처리
                    },
                    onDismiss: {
                        isAdding = false
                    }
                )
                .frame(height: 36)
            }
        } else {
            Button { isAdding = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.shared.accent)
                    Text("투두 추가")
                        .font(.body)
                        .foregroundStyle(AppTheme.shared.accent)
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
            .foregroundStyle(AppTheme.shared.accent)
            .opacity(visible ? 1 : 0)
            .frame(width: 16)
    }
}

// MARK: - 플래너 선택 시트

private struct PlannerSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showAddPlanner = false
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
                                PlannerIconView(
                                    iconType: planner.iconType,
                                    iconImageData: planner.iconImageData,
                                    colorHex: planner.colorHex,
                                    size: 28
                                )
                                Text(planner.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if planner.isNotionConnected {
                                    Text("N")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 18, height: 18)
                                        .background(Color.black, in: Circle())
                                }
                                if planner.id == PlannerService.shared.selectedPlannerId {
                                    Image(systemName: "checkmark")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(AppTheme.shared.accent)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button {
                        guard isPro else { showProAlert = true; return }
                        showAddPlanner = true
                    } label: {
                        Label("플래너 추가", systemImage: "plus")
                            .foregroundStyle(isPro ? AppTheme.shared.accent : .secondary)
                    }
                }
            }
            .navigationTitle("플래너")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") { dismiss() }
                        .tint(AppTheme.shared.accent)
                }
            }
        }
        .presentationDetents([.medium])
        .sheet(isPresented: $showAddPlanner) {
            PlannerAddView()
        }
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
                .tint(AppTheme.shared.accent)
                .padding(.horizontal)
                .navigationTitle("날짜 선택")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("완료") { dismiss() }
                            .tint(AppTheme.shared.accent)
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
                .tint(AppTheme.shared.accent)
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
                        .tint(AppTheme.shared.accent)
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
                            .tint(AppTheme.shared.accent)
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
                    .tint(isSaveEnabled ? AppTheme.shared.accent : Color(.tertiaryLabel))
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
                .background(AppTheme.shared.accent)
                .clipShape(Circle())
                .shadow(color: AppTheme.shared.accent.opacity(0.4), radius: 8, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }
}
