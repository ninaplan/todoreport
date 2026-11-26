import Foundation
import Observation

@Observable
final class TimeBlockViewModel {
    private let service = TimeBlockService.shared

    private(set) var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    private(set) var entries: [TimeBlockEntry] = []
    /// `entries`가 어느 날짜 것인지. 바뀌는 순간 화면이 좌우로 슬라이드된다 (새 블록이 다 불러와진 뒤라 깜박임 없음)
    private(set) var entriesDay: Date = Calendar.current.startOfDay(for: .now)
    private(set) var snapMinutes: Int
    /// 일과 시간 (플래너별). 화면에 그릴 시간 범위이자 블록을 만들 수 있는 범위
    private(set) var dayRange: TimeBlockDayRange
    private(set) var showDayRangeEditor = false
    /// 메뉴 「카테고리 색상 보기」. 끄면 모든 블록이 흰 블록.
    private(set) var showsCategoryColor: Bool
    /// 메뉴 「새 블록 기본 알림」 시작·종료 (새 블록 기본값. 이미 있는 블록은 건드리지 않음)
    private(set) var isStartAlarmEnabled: Bool = TimeBlockNotificationManager.shared.isGloballyEnabled
    private(set) var isEndAlarmEnabled: Bool = TimeBlockNotificationManager.shared.isEndGloballyEnabled

    // 이동 (블록 길게 누른 뒤 드래그)
    private(set) var movingBlockId: String?
    private(set) var moveDraftStartMinute: Int?
    private var moveOriginalStartMinute: Int?
    /// 겹치는 자리에 놓아 원래 자리로 돌아갈 때 증가 (진동용)
    private(set) var moveRejectedToken = 0

    // 길이 조절 (블록 아래 손잡이 드래그)
    private(set) var resizingBlockId: String?
    private(set) var resizeDraftEndMinute: Int?
    private var resizeOriginalEndMinute: Int?

    // 빈 칸 → 할 일 고르기 시트
    private(set) var pickerRequest: TimeBlockSlotRequest?
    private(set) var todoOptions: [TimeBlockTodoOption] = []

    // 블록 탭 → 시간 편집 시트
    private(set) var editingEntry: TimeBlockEntry?

    // 진행 중 블록 완료 → 「종료 시각을 지금으로 바꿀까요?」
    private(set) var showFinishEarlyAlert = false
    private(set) var finishEarlyEntry: TimeBlockEntry?
    /// 확인 창에 보여 줄 지금 시각 (창을 연 순간 기준)
    private(set) var finishEarlyTime: Date = .now

    /// 블록의 메모·「+ 메모 추가」로 팝업을 열었는지 → 메모 칸에 바로 커서
    private(set) var editorFocusesMemo = false

    /// 1분 = 몇 pt (두 손가락으로 오므리거나 벌려 바꿈, 기기에 저장). 기본 1.1 = 1시간 66pt
    private(set) var pointsPerMinute: CGFloat

    // 오류 알림
    private(set) var showErrorAlert = false
    private(set) var errorMessage = ""

    // 무료 사용자 결제 화면
    private(set) var showPaywall = false
    private var hasConfirmedSubscription = false

    init() {
        let stored = UserDefaults.standard.integer(forKey: TimeBlockLayout.snapMinutesKey)
        snapMinutes = TimeBlockLayout.snapOptions.contains(stored) ? stored : TimeBlockLayout.defaultSnapMinutes
        let range = TimeBlockDayRangeStore.load(plannerId: PlannerService.shared.selectedPlanner?.id)
        dayRange = range
        // 범위가 새벽까지면 새벽엔 전날 화면이 오늘
        let today = range.logicalDay(for: .now)
        selectedDate = today
        entriesDay = today
        let defaults = UserDefaults.standard
        let storedScale = defaults.double(forKey: TimeBlockLayout.pointsPerMinuteKey)
        pointsPerMinute = storedScale > 0
            ? TimeBlockLayout.clampPointsPerMinute(CGFloat(storedScale))
            : TimeBlockLayout.pointsPerMinute
        showsCategoryColor = defaults.object(forKey: TimeBlockLayout.showsCategoryColorKey) == nil
            ? true
            : defaults.bool(forKey: TimeBlockLayout.showsCategoryColorKey)
    }

    /// 길이 조절·이동 중에는 바깥 스크롤을 멈춘다
    var isDraggingBlock: Bool { resizingBlockId != nil || movingBlockId != nil }

    // MARK: - 확대·축소 (시간 높이)

    /// 핀치를 시작하면 두 손가락에 같이 걸린 블록 이동·길이 조절은 저장하지 않고 취소
    /// (끝 신호 없이 남으면 스크롤이 계속 막힌다)
    func cancelBlockDrags() {
        clearMove()
        clearResize()
    }

    /// 핀치 중에는 화면만 바꾸고, 끝나면 `commitPointsPerMinute`로 저장
    func setPointsPerMinute(_ value: CGFloat) {
        let clamped = TimeBlockLayout.clampPointsPerMinute(value)
        guard abs(clamped - pointsPerMinute) > 0.001 else { return }
        pointsPerMinute = clamped
    }

    func commitPointsPerMinute() {
        UserDefaults.standard.set(Double(pointsPerMinute), forKey: TimeBlockLayout.pointsPerMinuteKey)
    }

    /// 메뉴 「하루 한눈에 보기」: 일과 시간 전체가 화면 높이에 들어가게
    func fitDayToHeight(_ height: CGFloat) {
        let usable = height - TimeBlockLayout.verticalPadding * 2
        guard usable > 0, dayRange.durationMinutes > 0 else { return }
        setPointsPerMinute(usable / CGFloat(dayRange.durationMinutes))
        commitPointsPerMinute()
    }

    /// 메뉴 「기본 크기로」
    func resetPointsPerMinute() {
        setPointsPerMinute(TimeBlockLayout.pointsPerMinute)
        commitPointsPerMinute()
    }

    var isDefaultScale: Bool { abs(pointsPerMinute - TimeBlockLayout.pointsPerMinute) < 0.01 }

    /// 타임블록의 오늘 (일과 시간이 새벽까지면 새벽엔 전날). 투두 탭의 오늘과는 별개
    var todayDate: Date { dayRange.logicalDay(for: .now) }

    var isToday: Bool { selectedDate == todayDate }

    /// 범위와 겹치는 블록만 화면에 그린다
    var visibleEntries: [TimeBlockEntry] {
        entries.filter { dayRange.intersects(start: $0.block.startMinute, end: $0.block.endMinute) }
    }

    /// 일과 시간 밖으로 (일부라도) 나간 블록 수 → 「범위 밖 블록 N개」
    var outOfRangeCount: Int {
        entries.filter { !dayRange.contains(start: $0.block.startMinute, end: $0.block.endMinute) }.count
    }

    // MARK: - 로드

    func onAppear() async {
        // 알림 규칙 변경(메뉴 = 새 블록 기본값) 전에 만든 블록을 한 번 정리
        service.migrateAlarmFlagsIfNeeded()
        await confirmSubscriptionIfNeeded()
        await reload()
    }

    func reload() async {
        refreshDayRange()
        let day = selectedDate
        let loaded = await service.fetchEntries(for: day)
        // 빠르게 날짜를 넘기면 늦게 끝난 옛 날짜 결과가 덮어쓰지 않게
        guard day == selectedDate else { return }
        entries = loaded
        entriesDay = day
    }

    /// 앱 시작 직후엔 `isPro`가 아직 false일 수 있어 1회 확인 (Pro 사용자가 잠금 화면을 잠깐 보는 것 방지)
    private func confirmSubscriptionIfNeeded() async {
        guard !hasConfirmedSubscription else { return }
        hasConfirmedSubscription = true
        guard !SubscriptionManager.shared.isPro else { return }
        await SubscriptionManager.shared.updatePurchasedProducts()
    }

    // MARK: - 날짜 이동

    func goToPreviousDay() { moveDay(by: -1) }
    func goToNextDay() { moveDay(by: 1) }

    func goToToday() {
        selectedDate = todayDate
        Task { await reload() }
    }

    func selectDate(_ date: Date) {
        let day = Calendar.current.startOfDay(for: date)
        guard day != selectedDate else { return }
        selectedDate = day
        Task { await reload() }
    }

    /// 주간 달력에서 n주 넘기기 (요일은 그대로)
    func shiftWeeks(by weeks: Int) {
        guard weeks != 0 else { return }
        moveDay(by: weeks * 7)
    }

    /// 상단 주간 달력에 보여줄 7일 (설정의 시작 요일 기준)
    var weekDays: [Date] {
        let calendar = AppCalendar.localized
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else { return [selectedDate] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    private func moveDay(by value: Int) {
        guard let next = Calendar.current.date(byAdding: .day, value: value, to: selectedDate) else { return }
        selectedDate = Calendar.current.startOfDay(for: next)
        Task { await reload() }
    }

    // MARK: - 일과 시간

    func openDayRangeEditor() {
        showDayRangeEditor = true
    }

    func dismissDayRangeEditor() {
        showDayRangeEditor = false
    }

    func saveDayRange(_ range: TimeBlockDayRange) {
        guard range.isValid else { return }
        TimeBlockDayRangeStore.save(range, plannerId: PlannerService.shared.selectedPlanner?.id)
        dayRange = range
        showDayRangeEditor = false
    }

    /// 플래너가 바뀌었을 수 있어 불러올 때마다 확인 (같으면 그대로 → 화면 다시 그리지 않음)
    private func refreshDayRange() {
        let range = TimeBlockDayRangeStore.load(plannerId: PlannerService.shared.selectedPlanner?.id)
        guard range != dayRange else { return }
        dayRange = range
    }

    // MARK: - 스냅 단위

    func setSnapMinutes(_ minutes: Int) {
        guard TimeBlockLayout.snapOptions.contains(minutes) else { return }
        snapMinutes = minutes
        UserDefaults.standard.set(minutes, forKey: TimeBlockLayout.snapMinutesKey)
    }

    func setEndAlarmEnabled(_ enabled: Bool) {
        isEndAlarmEnabled = enabled
        TimeBlockNotificationManager.shared.setEndGloballyEnabled(enabled)
        if enabled {
            TodoNotificationManager.shared.requestPermission()
        }
    }

    func setStartAlarmEnabled(_ enabled: Bool) {
        isStartAlarmEnabled = enabled
        TimeBlockNotificationManager.shared.setGloballyEnabled(enabled)
        if enabled {
            TodoNotificationManager.shared.requestPermission()
        }
    }

    func setShowsCategoryColor(_ shows: Bool) {
        showsCategoryColor = shows
        UserDefaults.standard.set(shows, forKey: TimeBlockLayout.showsCategoryColorKey)
    }

    // MARK: - 빈 칸 탭 → 고르기

    func requestSlot(atMinute minute: Int) {
        guard let range = freeRange(startingNear: minute) else { return }
        pickerRequest = TimeBlockSlotRequest(day: selectedDate, startMinute: range.start, endMinute: range.end)
        todoOptions = []
        Task { todoOptions = await service.fetchTodoOptions(for: selectedDate) }
    }

    func dismissPicker() {
        pickerRequest = nil
        todoOptions = []
    }

    func placeTodo(_ option: TimeBlockTodoOption) {
        guard let request = pickerRequest else { return }
        do {
            try service.createBlock(
                todoId: option.id,
                day: request.day,
                startMinute: request.startMinute,
                endMinute: request.endMinute
            )
            dismissPicker()
            Task { await reload() }
        } catch {
            presentError(error)
        }
    }

    func createTodoInSlot(title: String) {
        guard let request = pickerRequest else { return }
        Task {
            do {
                try await service.createTodoAndBlock(
                    title: title,
                    day: request.day,
                    startMinute: request.startMinute,
                    endMinute: request.endMinute
                )
                dismissPicker()
                await reload()
            } catch {
                presentError(error)
            }
        }
    }

    /// 누른 위치를 스냅 단위로 내림 → 앞 블록 끝·다음 블록 시작 사이로 맞춘 빈 구간
    private func freeRange(startingNear minute: Int) -> (start: Int, end: Int)? {
        var start = dayRange.clamp(TimeBlockLayout.snapDown(minute, unit: snapMinutes))
        // 블록 위를 누른 경우는 블록 자체가 탭을 받으므로 여기서는 무시
        if entries.contains(where: { $0.block.startMinute <= minute && minute < $0.block.endMinute }) {
            return nil
        }
        if let previous = entries.last(where: { $0.block.startMinute <= start && $0.block.endMinute > start }) {
            start = previous.block.endMinute
        }
        let limit = entries
            .map(\.block.startMinute)
            .filter { $0 >= start }
            .min() ?? dayRange.endMinute
        let duration = max(TimeBlockLayout.defaultDurationMinutes, snapMinutes)
        let end = min(start + duration, limit, dayRange.endMinute)
        guard end - start >= 5 else { return nil }
        return (start, end)
    }

    // MARK: - 길이 조절

    func beginResize(_ entry: TimeBlockEntry) {
        guard resizingBlockId == nil, movingBlockId == nil else { return }
        resizingBlockId = entry.id
        resizeOriginalEndMinute = entry.block.endMinute
        resizeDraftEndMinute = entry.block.endMinute
    }

    func updateResize(translationHeight: CGFloat) {
        guard let id = resizingBlockId,
              let original = resizeOriginalEndMinute,
              let entry = entries.first(where: { $0.id == id }) else { return }
        let deltaMinutes = Int((translationHeight / pointsPerMinute).rounded())
        let snapped = TimeBlockLayout.snapNearest(original + deltaMinutes, unit: snapMinutes)
        let minimumEnd = entry.block.startMinute + min(snapMinutes, 15)
        let maximumEnd = min(nextBlockStart(after: entry) ?? dayRange.endMinute, dayRange.endMinute)
        resizeDraftEndMinute = min(max(snapped, minimumEnd), maximumEnd)
    }

    func endResize() {
        guard let id = resizingBlockId,
              let newEnd = resizeDraftEndMinute,
              let entry = entries.first(where: { $0.id == id }) else {
            clearResize()
            return
        }
        defer { clearResize() }
        guard newEnd != entry.block.endMinute else { return }
        do {
            try service.updateBlockTime(id: id, startMinute: entry.block.startMinute, endMinute: newEnd)
            applyLocalTime(id: id, start: entry.block.startMinute, end: newEnd)
            registerUndoForTimeChange(entry)
        } catch {
            presentError(error)
        }
    }

    /// 드래그 중 화면에 쓸 시작 분 (이동 중이 아니면 원래 값)
    func displayStartMinute(for entry: TimeBlockEntry) -> Int {
        if entry.id == movingBlockId, let draft = moveDraftStartMinute { return draft }
        return entry.block.startMinute
    }

    /// 드래그 중 화면에 쓸 끝 분 (길이 조절·이동 중이 아니면 원래 값)
    func displayEndMinute(for entry: TimeBlockEntry) -> Int {
        if entry.id == resizingBlockId, let draft = resizeDraftEndMinute { return draft }
        if entry.id == movingBlockId, let draft = moveDraftStartMinute {
            return draft + entry.block.durationMinutes
        }
        return entry.block.endMinute
    }

    // MARK: - 이동 (길게 누른 뒤 드래그)

    func beginMove(_ entry: TimeBlockEntry) {
        // 이전 이동이 끝 신호 없이 남아 있으면(블록이 떠 있는 채로 멈춤) 먼저 정리
        if movingBlockId != nil { clearMove() }
        guard resizingBlockId == nil else { return }
        movingBlockId = entry.id
        moveOriginalStartMinute = entry.block.startMinute
        moveDraftStartMinute = entry.block.startMinute
    }

    /// 다른 블록 위로 지나갈 수는 있다. 겹침 검사는 놓을 때만 한다.
    func updateMove(translationHeight: CGFloat) {
        guard let id = movingBlockId,
              let original = moveOriginalStartMinute,
              let entry = entries.first(where: { $0.id == id }) else { return }
        let deltaMinutes = Int((translationHeight / pointsPerMinute).rounded())
        let snapped = TimeBlockLayout.snapNearest(original + deltaMinutes, unit: snapMinutes)
        // 일과 시간 안에서만 움직인다
        let earliestStart = dayRange.startMinute
        let latestStart = max(dayRange.endMinute - entry.block.durationMinutes, earliestStart)
        moveDraftStartMinute = min(max(snapped, earliestStart), latestStart)
    }

    func endMove() {
        guard let id = movingBlockId,
              let newStart = moveDraftStartMinute,
              let entry = entries.first(where: { $0.id == id }) else {
            clearMove()
            return
        }
        let newEnd = newStart + entry.block.durationMinutes
        guard newStart != entry.block.startMinute else {
            clearMove()
            return
        }
        let overlapsOther = entries.contains {
            $0.id != id && $0.block.overlaps(start: newStart, end: newEnd)
        }
        guard !overlapsOther else {
            moveRejectedToken += 1
            clearMove()
            return
        }
        do {
            try service.updateBlockTime(id: id, startMinute: newStart, endMinute: newEnd)
            applyLocalTime(id: id, start: newStart, end: newEnd)
            registerUndoForTimeChange(entry)
        } catch {
            presentError(error)
        }
        clearMove()
    }

    private func clearMove() {
        movingBlockId = nil
        moveDraftStartMinute = nil
        moveOriginalStartMinute = nil
    }

    private func clearResize() {
        resizingBlockId = nil
        resizeDraftEndMinute = nil
        resizeOriginalEndMinute = nil
    }

    private func nextBlockStart(after entry: TimeBlockEntry) -> Int? {
        entries
            .filter { $0.id != entry.id && $0.block.startMinute >= entry.block.endMinute }
            .map(\.block.startMinute)
            .min()
    }

    private func applyLocalTime(id: String, start: Int, end: Int) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        let old = entries[index]
        var block = old.block
        block.startMinute = start
        block.endMinute = end
        entries[index] = TimeBlockEntry(
            block: block,
            title: old.title,
            isCompleted: old.isCompleted,
            categoryColorHex: old.categoryColorHex,
            categoryIcon: old.categoryIcon,
            categoryId: old.categoryId,
            memo: old.memo
        )
    }

    // MARK: - 완료 (블록 체크 원)

    func toggleCompletion(_ entry: TimeBlockEntry) {
        // 진행 중인 블록을 완료하면 일찍 끝난 것 → 종료를 지금으로 줄일지 묻는다
        let now = Date.now
        if entry.status(now: now) == .current {
            finishEarlyEntry = entry
            finishEarlyTime = now
            showFinishEarlyAlert = true
            return
        }
        completeBlock(entry)
    }

    /// 「지금으로 바꾸기」: 종료를 지금(분 단위)으로 줄이고 완료
    func confirmFinishEarly() {
        guard let entry = finishEarlyEntry else { return }
        let now = finishEarlyTime
        clearFinishEarly()
        Task {
            do {
                try await service.finishBlockEarly(blockId: entry.id, now: now)
                await reload()
            } catch {
                presentError(error)
            }
        }
    }

    /// 「그대로 두기」: 길이는 그대로 두고 완료만
    func cancelFinishEarly() {
        guard let entry = finishEarlyEntry else {
            clearFinishEarly()
            return
        }
        clearFinishEarly()
        completeBlock(entry)
    }

    /// 창이 닫힐 때 (버튼 동작과 순서가 바뀌어도 안전하게 창만 닫고, 고른 블록은 버튼 동작이 쓰고 비운다)
    func dismissFinishEarlyAlert() {
        showFinishEarlyAlert = false
    }

    private func clearFinishEarly() {
        showFinishEarlyAlert = false
        finishEarlyEntry = nil
    }

    private func completeBlock(_ entry: TimeBlockEntry) {
        Task {
            do {
                try await service.toggleBlockCompletion(blockId: entry.id)
                await reload()
            } catch {
                presentError(error)
            }
        }
    }

    // MARK: - 편집 시트

    func openEditor(_ entry: TimeBlockEntry, focusesMemo: Bool = false) {
        editorFocusesMemo = focusesMemo
        editingEntry = entry
    }

    /// 편집 팝업의 카테고리 목록 (이 플래너의 보이는 카테고리 + 지금 할 일의 카테고리가 숨김이면 그것도)
    var editableCategories: [Category] {
        let service = CategoryService.shared
        var list = service.activeCategories
        if let currentId = editingEntry?.categoryId,
           !list.contains(where: { $0.id == currentId }),
           let current = service.store.first(where: { $0.id == currentId }) {
            list.append(current)
        }
        return list
    }

    func dismissEditor() {
        editingEntry = nil
    }

    func saveEdit(_ result: TimeBlockEditResult) {
        guard let entry = editingEntry else { return }
        // 시각만 보고 일과 시간 화면의 분으로 바꾼다 (범위가 새벽까지면 01:00 = 다음 날 01:00)
        let startMinute = dayRange.pageMinute(of: result.start)
        let endMinute = dayRange.pageEndMinute(of: result.end, start: startMinute)
        do {
            try service.updateBlockTime(id: entry.id, startMinute: startMinute, endMinute: endMinute)
            try service.setAlarms(id: entry.id, startEnabled: result.startAlarm, endEnabled: result.endAlarm)
            dismissEditor()
        } catch {
            presentError(error)
            return
        }
        let oldMemo = (entry.memo ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let todoChanged = result.title != entry.title
            || result.categoryId != entry.categoryId
            || result.memo != oldMemo
        let todoId = entry.block.todoId
        Task {
            if todoChanged {
                do {
                    try await service.updateTodoDetails(
                        todoId: todoId,
                        title: result.title,
                        categoryId: result.categoryId,
                        memo: result.memo
                    )
                } catch {
                    presentError(error)
                }
            }
            await reload()
        }
    }

    func deleteEditingBlock() {
        guard let entry = editingEntry else { return }
        let snapshot = service.blockSnapshot(id: entry.id)
        do {
            try service.deleteBlock(id: entry.id)
            dismissEditor()
            entries.removeAll { $0.id == entry.id }
            if let snapshot {
                registerUndoForBlockDelete(snapshot, title: entry.title)
            }
        } catch {
            presentError(error)
        }
    }

    /// 팝업 「할 일까지 삭제」
    func deleteEditingTodo(_ scope: TimeBlockTodoDeleteScope) {
        guard let entry = editingEntry else { return }
        let todoId = entry.block.todoId
        if let todo = TodoService.shared.todoSnapshot(id: todoId) {
            if scope == .allFuture, let seriesId = todo.recurrenceId, let date = todo.date {
                registerUndoForSeriesDelete(seriesId: seriesId, from: date, title: todo.title)
            } else {
                registerUndoForTodoDelete(todo, blocks: service.blockSnapshots(ofTodo: todoId))
            }
        }
        dismissEditor()
        entries.removeAll { $0.block.todoId == todoId }
        Task {
            do {
                try await service.deleteTodo(todoId: todoId, scope: scope)
            } catch {
                presentError(error)
            }
            await reload()
        }
    }

    // MARK: - 실행 취소

    /// 크기 조절·이동 → 바꾸기 전 시각으로 (흔들기만, 삭제가 아니라 배너 없음). 알림도 `updateBlockTime`이 다시 맞춘다
    private func registerUndoForTimeChange(_ before: TimeBlockEntry) {
        let id = before.id
        let start = before.block.startMinute
        let end = before.block.endMinute
        AppUndoCenter.shared.register(
            confirmTitle: String(localized: "'\(before.title)' 블록 시간을 원래대로 되돌릴까요?")
        ) { [weak self] in
            do {
                try TimeBlockService.shared.updateBlockTime(id: id, startMinute: start, endMinute: end)
            } catch {
                self?.presentError(error)
            }
            await self?.reload()
        }
    }

    private func registerUndoForBlockDelete(_ snapshot: TimeBlockSnapshot, title: String) {
        AppUndoCenter.shared.register(
            confirmTitle: String(localized: "'\(title)' 블록 삭제를 되돌릴까요?"),
            bannerMessage: String(localized: "블록을 삭제했습니다."),
            bannerScope: .timeBlock
        ) { [weak self] in
            do {
                try TimeBlockService.shared.restoreBlocks([snapshot])
            } catch {
                self?.presentError(error)
            }
            await self?.reload()
        }
    }

    /// 「이후 반복 모두 삭제」 — 반복 끝 날짜와 지워질 할 일들, 그 할 일들의 블록을 남겨 둔다
    private func registerUndoForSeriesDelete(seriesId: String, from date: Date, title: String) {
        guard let snapshot = RecurringTodoManager.shared.capSnapshot(seriesId: seriesId, from: date) else { return }
        let blocks = snapshot.todos.flatMap { service.blockSnapshots(ofTodo: $0.id) }
        AppUndoCenter.shared.register(
            confirmTitle: String(localized: "'\(title)' 이후 반복 삭제를 되돌릴까요?"),
            bannerMessage: String(localized: "할 일을 삭제했습니다."),
            bannerScope: .timeBlock
        ) { [weak self] in
            await TimeBlockService.shared.restoreSeriesDelete(snapshot, blocks: blocks)
            await self?.reload()
        }
    }

    private func registerUndoForTodoDelete(_ todo: Todo, blocks: [TimeBlockSnapshot]) {
        AppUndoCenter.shared.register(
            confirmTitle: String(localized: "'\(todo.title)' 삭제를 되돌릴까요?"),
            bannerMessage: String(localized: "할 일을 삭제했습니다."),
            bannerScope: .timeBlock
        ) { [weak self] in
            do {
                try await TimeBlockService.shared.restoreDeletedTodo(todo, blocks: blocks)
            } catch {
                self?.presentError(error)
            }
            await self?.reload()
        }
    }

    // MARK: - 결제 화면

    func requestPaywall() {
        showPaywall = true
    }

    func dismissPaywall() {
        showPaywall = false
    }

    // MARK: - 오류 알림

    func dismissErrorAlert() {
        showErrorAlert = false
        errorMessage = ""
    }

    private func presentError(_ error: Error) {
        switch error as? TimeBlockError {
        case .overlap?:
            errorMessage = String(localized: "다른 블록과 시간이 겹칩니다.")
        case .invalidRange?:
            errorMessage = String(localized: "끝나는 시각은 시작 시각보다 늦어야 합니다.")
        case .readOnlyPlanner?:
            errorMessage = String(localized: "읽기 전용 플래너에는 할 일을 추가할 수 없습니다.")
        case .saveFailed?, nil:
            errorMessage = String(localized: "저장하지 못했습니다. 다시 시도해 주세요.")
        }
        showErrorAlert = true
    }
}
