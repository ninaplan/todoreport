import Foundation

// Picker용 단순 enum (associated values 없음)
enum RecurrenceKind: String, CaseIterable, Equatable {
    case none      = "안 함"
    case daily     = "매일"
    case weekdays  = "평일(월~금)"
    case weekends  = "주말(토~일)"
    case weekly    = "매주"
    case biweekly  = "격주"
    case monthly   = "매월"
    case yearly    = "매년"

    var needsWeekdaySelection: Bool { self == .weekly || self == .biweekly }
}

// 실제 저장/계산에 사용하는 enum
enum RecurrenceRule: Codable, Equatable {
    case daily
    case weekdays
    case weekends
    case weekly([Int])     // 0=일, 1=월, 2=화, 3=수, 4=목, 5=금, 6=토
    case biweekly([Int])
    case monthly
    case yearly

    var kind: RecurrenceKind {
        switch self {
        case .daily:    return .daily
        case .weekdays: return .weekdays
        case .weekends: return .weekends
        case .weekly:   return .weekly
        case .biweekly: return .biweekly
        case .monthly:  return .monthly
        case .yearly:   return .yearly
        }
    }

    var weekdayIndices: [Int] {
        switch self {
        case .weekly(let d), .biweekly(let d): return d
        default: return []
        }
    }

    var displayName: String {
        switch self {
        case .daily:            return "매일"
        case .weekdays:         return "평일(월~금)"
        case .weekends:         return "주말(토~일)"
        case .weekly(let d):    return "매주 \(weekdayLabel(d))"
        case .biweekly(let d):  return "격주 \(weekdayLabel(d))"
        case .monthly:          return "매월"
        case .yearly:           return "매년"
        }
    }

    private func weekdayLabel(_ indices: [Int]) -> String {
        let names = ["일", "월", "화", "수", "목", "금", "토"]
        return indices.sorted().compactMap { $0 < names.count ? names[$0] : nil }.joined(separator: "·")
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey { case type, weekdays }

    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .daily:           try c.encode("daily",    forKey: .type)
        case .weekdays:        try c.encode("weekdays", forKey: .type)
        case .weekends:        try c.encode("weekends", forKey: .type)
        case .weekly(let d):   try c.encode("weekly",   forKey: .type); try c.encode(d, forKey: .weekdays)
        case .biweekly(let d): try c.encode("biweekly", forKey: .type); try c.encode(d, forKey: .weekdays)
        case .monthly:         try c.encode("monthly",  forKey: .type)
        case .yearly:          try c.encode("yearly",   forKey: .type)
        }
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let t = try c.decode(String.self, forKey: .type)
        switch t {
        case "daily":    self = .daily
        case "weekdays": self = .weekdays
        case "weekends": self = .weekends
        case "weekly":   self = .weekly((try? c.decode([Int].self, forKey: .weekdays)) ?? [])
        case "biweekly": self = .biweekly((try? c.decode([Int].self, forKey: .weekdays)) ?? [])
        case "monthly":  self = .monthly
        case "yearly":   self = .yearly
        default:         self = .daily
        }
    }

    // MARK: - Date Matching

    /// origin의 패턴이 date에 해당하는지 판정
    func matches(date: Date, origin: Date) -> Bool {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date) - 1  // 0=일..6=토
        switch self {
        case .daily:
            return true
        case .weekdays:
            return (1...5).contains(weekday)
        case .weekends:
            return weekday == 0 || weekday == 6
        case .weekly(let days):
            return days.contains(weekday)
        case .biweekly(let days):
            guard days.contains(weekday) else { return false }
            let originStart = cal.startOfDay(for: origin)
            let dateStart   = cal.startOfDay(for: date)
            guard dateStart >= originStart else { return false }
            let daysDiff  = cal.dateComponents([.day], from: originStart, to: dateStart).day ?? 0
            let weeksDiff = daysDiff / 7
            return weeksDiff % 2 == 0
        case .monthly:
            return cal.component(.day, from: date) == cal.component(.day, from: origin)
        case .yearly:
            let oComps = cal.dateComponents([.month, .day], from: origin)
            let dComps = cal.dateComponents([.month, .day], from: date)
            return oComps.month == dComps.month && oComps.day == dComps.day
        }
    }

    /// [startDate, endDate] 범위에서 패턴과 일치하는 날짜 목록 반환
    func dates(in range: ClosedRange<Date>, origin: Date) -> [Date] {
        let cal = Calendar.current
        var results: [Date] = []
        var current = cal.startOfDay(for: range.lowerBound)
        let end     = cal.startOfDay(for: range.upperBound)
        while current <= end {
            if matches(date: current, origin: origin) { results.append(current) }
            guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return results
    }
}

// MARK: - RecurrenceKind → RecurrenceRule 변환 헬퍼
extension RecurrenceKind {
    func toRule(weekdays: [Int] = []) -> RecurrenceRule? {
        switch self {
        case .none:      return nil
        case .daily:     return .daily
        case .weekdays:  return .weekdays
        case .weekends:  return .weekends
        case .weekly:    return .weekly(weekdays.isEmpty ? [1] : weekdays)
        case .biweekly:  return .biweekly(weekdays.isEmpty ? [1] : weekdays)
        case .monthly:   return .monthly
        case .yearly:    return .yearly
        }
    }
}
