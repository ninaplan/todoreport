import SwiftUI

struct TodoView: View {
    @State private var viewModel = TodoViewModel()
    @State private var newTodoTitle: String = ""
    @State private var isAddingTodo: Bool = false
    @State private var showDatePicker: Bool = false
    @State private var showViewOptions: Bool = false
    @State private var showPlannerSheet: Bool = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                List {
                    // 날짜 + 완료율 + 데일리리포트 섹션
                    Section {
                        DateNavigationRow(viewModel: viewModel, showDatePicker: $showDatePicker)
                        CompletionRateRow(
                            rate: viewModel.completionRate,
                            completed: viewModel.todos.filter(\.isCompleted).count,
                            total: viewModel.todos.count
                        )
                        DailyReportSkeletonRow()
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 24, bottom: 4, trailing: 24))

                    // 투두 목록
                    Section {
                        ForEach(viewModel.displayedTodos) { todo in
                            TodoRow(todo: todo)
                                // 오른쪽 스와이프 → 완료/미완료 토글
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        viewModel.toggleTodo(todo)
                                    } label: {
                                        CircleSwipeIcon(
                                            systemName: todo.isCompleted ? "xmark" : "checkmark",
                                            color: todo.isCompleted ? Color(.systemGray3) : Color.nockOrange
                                        )
                                    }
                                    .tint(Color(.systemBackground))
                                }
                                // 왼쪽 스와이프 → 내일하기 / 날짜변경 / 삭제
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        viewModel.deleteTodo(todo)
                                    } label: {
                                        CircleSwipeIcon(systemName: "trash", color: .red)
                                    }
                                    .tint(Color(.systemBackground))

                                    Button {
                                        // TODO: 날짜 변경 시트 오픈
                                    } label: {
                                        CircleSwipeIcon(systemName: "calendar.badge.clock", color: .blue)
                                    }
                                    .tint(Color(.systemBackground))

                                    Button {
                                        viewModel.moveToTomorrow(todo)
                                    } label: {
                                        CircleSwipeIcon(systemName: "calendar", color: Color.nockOrange)
                                    }
                                    .tint(Color(.systemBackground))
                                }
                        }

                        AddTodoRow(
                            newTodoTitle: $newTodoTitle,
                            isAdding: $isAddingTodo
                        ) {
                            viewModel.addTodo(title: newTodoTitle)
                            newTodoTitle = ""
                            isAddingTodo = false
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 24, bottom: 4, trailing: 24))
                }
                .listStyle(.plain)
                .task { await viewModel.fetchTodos() }

                FloatingCaptureButton {
                    // TODO: QuickCapture 시트 오픈
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
        }
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

// MARK: - 데일리리포트 스켈레톤

private struct DailyReportSkeletonRow: View {
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("별점")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("☆☆☆☆☆")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider().frame(height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text("하루 리뷰")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("오늘 하루 어떠셨나요?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary.opacity(0.6))
            }

            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 투두 행 (탭 없음 — 오른쪽 스와이프로 완료 토글)

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

// MARK: - 원형 스와이프 아이콘

private struct CircleSwipeIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.callout.weight(.medium))
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .background(color)
            .clipShape(Circle())
            .padding(.horizontal, 4)
    }
}

// MARK: - 보기 옵션 팝오버

private struct ViewOptionsPopover: View {
    @Bindable var viewModel: TodoViewModel
    @State private var sortExpanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // 완료된 할일 숨기기
            HStack {
                Text("완료된 할일 숨기기")
                    .font(.subheadline)
                Spacer()
                Toggle("", isOn: $viewModel.hideCompleted)
                    .labelsHidden()
                    .tint(Color.nockOrange)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            // 카테고리로 보기
            HStack {
                Text("카테고리로 보기")
                    .font(.subheadline)
                Spacer()
                Toggle("", isOn: $viewModel.groupByCategory)
                    .labelsHidden()
                    .tint(Color.nockOrange)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            // 정렬 옵션 (탭 시 인라인 드롭다운)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    sortExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("정렬 옵션")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: sortExpanded ? "chevron.up" : "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }

            if sortExpanded {
                Divider()
                ForEach(TodoSortOrder.allCases, id: \.self) { order in
                    Button {
                        viewModel.sortOrder = order
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: viewModel.sortOrder == order ? "record.circle.fill" : "circle")
                                .font(.subheadline)
                                .foregroundStyle(viewModel.sortOrder == order ? Color.nockOrange : .secondary)
                            Text(order.rawValue)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    }
                    if order != TodoSortOrder.allCases.last {
                        Divider().padding(.leading, 44)
                    }
                }
            }
        }
        .frame(minWidth: 260)
    }
}

// MARK: - 플래너 선택 시트

private struct PlannerSelectionSheet: View {
    let currentName: String
    @Environment(\.dismiss) private var dismiss
    @State private var showProAlert: Bool = false

    // TODO: ViewModel에서 실제 플래너 목록 가져오기
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
