import Foundation
import Observation

@Observable
final class TimeBlockViewModel {
    private let service = TimeBlockService.shared

    private(set) var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    private(set) var entries: [TimeBlockEntry] = []
    private(set) var snapMinutes: Int
    /// 메뉴 「카테고리 색상 보기」. 끄면 모든 블록이 흰 블록.
    private(set) var showsCategoryColor: Bool

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
        let defaults = UserDefaults.standard
        showsCategoryColor = defaults.object(forKey: TimeBlockLayout.showsCategoryColorKey) == nil
            ? true
            : defaults.bool(forKey: TimeBlockLayout.showsCategoryColorKey)
    }

    /// 길이 조절·이동 중에는 바깥 스크롤을 멈춘다
    var isDraggingBlock: Bool { resizingBlockId != nil || movingBlockId != nil }

    var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }

    // MARK: - 로드

    func onAppear() async {
        await confirmSubscriptionIfNeeded()
        await reload()
    }

    func reload() async {
        entries = await service.fetchEntries(for: selectedDate)
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
        selectedDate = Calendar.current.startOfDay(for: .now)
        Task { await reload() }
    }

    private func moveDay(by value: Int) {
        guard let next = Calendar.current.date(byAdding: .day, value: value, to: selectedDate) else { return }
        selectedDate = Calendar.current.startOfDay(for: next)
        Task { await reload() }
    }

    // MARK: - 스냅 단위

    func setSnapMinutes(_ minutes: Int) {
        guard TimeBlockLayout.snapOptions.contains(minutes) else { return }
        snapMinutes = minutes
        UserDefaults.standard.set(minutes, forKey: TimeBlockLayout.snapMinutesKey)
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
        var start = TimeBlockLayout.snapDown(minute, unit: snapMinutes)
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
            .min() ?? TimeBlockLayout.minutesPerDay
        let duration = max(TimeBlockLayout.defaultDurationMinutes, snapMinutes)
        let end = min(start + duration, limit)
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
        let maximumEnd = nextBlockStart(after: entry) ?? TimeBlockLayout.minutesPerDay
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
        let latestStart = TimeBlockLayout.minutesPerDay - entry.block.durationMinutes
        moveDraftStartMinute = min(max(snapped, 0), latestStart)
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
            categoryColorHex: old.categoryColorHex
        )
    }

    // MARK: - 완료 (스와이프)

    func toggleCompletion(_ entry: TimeBlockEntry) {
        Task {
            do {
                try await service.toggleCompletion(todoId: entry.block.todoId)
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

    func saveEdit(start: Date, end: Date) {
        guard let entry = editingEntry else { return }
        let day = entry.block.day
        let startMinute = TimeBlockLayout.minute(of: start, day: day)
        let endMinute = TimeBlockLayout.minute(of: end, day: day)
        do {
            try service.updateBlockTime(id: entry.id, startMinute: startMinute, endMinute: endMinute)
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
