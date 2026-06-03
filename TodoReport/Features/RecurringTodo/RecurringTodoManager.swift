import Foundation
import SwiftData

@MainActor
final class RecurringTodoManager {
    static let shared = RecurringTodoManager()
    private init() {}

    private var context: ModelContext { PersistenceController.shared.context }

    // 오늘~2주 뒤 반복 투두 생성 (이미 존재하는 날짜는 스킵)
    func generateUpcoming() {
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
            }
        }

        try? context.save()
    }
}
