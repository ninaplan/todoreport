import Foundation
import SwiftData

@MainActor
final class RecurringTodoManager {
    static let shared = RecurringTodoManager()

    private init() {
        // 재설치 직후엔 iCloud 백업이 늦게 내려온다 → 도착하는 즉시 복원·따라잡기
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { _ in
            Task { @MainActor in
                await RecurringTodoManager.shared.materializeDue()
            }
        }
    }

    private var context: ModelContext { PersistenceController.shared.context }

    /// 시리즈를 만들고, 시작일이 규칙에 맞으면 그날의 할 일을 하나 생성한 뒤 놓친 날짜를 따라잡는다.
    func createSeries(
        title: String,
        memo: String?,
        categoryId: String?,
        plannerId: String?,
        originDate: Date,
        scheduledTime: Date?,
        alarmOffset: Int?,
        rule: RecurrenceRule,
        endDate: Date?,
        occurrenceLimit: Int?
    ) async throws -> Todo? {
        guard SubscriptionManager.shared.isPro else {
            AppLogger.shared.error("RecurringTodo", "Pro 구독 없이 시리즈 생성 시도")
            throw RecurringTodoError.requiresPro
        }
        guard let ruleData = try? JSONEncoder().encode(rule) else {
            AppLogger.shared.error("RecurringTodo", "RecurrenceRule 인코딩 실패")
            throw RecurringTodoError.ruleEncodingFailed
        }

        let cal = Calendar.current
        let originDay = cal.startOfDay(for: originDate)
        let series = RecurringSeries(
            plannerId: plannerId,
            title: title,
            memo: memo,
            categoryId: categoryId,
            scheduledTime: scheduledTime,
            alarmOffset: alarmOffset,
            ruleData: ruleData,
            originDate: originDay,
            endDate: endDate,
            occurrenceLimit: occurrenceLimit
        )
        context.insert(series)
        try context.save()

        var created: Todo?
        if rule.matches(date: originDay, origin: originDay) {
            created = try await saveOccurrence(of: series, on: originDay)
        }
        await materialize(series, through: Calendar.current.startOfDay(for: .now))
        RecurringSeriesBackupStore.shared.backupAll()
        return created
    }

    /// 기존 할 일을 새 시리즈의 시작으로 등록한다. 할 일 자체는 이미 있으므로 생성하지 않는다.
    func adoptExistingTodoAsSeriesOrigin(_ todo: Todo) throws {
        guard SubscriptionManager.shared.isPro else {
            AppLogger.shared.error("RecurringTodo", "Pro 구독 없이 시리즈 등록 시도")
            throw RecurringTodoError.requiresPro
        }
        guard let rule = todo.recurrenceRule else {
            AppLogger.shared.error("RecurringTodo", "adopt — RecurrenceRule 없음")
            throw RecurringTodoError.missingRule
        }
        guard let origin = todo.date else {
            AppLogger.shared.error("RecurringTodo", "adopt — origin 날짜 없음")
            throw RecurringTodoError.missingOriginDate
        }
        let seriesId = todo.recurrenceId ?? UUID().uuidString
        _ = try insertSeries(id: seriesId, from: todo, rule: rule, origin: origin)
        try context.save()
        RecurringSeriesBackupStore.shared.backupAll()
    }

    /// 앱 기동·포그라운드 복귀 시 호출. 오늘까지 놓친 발생분을 따라잡는다.
    func materializeDue() async {
        await materializeAll(through: Calendar.current.startOfDay(for: .now))
    }

    /// 날짜 이동 시 호출. 진짜 할 일은 **오늘까지만** 만든다 (2026-11-24 변경).
    /// 미래 날짜는 `previewOccurrences`로 미리보기만 보여주고, 그날이 되면 만든다.
    /// → 미래 날짜를 넘겨 보기만 해도 노션에 할 일이 잔뜩 생기던 문제·재설치 후 중복 방지.
    func materializeThrough(date: Date) async {
        await materializeDue()
    }

    /// 미래 날짜 미리보기: 그날 아직 없는 반복 할 일 (선택된 플래너, 읽기 전용 제외).
    /// 노션에 이미 미리 만들어진 같은 제목 할 일이 있으면 그 할 일이 보이므로 미리보기는 뺀다.
    func previewOccurrences(on date: Date, existingTitles: Set<String>) -> [RecurringOccurrencePreview] {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        guard day > calendar.startOfDay(for: .now) else { return [] }
        guard let seriesList = try? context.fetch(FetchDescriptor<RecurringSeries>()) else { return [] }
        let plannerId = PlannerService.shared.selectedPlanner?.id

        var previews: [RecurringOccurrencePreview] = []
        for series in seriesList where series.isActive {
            if isPlannerReadOnly(series.plannerId) { continue }
            if let plannerId, let seriesPlanner = series.plannerId, seriesPlanner != plannerId { continue }
            if existingTitles.contains(series.title) { continue }
            guard let existing = existingOccurrenceDates(seriesId: series.id),
                  series.shouldPreviewOccurrence(on: day, existingOccurrenceDates: existing) else { continue }
            previews.append(RecurringOccurrencePreview(
                id: series.id,
                title: series.title,
                categoryId: series.categoryId,
                scheduledTime: appliedScheduledTime(series.scheduledTime, on: day)
            ))
        }
        return previews.sorted { ($0.scheduledTime ?? .distantFuture, $0.title) < ($1.scheduledTime ?? .distantFuture, $1.title) }
    }

    /// 해당 월에서 아직 TodoItem이 없는 활성 시리즈 매칭 날짜의 카테고리 점.
    func previewCategoryDots(forMonthContaining date: Date) -> [Date: DayCategoryDots] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let monthStart = calendar.date(from: components),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart),
              let monthLast = calendar.date(byAdding: .day, value: -1, to: nextMonth) else {
            return [:]
        }

        let seriesList: [RecurringSeries]
        do {
            seriesList = try context.fetch(FetchDescriptor<RecurringSeries>())
        } catch {
            AppLogger.shared.error("RecurringTodo", "미리보기 시리즈 조회 실패 \(error.localizedDescription)")
            return [:]
        }

        let plannerId = PlannerService.shared.selectedPlanner?.id
        var buckets: [Date: (ids: [String], seen: Set<String>, hasUncategorized: Bool)] = [:]

        for series in seriesList where series.isActive {
            if isPlannerReadOnly(series.plannerId) { continue }
            if let plannerId, let seriesPlanner = series.plannerId,
               seriesPlanner != plannerId { continue }
            guard let rule = series.decodedRule else { continue }

            let origin = calendar.startOfDay(for: series.originDate)
            var rangeEnd = monthLast
            if let seriesEnd = series.endDate {
                let endDay = calendar.startOfDay(for: seriesEnd)
                if endDay < rangeEnd { rangeEnd = endDay }
            }
            guard origin <= rangeEnd, monthStart <= rangeEnd else { continue }
            let rangeStart = max(monthStart, origin)

            guard let existing = existingOccurrenceDates(seriesId: series.id) else { continue }

            let dates = rule.dates(in: rangeStart...rangeEnd, origin: origin)
            for day in dates {
                guard series.shouldPreviewOccurrence(on: day, existingOccurrenceDates: existing) else { continue }
                var bucket = buckets[day] ?? (ids: [], seen: [], hasUncategorized: false)
                if let categoryId = series.categoryId {
                    if !bucket.seen.contains(categoryId) {
                        bucket.seen.insert(categoryId)
                        bucket.ids.append(categoryId)
                    }
                } else {
                    bucket.hasUncategorized = true
                }
                buckets[day] = bucket
            }
        }

        return buckets.mapValues {
            DayCategoryDots(categoryIds: $0.ids, hasUncategorized: $0.hasUncategorized)
        }
    }

    /// 목록·편집용. `recurrenceId`에 해당하는 시리즈의 규칙·종료조건을 Todo에 붙인다.
    func attachingSeries(to todo: Todo) -> Todo {
        attachingSeries(to: [todo]).first ?? todo
    }

    func attachingSeries(to todos: [Todo]) -> [Todo] {
        let needed = Set(todos.compactMap(\.recurrenceId))
        guard !needed.isEmpty else { return todos }
        let seriesList: [RecurringSeries]
        do {
            seriesList = try context.fetch(FetchDescriptor<RecurringSeries>())
        } catch {
            AppLogger.shared.error("RecurringTodo", "시리즈 조회 실패 \(error.localizedDescription)")
            return todos
        }
        let byId = Dictionary(uniqueKeysWithValues: seriesList.map { ($0.id, $0) })
        return todos.map { todo in
            guard let rid = todo.recurrenceId, let series = byId[rid] else { return todo }
            return copy(todo, attaching: series)
        }
    }

    func deleteFutureTodos(seriesId: String, from date: Date, excludingId: String? = nil) async {
        let fromDay = Calendar.current.startOfDay(for: date)
        let allItems: [TodoItem]
        do {
            allItems = try context.fetch(FetchDescriptor<TodoItem>())
        } catch {
            AppLogger.shared.error("RecurringTodo", "미래 항목 조회 실패 \(error.localizedDescription)")
            return
        }
        let toDelete = allItems.filter {
            $0.recurrenceId == seriesId &&
            $0.id != excludingId &&
            ($0.date.map { Calendar.current.startOfDay(for: $0) } ?? .distantPast) >= fromDay
        }
        let ids = toDelete.map(\.id)
        for id in ids {
            do {
                try await TodoService.shared.deleteTodo(id: id)
            } catch {
                AppLogger.shared.error(
                    "RecurringTodo",
                    "미래 항목 삭제 실패 id:\(id) \(error.localizedDescription)"
                )
            }
        }
    }

    func capSeriesEndDate(seriesId: String, beforeDate: Date, excludingId: String? = nil) async {
        let cal = Calendar.current
        guard let endDay = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: beforeDate)) else { return }
        guard let series = RecurringSeries.fetch(id: seriesId, in: context) else { return }
        if let existingEnd = series.endDate {
            if cal.startOfDay(for: existingEnd) > endDay {
                series.endDate = endDay
            }
        } else {
            series.endDate = endDay
        }
        let originDay = cal.startOfDay(for: series.originDate)
        if let currentEnd = series.endDate, cal.startOfDay(for: currentEnd) < originDay {
            series.isActive = false
        }
        do {
            try context.save()
        } catch {
            AppLogger.shared.error("RecurringTodo", "시리즈 종료일 저장 실패 \(error.localizedDescription)")
        }
        RecurringSeriesBackupStore.shared.backupAll()
        await deleteFutureTodos(seriesId: seriesId, from: beforeDate, excludingId: excludingId)
        logLeftoverOccurrences(seriesId: seriesId, after: endDay, excludingId: excludingId, isActive: series.isActive)
    }

    /// 같은 시리즈의 이후 발생분에 제목·메모·카테고리·시간·알림만 반영한다.
    func updateFutureTodosDetails(from todo: Todo) async {
        guard let seriesId = todo.recurrenceId, let fromDate = todo.date else { return }
        let fromDay = Calendar.current.startOfDay(for: fromDate)
        let allItems: [TodoItem]
        do {
            allItems = try context.fetch(FetchDescriptor<TodoItem>())
        } catch {
            AppLogger.shared.error("RecurringTodo", "이후 항목 조회 실패 \(error.localizedDescription)")
            return
        }
        let targets = allItems.filter {
            $0.recurrenceId == seriesId &&
            $0.id != todo.id &&
            ($0.date.map { Calendar.current.startOfDay(for: $0) } ?? .distantPast) >= fromDay
        }
        for item in targets {
            var patched = item.toTodo()
            patched.title = todo.title
            patched.memo = todo.memo
            patched.categoryId = todo.categoryId
            patched.alarmOffset = todo.alarmOffset
            if let day = item.date {
                patched.scheduledTime = TodoScheduledTime.aligning(todo.scheduledTime, toDay: day)
            }
            patched.markLocallyModified()
            do {
                try await TodoService.shared.updateTodo(patched)
            } catch {
                AppLogger.shared.error(
                    "RecurringTodo",
                    "이후 항목 갱신 실패 id:\(item.id) \(error.localizedDescription)"
                )
            }
        }
    }

    /// 발생분 편집 내용을 이후 생성분의 템플릿으로 반영한다.
    func updateSeriesTemplate(from todo: Todo) {
        guard let seriesId = todo.recurrenceId else { return }
        guard let series = RecurringSeries.fetch(id: seriesId, in: context) else { return }
        series.title = todo.title
        series.memo = todo.memo
        series.categoryId = todo.categoryId
        series.scheduledTime = todo.scheduledTime
        series.alarmOffset = todo.alarmOffset
        do {
            try context.save()
        } catch {
            AppLogger.shared.error("RecurringTodo", "시리즈 템플릿 저장 실패 \(error.localizedDescription)")
        }
        RecurringSeriesBackupStore.shared.backupAll()
    }

    func updateSeriesEndCondition(seriesId: String, endDate: Date?, count: Int?) async {
        guard let series = RecurringSeries.fetch(id: seriesId, in: context) else { return }
        series.endDate = endDate
        series.occurrenceLimit = count
        do {
            try context.save()
        } catch {
            AppLogger.shared.error("RecurringTodo", "시리즈 종료 조건 저장 실패 \(error.localizedDescription)")
        }
        RecurringSeriesBackupStore.shared.backupAll()
    }

    // MARK: - Private

    private func insertSeries(id: String, from todo: Todo, rule: RecurrenceRule, origin: Date) throws -> RecurringSeries {
        guard let ruleData = try? JSONEncoder().encode(rule) else {
            AppLogger.shared.error("RecurringTodo", "RecurrenceRule 인코딩 실패")
            throw RecurringTodoError.ruleEncodingFailed
        }
        let cal = Calendar.current
        let originDay = cal.startOfDay(for: origin)
        let series = RecurringSeries(
            id: id,
            plannerId: todo.plannerId,
            title: todo.title,
            memo: todo.memo,
            categoryId: todo.categoryId,
            scheduledTime: todo.scheduledTime,
            alarmOffset: todo.alarmOffset,
            ruleData: ruleData,
            originDate: originDay,
            endDate: todo.recurrenceEndDate,
            occurrenceLimit: todo.recurrenceCount
        )
        context.insert(series)
        return series
    }

    private func materializeAll(through requestedThrough: Date) async {
        // 재설치·기기 변경 후: 기기에 없는 반복을 iCloud 백업에서 먼저 되살린다
        RecurringSeriesBackupStore.shared.restoreMissing()
        // 같은 반복이 두 벌이면(재설치 후 반복을 다시 설정한 경우 등) 하나로 합친다 — 날마다 2개씩 생기는 원인
        await mergeDuplicateSeries()
        defer { RecurringSeriesBackupStore.shared.backupAll() }
        let seriesList: [RecurringSeries]
        do {
            seriesList = try context.fetch(FetchDescriptor<RecurringSeries>())
        } catch {
            AppLogger.shared.error("RecurringTodo", "시리즈 조회 실패 \(error.localizedDescription)")
            return
        }
        let active = seriesList.filter(\.isActive)

        // 노션 플래너: 새로 만들 날짜의 노션 할 일을 먼저 받아 온다.
        // 그래야 노션에 이미 있는 같은 할 일(재설치 전에 올린 미래 할 일 등)을 연결하고, 2개를 만들지 않는다.
        // 범위 조회는 선택된 플래너만 가능 → 다른 노션 플래너는 그 플래너를 열 때 따라잡는다.
        let selectedPlannerId = PlannerService.shared.selectedPlanner?.id
        let selectedIsNotion = PlannerService.shared.selectedPlanner?.isNotionConnected == true
        var canMaterializeSelectedNotion = true
        if selectedIsNotion, let selectedPlannerId {
            let ranges = active
                .filter { $0.plannerId == selectedPlannerId }
                .compactMap { pendingRange(of: $0, through: requestedThrough) }
            if let start = ranges.map(\.lowerBound).min(), let end = ranges.map(\.upperBound).max() {
                do {
                    try await TodoService.shared.syncTodosFromNotionRange(start: start, end: end)
                } catch {
                    // 오프라인 등: 이번에는 만들지 않고 다음 기회에 (만들면 나중에 노션 할 일과 2개가 될 수 있음)
                    canMaterializeSelectedNotion = false
                    AppLogger.shared.warn("RecurringTodo", "노션 범위 조회 실패 — 반복 생성 보류 \(error.localizedDescription)")
                }
            }
        }

        for series in active {
            if let plannerId = series.plannerId, isNotionPlanner(plannerId) {
                guard plannerId == selectedPlannerId, canMaterializeSelectedNotion else { continue }
            }
            await materialize(series, through: requestedThrough)
        }
    }

    /// 같은 플래너·같은 제목·같은 규칙의 활성 시리즈가 여러 개면 가장 먼저 만든 것만 남긴다.
    /// - 나머지 시리즈는 끄고(isActive = false), 그 할 일은 남길 시리즈로 옮긴다
    /// - 같은 날에 남길 시리즈의 할 일이 이미 있으면 겹치는 할 일은 지운다
    private func mergeDuplicateSeries() async {
        guard let all = try? context.fetch(FetchDescriptor<RecurringSeries>()) else { return }
        let groups = Dictionary(grouping: all.filter(\.isActive)) { series in
            // 규칙은 JSON 바이트가 아니라 해석한 값으로 비교 (인코딩 순서가 달라도 같은 규칙이면 같게)
            "\(series.plannerId ?? "")|\(series.title)|\(String(describing: series.decodedRule))"
        }
        let calendar = Calendar.current
        for (_, group) in groups where group.count > 1 {
            // 시작일이 빠른 것 → 같으면 먼저 만든 것 (복원된 시리즈는 만든 시각이 같을 수 있어 시작일 우선)
            let sorted = group.sorted { ($0.originDate, $0.createdAt) < ($1.originDate, $1.createdAt) }
            guard let keeper = sorted.first else { continue }
            let duplicates = sorted.dropFirst()
            let duplicateIds = Set(duplicates.map(\.id))
            let keeperId = keeper.id

            let items = (try? context.fetch(FetchDescriptor<TodoItem>())) ?? []
            var keeperDays = Set(items.compactMap { item -> Date? in
                guard item.recurrenceId == keeperId, let date = item.date else { return nil }
                return calendar.startOfDay(for: date)
            })
            var toDelete: [TodoItem] = []
            for item in items {
                guard let rid = item.recurrenceId, duplicateIds.contains(rid) else { continue }
                guard let date = item.date else { item.recurrenceId = keeperId; continue }
                let day = calendar.startOfDay(for: date)
                if keeperDays.contains(day) {
                    toDelete.append(item)
                } else {
                    item.recurrenceId = keeperId
                    keeperDays.insert(day)
                }
            }
            for duplicate in duplicates {
                duplicate.isActive = false
                if let last = duplicate.lastMaterializedThrough,
                   last > (keeper.lastMaterializedThrough ?? .distantPast) {
                    keeper.lastMaterializedThrough = last
                }
            }
            do {
                try context.save()
            } catch {
                AppLogger.shared.error("RecurringTodo", "중복 반복 합치기 저장 실패 \(error.localizedDescription)")
                continue
            }
            for item in toDelete {
                await removeDuplicateOccurrence(item)
            }
            AppLogger.shared.info(
                "RecurringTodo",
                "중복 반복 합침 keep:\(keeperId) off:\(duplicates.count)개 겹친 할 일 삭제:\(toDelete.count)개"
            )
        }
    }

    /// 겹친 발생분 삭제. 노션에 올라간 것은 기존 삭제 경로(노션에서도 삭제),
    /// 아직 안 올라간 것은 대기 중인 노션 생성 작업까지 같이 지워 노션에 생기지 않게 한다.
    private func removeDuplicateOccurrence(_ item: TodoItem) async {
        let todoId = item.id
        guard item.notionPageId.isEmpty else {
            try? await TodoService.shared.deleteTodo(id: todoId)
            return
        }
        let queueDescriptor = FetchDescriptor<SyncQueueItem>(
            predicate: #Predicate { $0.entityId == todoId && $0.status != "processing" }
        )
        for queued in (try? context.fetch(queueDescriptor)) ?? [] {
            context.delete(queued)
        }
        TodoNotificationManager.shared.cancel(for: todoId)
        context.delete(item)
        try? context.save()
    }

    /// `materialize`가 새로 만들 날짜 범위 (없으면 nil). 시작·끝 계산은 `materialize`와 같다.
    private func pendingRange(of series: RecurringSeries, through requestedThrough: Date) -> ClosedRange<Date>? {
        let cal = Calendar.current
        let origin = cal.startOfDay(for: series.originDate)
        var through = cal.startOfDay(for: requestedThrough)
        if let seriesEnd = series.endDate {
            let endDay = cal.startOfDay(for: seriesEnd)
            if endDay < origin { return nil }
            if endDay < through { through = endDay }
        }
        let start: Date
        if let last = series.lastMaterializedThrough {
            guard let next = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: last)) else { return nil }
            start = next
        } else {
            start = origin
        }
        return start <= through ? start...through : nil
    }

    private func isNotionPlanner(_ plannerId: String) -> Bool {
        PlannerService.shared.store.first(where: { $0.id == plannerId })?.isNotionConnected == true
    }

    private func materialize(_ series: RecurringSeries, through requestedThrough: Date) async {
        guard series.isActive else { return }
        guard !isPlannerReadOnly(series.plannerId) else { return }
        guard let rule = series.decodedRule else {
            AppLogger.shared.error("RecurringTodo", "시리즈 규칙 디코딩 실패 id:\(series.id)")
            return
        }

        let cal = Calendar.current
        let origin = cal.startOfDay(for: series.originDate)
        if let seriesEnd = series.endDate, cal.startOfDay(for: seriesEnd) < origin {
            return
        }

        var through = cal.startOfDay(for: requestedThrough)
        if let seriesEnd = series.endDate {
            let endDay = cal.startOfDay(for: seriesEnd)
            if endDay < through { through = endDay }
        }

        let start: Date
        if let last = series.lastMaterializedThrough {
            guard let next = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: last)) else { return }
            start = next
        } else {
            start = origin
        }

        if start <= through {
            guard let existing = existingOccurrenceDates(seriesId: series.id) else { return }
            var count = existing.count
            var didFail = false
            let dates = rule.dates(in: start...through, origin: origin)
            for day in dates {
                if existing.contains(day) { continue }
                if let limit = series.occurrenceLimit, count >= limit { break }
                do {
                    _ = try await saveOccurrence(of: series, on: day)
                    count += 1
                } catch {
                    didFail = true
                    AppLogger.shared.error(
                        "RecurringTodo",
                        "발생분 생성 실패 series:\(series.id) day:\(day) \(error.localizedDescription)"
                    )
                    break
                }
            }
            if didFail { return }
        }

        if let last = series.lastMaterializedThrough, last >= through {
            return
        }
        series.lastMaterializedThrough = through
        do {
            try context.save()
        } catch {
            AppLogger.shared.error("RecurringTodo", "lastMaterializedThrough 저장 실패 \(error.localizedDescription)")
        }
    }

    private func saveOccurrence(of series: RecurringSeries, on day: Date) async throws -> Todo? {
        guard let existing = existingOccurrenceDates(seriesId: series.id) else {
            throw RecurringTodoError.storeFetchFailed
        }
        if existing.contains(Calendar.current.startOfDay(for: day)) { return nil }
        if adoptUnlinkedTodo(of: series, on: day) { return nil }
        let todo = occurrenceTodo(from: series, on: day)
        try await TodoService.shared.saveTodo(todo)
        return todo
    }

    /// 같은 플래너·같은 날·같은 제목인데 반복 연결이 없는 할 일이 있으면, 새로 만들지 않고 그 할 일을 이 반복에 연결한다.
    /// (재설치 후 노션에서 다시 들어온 할 일과 2개가 되는 것 방지. recurrenceId는 로컬 전용 값이라 노션 동기화 불필요)
    private func adoptUnlinkedTodo(of series: RecurringSeries, on day: Date) -> Bool {
        let calendar = Calendar.current
        let target = calendar.startOfDay(for: day)
        let plannerId = series.plannerId
        let title = series.title
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { $0.recurrenceId == nil && $0.title == title }
        )
        guard let candidates = try? context.fetch(descriptor),
              let match = candidates.first(where: {
                  $0.plannerId == plannerId && $0.date.map { calendar.startOfDay(for: $0) } == target
              }) else {
            return false
        }
        match.recurrenceId = series.id
        do {
            try context.save()
        } catch {
            AppLogger.shared.error("RecurringTodo", "기존 할 일 반복 연결 실패 \(error.localizedDescription)")
            return false
        }
        AppLogger.shared.info("RecurringTodo", "같은 날 같은 제목 할 일을 반복에 연결 series:\(series.id)")
        return true
    }

    private func occurrenceTodo(from series: RecurringSeries, on day: Date) -> Todo {
        Todo(
            title: series.title,
            memo: series.memo,
            date: day,
            categoryId: series.categoryId,
            plannerId: series.plannerId,
            scheduledTime: appliedScheduledTime(series.scheduledTime, on: day),
            alarmOffset: series.alarmOffset,
            recurrenceId: series.id,
            localModifiedAt: .now
        )
    }

    private func appliedScheduledTime(_ template: Date?, on day: Date) -> Date? {
        guard let template else { return nil }
        let cal = Calendar.current
        let time = cal.dateComponents([.hour, .minute], from: template)
        var parts = cal.dateComponents([.year, .month, .day], from: day)
        parts.hour = time.hour
        parts.minute = time.minute
        return cal.date(from: parts) ?? day
    }

    private func existingOccurrenceDates(seriesId: String) -> Set<Date>? {
        let cal = Calendar.current
        let items: [TodoItem]
        do {
            items = try context.fetch(FetchDescriptor<TodoItem>())
        } catch {
            AppLogger.shared.error("RecurringTodo", "할 일 조회 실패 \(error.localizedDescription)")
            return nil
        }
        return Set(
            items.compactMap { item -> Date? in
                guard item.recurrenceId == seriesId, let date = item.date else { return nil }
                return cal.startOfDay(for: date)
            }
        )
    }

    private func logLeftoverOccurrences(
        seriesId: String,
        after endDay: Date,
        excludingId: String?,
        isActive: Bool
    ) {
        let cal = Calendar.current
        let items: [TodoItem]
        do {
            items = try context.fetch(FetchDescriptor<TodoItem>())
        } catch {
            AppLogger.shared.error("RecurringTodo", "시리즈 종료 잔여 조회 실패 \(error.localizedDescription)")
            return
        }
        let leftover = items.filter {
            $0.recurrenceId == seriesId &&
            $0.id != excludingId &&
            ($0.date.map { cal.startOfDay(for: $0) } ?? .distantPast) > endDay
        }.count
        let message = "시리즈 종료 정리 series:\(seriesId) leftover:\(leftover) isActive:\(isActive)"
        if leftover == 0 {
            AppLogger.shared.info("RecurringTodo", message)
        } else {
            AppLogger.shared.warn("RecurringTodo", message)
        }
    }

    private func isPlannerReadOnly(_ plannerId: String?) -> Bool {
        guard let plannerId else { return false }
        return PlannerService.shared.store.first(where: { $0.id == plannerId })?.isReadOnly == true
    }

    private func copy(_ todo: Todo, attaching series: RecurringSeries) -> Todo {
        var result = todo
        result.recurrenceRule = series.decodedRule
        result.recurrenceEndDate = series.endDate.map { Calendar.current.startOfDay(for: $0) }
        result.recurrenceCount = series.occurrenceLimit
        return result
    }
}
