import Foundation

enum TodoDateAccess {
    /// 무료: 어제·오늘·내일. Pro: 모든 날짜.
    static func canView(date: Date, isPro: Bool) -> Bool {
        if isPro { return true }
        let cal = Calendar.current
        let target = cal.startOfDay(for: date)
        let todayStart = cal.startOfDay(for: .now)
        guard let yesterdayStart = cal.date(byAdding: .day, value: -1, to: todayStart),
              let tomorrowStart = cal.date(byAdding: .day, value: 1, to: todayStart) else {
            return false
        }
        return target >= yesterdayStart && target <= tomorrowStart
    }
}
