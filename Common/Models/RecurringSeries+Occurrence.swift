import Foundation
import SwiftData

extension RecurringSeries {
    var decodedRule: RecurrenceRule? {
        try? JSONDecoder().decode(RecurrenceRule.self, from: ruleData)
    }

    /// 아직 생성되지 않았고, 규칙·종료·횟수 한도에 맞는 미리보기 날짜인지.
    /// SwiftData에 쓰지 않는 읽기 전용 판정 — 위젯·달력 미리보기가 같이 쓴다.
    func shouldPreviewOccurrence(on day: Date, existingOccurrenceDates: Set<Date>) -> Bool {
        guard isActive else { return false }
        guard let rule = decodedRule else { return false }
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        let origin = cal.startOfDay(for: originDate)
        if dayStart < origin { return false }
        if let end = endDate, dayStart > cal.startOfDay(for: end) { return false }
        if let last = lastMaterializedThrough, dayStart <= cal.startOfDay(for: last) { return false }
        if existingOccurrenceDates.contains(dayStart) { return false }
        if let limit = occurrenceLimit, existingOccurrenceDates.count >= limit { return false }
        return rule.matches(date: dayStart, origin: origin)
    }
}
