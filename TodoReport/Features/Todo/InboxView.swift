import SwiftUI

struct InboxView: View {
    private let highlightTodoId: String?

    @State private var viewModel = InboxViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var newTodoTitle = ""
    @State private var isAddingTodo = false
    @State private var inlineEditingTodoId: String? = nil
    @State private var changingDateTodo: Todo? = nil
    @State private var editingTodo: Todo? = nil
    @State private var snoozedActionTodo: Todo? = nil
    @State private var highlightedTodoId: String? = nil
    @State private var highlightScrollTask: Task<Void, Never>? = nil
    @State private var didConsumeHighlight = false

    @State private var hapticImpactTrigger = false
    @State private var hapticSuccessTrigger = false
    @State private var hapticWarningTrigger = false

    init(highlightTodoId: String? = nil) {
        self.highlightTodoId = highlightTodoId
    }

    var body: some View {
        @Bindable var vm = viewModel
        ScrollViewReader { proxy in
            List {
                segmentSection

                switch viewModel.segment {
                case .now:
                    nowContent
                case .snoozed:
                    snoozedContent
                case .completed:
                    completedContent
                }
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, 0)
            .task {
                await viewModel.load()
                startHighlightIfNeeded(proxy: proxy)
            }
        }
        .navigationTitle("수집함")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("완료") {
                    resignAndFinishInlineInputs()
                    dismiss()
                }
                .toolbarPrimaryActionStyle()
            }
        }
        .sheet(item: $changingDateTodo) { todo in
            TodoDateChangeSheet(
                initialDate: Calendar.current.startOfDay(for: .now),
                navigationTitleKey: "날짜 넣기"
            ) { newDate in
                viewModel.assignDate(todo, to: newDate)
                hapticSuccessTrigger.toggle()
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingTodo) { todo in
            TodoEditSheet(
                todo: todo,
                categories: viewModel.categories,
                onSave: { updated in
                    viewModel.saveTodoEdit(updated)
                    hapticSuccessTrigger.toggle()
                },
                onDeleteTapped: { deleting in
                    editingTodo = nil
                    viewModel.requestDelete(deleting)
                }
            )
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "나중에 보기",
            isPresented: $vm.showSnoozeSheet,
            titleVisibility: .visible
        ) {
            Button("다음주") { viewModel.confirmSnoozeNextWeek() }
            Button("다음달") { viewModel.confirmSnoozeNextMonth() }
            Button("직접 날짜 선택") { viewModel.openCustomSnoozePicker() }
            Button("취소", role: .cancel) { viewModel.cancelSnoozeSheet() }
        }
        .confirmationDialog(
            snoozedActionTodo?.title ?? "",
            isPresented: Binding(
                get: { snoozedActionTodo != nil },
                set: { if !$0 { snoozedActionTodo = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("지금 보기로") {
                if let todo = snoozedActionTodo {
                    viewModel.clearSnooze(todo)
                    hapticSuccessTrigger.toggle()
                }
                snoozedActionTodo = nil
            }
            Button("날짜 다시 정하기") {
                if let todo = snoozedActionTodo {
                    changingDateTodo = todo
                }
                snoozedActionTodo = nil
            }
            Button("취소", role: .cancel) { snoozedActionTodo = nil }
        }
        .sheet(isPresented: $vm.showCustomSnoozePicker) {
            customSnoozePickerSheet
        }
        .alert("이 할 일을 삭제할까요?", isPresented: $vm.showDeleteAlert) {
            Button("삭제", role: .destructive) { viewModel.confirmDelete() }
            Button("취소", role: .cancel) { viewModel.cancelDelete() }
        }
        .alert("읽기 전용 플래너", isPresented: $vm.showReadOnlyAlert) {
            Button("확인", role: .cancel) { viewModel.cancelReadOnlyAlert() }
        } message: {
            Text("이 플래너는 읽기 전용입니다. Pro 구독 시 다시 활성화됩니다.")
        }
        .sensoryFeedback(.impact, trigger: hapticImpactTrigger)
        .sensoryFeedback(.success, trigger: hapticSuccessTrigger)
        .sensoryFeedback(.warning, trigger: hapticWarningTrigger)
        .tapToDismissKeyboard()
        .onChange(of: viewModel.segment) { _, _ in
            resignAndFinishInlineInputs()
        }
    }

    // MARK: - Sections

    private var segmentSection: some View {
        Section {
            Picker("", selection: Binding(
                get: { viewModel.segment },
                set: { viewModel.segment = $0 }
            )) {
                Text("지금").tag(InboxSegment.now)
                Text(snoozedSegmentTitle).tag(InboxSegment.snoozed)
                Text(completedSegmentTitle).tag(InboxSegment.completed)
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var snoozedSegmentTitle: String {
        let count = viewModel.snoozedCount
        if count > 0 {
            return String(localized: "미뤄둠 (\(count))")
        }
        return String(localized: "미뤄둠")
    }

    private var completedSegmentTitle: String {
        let count = viewModel.completedCount
        if count > 0 {
            return String(localized: "완료됨 (\(count))")
        }
        return String(localized: "완료됨")
    }

    @ViewBuilder
    private var nowContent: some View {
        if viewModel.nowTodos.isEmpty && !isAddingTodo {
            Section {
                ContentUnavailableView(
                    "수집함에 할 일이 없습니다",
                    systemImage: "tray",
                    description: Text("날짜 없이 저장한 할 일이 여기에 모입니다.")
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        } else {
            ageBucketSections(segment: .now)
        }

        Section {
            InboxAddRow(newTodoTitle: $newTodoTitle, isAdding: $isAddingTodo) {
                viewModel.addInboxTodo(title: newTodoTitle)
                newTodoTitle = ""
                hapticSuccessTrigger.toggle()
            }
            .padding(.vertical, 8)
            .listRowInsets(EdgeInsets(top: 4, leading: 24, bottom: 4, trailing: 24))
        }
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private var snoozedContent: some View {
        if viewModel.snoozedTodos.isEmpty {
            Section {
                ContentUnavailableView(
                    "미뤄둔 할 일이 없습니다",
                    systemImage: "clock",
                    description: Text("나중에 보기로 미룬 할 일이 여기에 표시됩니다.")
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        } else {
            Section {
                inboxRows(for: viewModel.snoozedTodos, catalog: .snoozed)
            }
        }
    }

    @ViewBuilder
    private var completedContent: some View {
        if viewModel.completedTodos.isEmpty {
            Section {
                ContentUnavailableView(
                    "완료된 할 일이 없습니다",
                    systemImage: "checkmark.circle",
                    description: Text("완료한 수집함 할 일이 여기에 표시됩니다.")
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        } else {
            ageBucketSections(segment: .completed)
        }
    }

    @ViewBuilder
    private func ageBucketSections(segment: InboxSegment) -> some View {
        let catalog: RowCatalog = segment == .now ? .now : .completed

        let recentTodos = viewModel.displayedTodos(in: .recent, segment: segment)
        if !recentTodos.isEmpty {
            Section {
                inboxRows(for: recentTodos, catalog: catalog)
            }
        }

        ForEach(InboxAgeBucket.collapsibleCases) { bucket in
            let total: Int = {
                switch segment {
                case .now: return viewModel.nowTodos(in: bucket).count
                case .completed: return viewModel.completedTodos(in: bucket).count
                case .snoozed: return 0
                }
            }()
            if total > 0 {
                Section {
                    Button {
                        withAnimation { viewModel.toggleBucket(bucket, segment: segment) }
                    } label: {
                        InboxBucketHeader(
                            title: bucket.headerTitle,
                            count: total,
                            isExpanded: viewModel.isBucketExpanded(bucket, segment: segment)
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 20, leading: 24, bottom: 8, trailing: 24))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    if viewModel.isBucketExpanded(bucket, segment: segment) {
                        inboxRows(
                            for: viewModel.displayedTodos(in: bucket, segment: segment),
                            catalog: catalog
                        )
                        let remaining = viewModel.remainingCount(in: bucket, segment: segment)
                        if remaining > 0 {
                            Button {
                                withAnimation { viewModel.loadMore(in: bucket, segment: segment) }
                            } label: {
                                Text("더보기")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                }
            }
        }
    }

    private enum RowCatalog {
        case now
        case snoozed
        case completed
    }

    @ViewBuilder
    private func inboxRows(for todos: [Todo], catalog: RowCatalog) -> some View {
        ForEach(todos) { todo in
            InboxInteractiveRow(
                todo: todo,
                showsSnoozeCaption: catalog == .snoozed,
                isInlineEditing: catalog == .now && inlineEditingTodoId == todo.id,
                allowsInlineEdit: catalog == .now,
                leadingActions: leadingActions(for: catalog),
                trailingActions: trailingActions(for: catalog),
                contextActions: contextActions(for: catalog),
                onCheckboxTap: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.toggleTodo(todo)
                    }
                    hapticSuccessTrigger.toggle()
                },
                onStartInlineEdit: {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                    finishAddingIfNeeded()
                    inlineEditingTodoId = todo.id
                },
                onCommitInlineEdit: { draft in commitInlineTitleEdit(todo: todo, draft: draft) },
                onOpenDetailFromInline: { draft in openDetailFromInline(todo: todo, draft: draft) },
                onSnoozedRowTap: catalog == .snoozed ? { snoozedActionTodo = todo } : nil,
                onAction: { performRowAction($0, for: todo) }
            )
            .id(todo.id)
            .listRowInsets(EdgeInsets(top: 3, leading: 24, bottom: 3, trailing: 24))
            .listRowBackground(
                highlightedTodoId == todo.id
                    ? AppTheme.shared.accent.opacity(0.14)
                    : Color.clear
            )
            .listRowSeparator(.hidden)
        }
        .animation(.easeInOut(duration: 0.3), value: todos.map(\.id))
    }

    private func leadingActions(for catalog: RowCatalog) -> [InboxRowAction] {
        switch catalog {
        case .now: return InboxRowActionCatalog.nowLeadingActions()
        case .snoozed: return InboxRowActionCatalog.snoozedLeadingActions()
        case .completed: return []
        }
    }

    private func trailingActions(for catalog: RowCatalog) -> [InboxRowAction] {
        switch catalog {
        case .now: return InboxRowActionCatalog.nowTrailingActions()
        case .snoozed: return InboxRowActionCatalog.snoozedTrailingActions()
        case .completed: return InboxRowActionCatalog.completedTrailingActions()
        }
    }

    private func contextActions(for catalog: RowCatalog) -> [InboxRowAction] {
        switch catalog {
        case .now: return InboxRowActionCatalog.nowContextActions()
        case .snoozed: return InboxRowActionCatalog.snoozedContextActions()
        case .completed: return InboxRowActionCatalog.completedContextActions()
        }
    }

    private var customSnoozePickerSheet: some View {
        @Bindable var vm = viewModel
        return NavigationStack {
            DatePicker(
                "다시 볼 날짜",
                selection: $vm.customSnoozeDate,
                in: Calendar.current.startOfDay(for: .now)...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(AppTheme.shared.accent)
            .environment(\.calendar, AppCalendar.localized)
            .padding(.horizontal)
            .navigationTitle("직접 날짜 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { viewModel.cancelSnoozeSheet() }
                        .toolbarSecondaryActionStyle()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") {
                        viewModel.confirmCustomSnooze()
                        hapticSuccessTrigger.toggle()
                    }
                    .toolbarPrimaryActionStyle()
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func startHighlightIfNeeded(proxy: ScrollViewProxy) {
        guard !didConsumeHighlight, let todoId = highlightTodoId else { return }
        didConsumeHighlight = true
        guard viewModel.revealTodoForNavigation(todoId) else { return }
        highlightedTodoId = todoId
        highlightScrollTask?.cancel()
        highlightScrollTask = Task { @MainActor in
            for _ in 0..<25 {
                if Task.isCancelled { return }
                if viewModel.isTodoVisibleInCurrentList(todoId) {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(todoId, anchor: .center)
                    }
                    try? await Task.sleep(for: .seconds(1.2))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut(duration: 0.35)) {
                        if highlightedTodoId == todoId {
                            highlightedTodoId = nil
                        }
                    }
                    return
                }
                try? await Task.sleep(for: .milliseconds(120))
            }
            if highlightedTodoId == todoId {
                highlightedTodoId = nil
            }
        }
    }

    private func performRowAction(_ kind: InboxRowActionKind, for todo: Todo) {
        switch kind {
        case .edit:
            editingTodo = todo
            hapticImpactTrigger.toggle()
        case .moveToToday:
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.moveToToday(todo)
            }
            hapticSuccessTrigger.toggle()
        case .assignDate:
            changingDateTodo = todo
        case .snooze:
            viewModel.requestSnooze(todo)
        case .bumpToRecent:
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.bumpToRecent(todo)
            }
            hapticSuccessTrigger.toggle()
        case .clearSnooze:
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.clearSnooze(todo)
            }
            hapticSuccessTrigger.toggle()
        case .uncomplete:
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.uncompleteTodo(todo)
            }
            hapticSuccessTrigger.toggle()
        case .delete:
            viewModel.requestDelete(todo)
            hapticWarningTrigger.toggle()
        }
    }

    private func commitInlineTitleEdit(todo: Todo, draft: String) {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != todo.title {
            viewModel.updateTodoTitle(todo, title: trimmed)
        }
        if inlineEditingTodoId == todo.id {
            inlineEditingTodoId = nil
        }
    }

    /// 포커스 잔류·세그먼트 전환·시트 닫기 전에 인라인 추가/수정을 커밋한다.
    private func resignAndFinishInlineInputs() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        finishAddingIfNeeded()
        inlineEditingTodoId = nil
    }

    /// AddRow.onDismiss와 동일: 공백만이면 저장하지 않고 입력만 종료.
    private func finishAddingIfNeeded() {
        guard isAddingTodo else { return }
        let trimmed = newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            viewModel.addInboxTodo(title: trimmed)
            newTodoTitle = ""
            hapticSuccessTrigger.toggle()
        } else {
            newTodoTitle = ""
        }
        isAddingTodo = false
    }

    private func openDetailFromInline(todo: Todo, draft: String) {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        var toEdit = todo
        if !trimmed.isEmpty {
            toEdit.title = trimmed
            if trimmed != todo.title {
                viewModel.updateTodoTitle(todo, title: trimmed)
            }
        }
        inlineEditingTodoId = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        editingTodo = toEdit
        hapticImpactTrigger.toggle()
    }
}

// MARK: - Bucket header

private struct InboxBucketHeader: View {
    let title: String
    let count: Int
    let isExpanded: Bool

    private var checkboxColumnWidth: CGFloat {
        UIFont.preferredFont(forTextStyle: .title3).lineHeight
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: checkboxColumnWidth, alignment: .center)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
            Text("\(title) (\(count))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .accessibilityLabel("\(title), \(count)")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Interactive Row

private struct InboxInteractiveRow: View {
    let todo: Todo
    let showsSnoozeCaption: Bool
    let isInlineEditing: Bool
    let allowsInlineEdit: Bool
    let leadingActions: [InboxRowAction]
    let trailingActions: [InboxRowAction]
    let contextActions: [InboxRowAction]
    let onCheckboxTap: () -> Void
    let onStartInlineEdit: () -> Void
    let onCommitInlineEdit: (String) -> Void
    let onOpenDetailFromInline: (String) -> Void
    let onSnoozedRowTap: (() -> Void)?
    let onAction: (InboxRowActionKind) -> Void

    var body: some View {
        InboxTodoRow(
            todo: todo,
            showsSnoozeCaption: showsSnoozeCaption,
            isInlineEditing: isInlineEditing,
            allowsInlineEdit: allowsInlineEdit,
            onCheckboxTap: onCheckboxTap,
            onStartInlineEdit: onStartInlineEdit,
            onCommitInlineEdit: onCommitInlineEdit,
            onOpenDetailFromInline: onOpenDetailFromInline,
            onSnoozedRowTap: onSnoozedRowTap
        )
        .id(todo.id)
        .contentShape(Rectangle())
        .contextMenu {
            if !isInlineEditing {
                ForEach(contextActions) { action in
                    Button(role: action.isDestructive ? .destructive : nil) {
                        onAction(action.kind)
                    } label: {
                        Label(action.title, systemImage: action.systemImage)
                    }
                }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: !leadingActions.isEmpty) {
            ForEach(leadingActions) { action in
                Button {
                    onAction(action.kind)
                } label: {
                    Label(action.title, systemImage: action.systemImage)
                }
                .tint(action.tint)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            ForEach(trailingActions) { action in
                Button(role: action.isDestructive ? .destructive : nil) {
                    onAction(action.kind)
                } label: {
                    Label(action.title, systemImage: action.systemImage)
                }
                .labelStyle(.iconOnly)
                .tint(action.isDestructive ? nil : action.tint)
            }
        }
    }
}

// MARK: - Row

private struct InboxTodoRow: View {
    let todo: Todo
    let showsSnoozeCaption: Bool
    let isInlineEditing: Bool
    let allowsInlineEdit: Bool
    var onCheckboxTap: (() -> Void)? = nil
    var onStartInlineEdit: (() -> Void)? = nil
    var onCommitInlineEdit: ((String) -> Void)? = nil
    var onOpenDetailFromInline: ((String) -> Void)? = nil
    var onSnoozedRowTap: (() -> Void)? = nil

    private let completedCheckboxOpacity: Double = 0.55

    private var firstLineHeight: CGFloat {
        UIFont.preferredFont(forTextStyle: .body).lineHeight
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                onCheckboxTap?()
            } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(
                        todo.isCompleted
                        ? AppTheme.shared.accent.opacity(completedCheckboxOpacity)
                        : Color(.tertiaryLabel)
                    )
                    .frame(height: firstLineHeight)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "완료 토글"))

            VStack(alignment: .leading, spacing: 6) {
                if isInlineEditing {
                    InboxInlineTitleEditor(
                        initialTitle: todo.title,
                        onCommit: { onCommitInlineEdit?($0) },
                        onOpenDetail: { onOpenDetailFromInline?($0) }
                    )
                } else {
                    Text(todo.title)
                        .font(.body)
                        .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                        .strikethrough(todo.isCompleted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if allowsInlineEdit {
                                onStartInlineEdit?()
                            } else {
                                onSnoozedRowTap?()
                            }
                        }
                }

                if showsSnoozeCaption, let until = todo.snoozedUntil {
                    Text(snoozeCaption(until))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let memo = todo.memo, !memo.isEmpty {
                    Text(memo)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
    }

    private func snoozeCaption(_ until: Date) -> String {
        let formatted = until.formatted(.dateTime.month().day())
        return String(localized: "\(formatted)에 다시 보기")
    }
}

// MARK: - Inline title

private struct InboxInlineTitleEditor: View {
    @State private var draftTitle: String
    @State private var didCommit = false
    let onCommit: (String) -> Void
    let onOpenDetail: (String) -> Void

    init(
        initialTitle: String,
        onCommit: @escaping (String) -> Void,
        onOpenDetail: @escaping (String) -> Void
    ) {
        _draftTitle = State(initialValue: initialTitle)
        self.onCommit = onCommit
        self.onOpenDetail = onOpenDetail
    }

    private var firstLineHeight: CGFloat {
        UIFont.preferredFont(forTextStyle: .body).lineHeight
    }

    var body: some View {
        AutoFocusTextField(
            text: $draftTitle,
            placeholder: "",
            textStyle: .body,
            contentVerticalAlignment: .center,
            onReturn: {
                commitOnce()
                return false
            },
            onDismiss: {
                commitOnce()
            },
            keyboardAccessoryTitle: String(localized: "자세히"),
            onKeyboardAccessory: {
                openDetailOnce()
            }
        )
        .frame(maxWidth: .infinity, minHeight: firstLineHeight, maxHeight: firstLineHeight, alignment: .leading)
    }

    private func commitOnce() {
        guard !didCommit else { return }
        didCommit = true
        onCommit(draftTitle)
    }

    private func openDetailOnce() {
        guard !didCommit else { return }
        didCommit = true
        onOpenDetail(draftTitle)
    }
}

// MARK: - Add row

private struct InboxAddRow: View {
    @Binding var newTodoTitle: String
    @Binding var isAdding: Bool
    let onAdd: () -> Void
    @State private var focusEpoch = UUID()
    @State private var didFinish = false

    var body: some View {
        if isAdding {
            HStack(spacing: 8) {
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundStyle(Color(.tertiaryLabel))
                AutoFocusTextField(
                    text: $newTodoTitle,
                    placeholder: String(localized: "새 투두"),
                    textStyle: .body,
                    onReturn: {
                        let trimmed = newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty { return false }
                        finishAdding(save: true)
                        return true
                    },
                    onDismiss: {
                        let trimmed = newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        finishAdding(save: !trimmed.isEmpty)
                    }
                )
                .id(focusEpoch)
                .frame(height: 36)
            }
        } else {
            Button {
                didFinish = false
                focusEpoch = UUID()
                isAdding = true
            } label: {
                HStack(spacing: 8) {
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

    private func finishAdding(save: Bool) {
        guard !didFinish else { return }
        didFinish = true
        if save {
            onAdd()
        }
        isAdding = false
    }
}
