import Foundation
import SwiftData

@MainActor
final class RecurringTodoManager {
    static let shared = RecurringTodoManager()
    private init() {}

    private var context: ModelContext { PersistenceController.shared.context }

    // 오늘~2주 뒤 반복 투두 생성 (이미 존재하는 날짜는 스킵)
    func generateUpcoming() async {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        guard let twoWeeksLater = cal.date(byAdding: .day, value: 14, to: today) else { return }

        let allItems = (try? context.fetch(FetchDescriptor<TodoItem>())) ?? []

        // recurrenceData가 있는 항목만 처리
        let sources = allItems.filter { $0.recurrenceData != nil && $0.recurrenceId != nil }

        // recurrenceId별로 그룹화 — 각 시리즈에서 가장 오래된 항목을 origin으로 사용
        var seriesMap: [String: TodoItem] = [:]
        for item in sources {
            guard let rid = item.recurrenceId else { continue }
            if let existing = seriesMap[rid] {
                if item.date < existing.date { seriesMap[rid] = item }
            } else {
                seriesMap[rid] = item
            }
        }

        for (recurrenceId, origin) in seriesMap {
            guard let rule = origin.decodedRecurrence else { continue }

            // 이미 생성된 날짜 Set
            let existingDates = Set(
                allItems
                    .filter { $0.recurrenceId == recurrenceId }
                    .map { cal.startOfDay(for: $0.date) }
            )

            // 생성 대상 날짜 계산
            let targetDates = rule.dates(in: today...twoWeeksLater, origin: origin.date)

            for targetDate in targetDates {
                // 이미 존재하면 스킵
                if existingDates.contains(targetDate) { continue }

                // 종료 조건 체크
                if let endDate = origin.recurrenceEndDate,
                   cal.startOfDay(for: endDate) < targetDate { continue }
                if let maxCount = origin.recurrenceCount {
                    let occurrencesSoFar = allItems.filter {
                        $0.recurrenceId == recurrenceId &&
                        cal.startOfDay(for: $0.date) <= targetDate
                    }.count
                    if occurrencesSoFar >= maxCount { continue }
                }

                // 새 TodoItem 생성
                let timeComps = cal.dateComponents([.hour, .minute], from: origin.scheduledTime ?? origin.date)
                let newDate: Date
                if origin.scheduledTime != nil {
                    var dc = cal.dateComponents([.year, .month, .day], from: targetDate)
                    dc.hour = timeComps.hour
                    dc.minute = timeComps.minute
                    newDate = cal.date(from: dc) ?? targetDate
                } else {
                    newDate = targetDate
                }

                let newItem = TodoItem(
                    title: origin.title,
                    memo: origin.memo,
                    categoryId: origin.categoryId,
                    notionPageId: "",
                    plannerId: origin.plannerId,
                    scheduledTime: origin.scheduledTime != nil ? newDate : nil,
                    alarmOffset: origin.alarmOffset,
                    recurrenceRule: origin.decodedRecurrence,
                    recurrenceId: recurrenceId,
                    recurrenceEndDate: origin.recurrenceEndDate,
                    recurrenceCount: origin.recurrenceCount,
                    notionRelationLinked: false
                )
                newItem.date = targetDate

                context.insert(newItem)
                print("[RecurringTodo] ➕ 생성: \(origin.title) \(targetDate)")
                SyncQueueManager.shared.enqueueTodoCreate(newItem.toTodo())
            }
        }

        try? context.save()
    }

    // MARK: - 편집 플로우 지원

    // 특정 항목을 제외하고 시리즈의 미래 항목 삭제
    func deleteFutureTodos(seriesId: String, from date: Date, excludingId: String) async {
        let fromDay = Calendar.current.startOfDay(for: date)
        let allItems = (try? context.fetch(FetchDescriptor<TodoItem>())) ?? []
        let toDelete = allItems.filter {
            $0.recurrenceId == seriesId &&
            Calendar.current.startOfDay(for: $0.date) >= fromDay &&
            $0.id != excludingId
        }
        let deletions: [(notionPageId: String, plannerId: String?)] = toDelete.compactMap {
            guard !$0.notionPageId.isEmpty else { return nil }
            return ($0.notionPageId, $0.plannerId)
        }
        let todoIds = toDelete.map { $0.id }
        toDelete.forEach { context.delete($0) }
        try? context.save()
        todoIds.forEach { TodoNotificationManager.shared.cancel(for: $0) }
        deletions.forEach { SyncQueueManager.shared.enqueueTodoDelete(notionPageId: $0.notionPageId, plannerId: $0.plannerId) }
    }

    // 기존 시리즈 항목들의 종료일을 특정 날짜 직전으로 제한 (미래 재생성 방지)
    func capSeriesEndDate(seriesId: String, beforeDate: Date, excludingId: String) async {
        let cal = Calendar.current
        guard let endDay = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: beforeDate)) else { return }
        let allItems = (try? context.fetch(FetchDescriptor<TodoItem>())) ?? []
        let seriesItems = allItems.filter { $0.recurrenceId == seriesId && $0.id != excludingId }
        var modified: [TodoItem] = []
        seriesItems.forEach { item in
            if item.recurrenceEndDate == nil || item.recurrenceEndDate! > endDay {
                item.recurrenceEndDate = endDay
                modified.append(item)
            }
        }
        try? context.save()
        modified.forEach { SyncQueueManager.shared.enqueueTodoUpdate($0.toTodo()) }
    }

    // 시리즈 전체 종료 조건 일괄 업데이트
    func updateSeriesEndCondition(seriesId: String, endDate: Date?, count: Int?) async {
        let allItems = (try? context.fetch(FetchDescriptor<TodoItem>())) ?? []
        let seriesItems = allItems.filter { $0.recurrenceId == seriesId }
        seriesItems.forEach { item in
            item.recurrenceEndDate = endDate
            item.recurrenceCount = count
        }
        try? context.save()
        seriesItems.forEach { SyncQueueManager.shared.enqueueTodoUpdate($0.toTodo()) }
    }
}
