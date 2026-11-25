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
    /// 메뉴 「블록 시작 알림」·「블록 종료 알림」 (전체)
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
        showsCategoryColor = defaults.object(forKey: TimeBlockLayout.showsCategoryColorKey) == nil
            ? true
            : defaults.bool(forKey: TimeBlockLayout.showsCategoryColorKey)
    }

    /// 길이 조절·이동 중에는 바깥 스크롤을 멈춘다
    var isDraggingBlock: Bool { resizingBlockId != nil || movingBlockId != nil }

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
        service.resyncUpcomingAlarms()
    }

    func setStartAlarmEnabled(_ enabled: Bool) {
        isStartAlarmEnabled = enabled
        TimeBlockNotificationManager.shared.setGloballyEnabled(enabled)
        service.resyncUpcomingAlarms()
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
        let deltaMinutes = Int((translationHeight / TimeBlockLayout.pointsPerMinute).rounded())
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
        guard movingBlockId == nil, resizingBlockId == nil else { return }
        movingBlockId = entry.id
        moveOriginalStartMinute = entry.block.startMinute
        moveDraftStartMinute = entry.block.startMinute
    }

    /// 다른 블록 위로 지나갈 수는 있다. 겹침 검사는 놓을 때만 한다.
    func updateMove(translationHeight: CGFloat) {
        guard let id = movingBlockId,
              let original = moveOriginalStartMinute,
              let entry = entries.first(where: { $0.id == id }) else { return }
        let deltaMinutes = Int((translationHeight / TimeBlockLayout.pointsPerMinute).rounded())
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
            categoryIcon: old.categoryIcon
        )
    }

    // MARK: - 완료 (블록 체크 원)

    func toggleCompletion(_ entry: TimeBlockEntry) {
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

    func openEditor(_ entry: TimeBlockEntry) {
        editingEntry = entry
    }

    func dismissEditor() {
        editingEntry = nil
    }

    func saveEdit(start: Date, end: Date, startAlarm: Bool, endAlarm: Bool) {
        guard let entry = editingEntry else { return }
        // 시각만 보고 일과 시간 화면의 분으로 바꾼다 (범위가 새벽까지면 01:00 = 다음 날 01:00)
        let startMinute = dayRange.pageMinute(of: start)
        let endMinute = dayRange.pageEndMinute(of: end, start: startMinute)
        do {
            try service.updateBlockTime(id: entry.id, startMinute: startMinute, endMinute: endMinute)
            try service.setAlarms(id: entry.id, startEnabled: startAlarm, endEnabled: endAlarm)
            dismissEditor()
            Task { await reload() }
        } catch {
            presentError(error)
        }
    }

    func deleteEditingBlock() {
        guard let entry = editingEntry else { return }
        do {
            try service.deleteBlock(id: entry.id)
            dismissEditor()
            entries.removeAll { $0.id == entry.id }
        } catch {
            presentError(error)
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
