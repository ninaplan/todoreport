import Foundation
import SwiftData

@MainActor
final class RecurringTodoManager {
    static let shared = RecurringTodoManager()
    private init() {}

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
    }

    /// 앱 기동·포그라운드 복귀 시 호출. 오늘까지 놓친 발생분을 따라잡는다.
    func materializeDue() async {
        await materializeAll(through: Calendar.current.startOfDay(for: .now))
    }

    /// 오늘과 `date` 중 더 늦은 날까지 순서대로 채운다. 지정일 하나만 건너뛰어 만들지 않는다.
    func materializeThrough(date: Date) async {
        let cal = Calendar.current
        let through = max(cal.startOfDay(for: .now), cal.startOfDay(for: date))
        await materializeAll(through: through)
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

    func deleteFutureTodos(seriesId: String, from date: Date, excludingId: String) async {
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

    func capSeriesEndDate(seriesId: String, beforeDate: Date) async {
        let cal = Calendar.current
        guard let endDay = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: beforeDate)) else { return }
        guard let series = RecurringSeries.fetch(id: seriesId, in: context) else { return }
        if let existingEnd = series.endDate, cal.startOfDay(for: existingEnd) <= endDay {
            return
        }
        series.endDate = endDay
        do {
            try context.save()
        } catch {
            AppLogger.shared.error("RecurringTodo", "시리즈 종료일 저장 실패 \(error.localizedDescription)")
        }
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
        let seriesList: [RecurringSeries]
        do {
            seriesList = try context.fetch(FetchDescriptor<RecurringSeries>())
        } catch {
            AppLogger.shared.error("RecurringTodo", "시리즈 조회 실패 \(error.localizedDescription)")
            return
        }
        for series in seriesList where series.isActive {
            await materialize(series, through: requestedThrough)
        }
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
        let todo = occurrenceTodo(from: series, on: day)
        try await TodoService.shared.saveTodo(todo)
        return todo
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
