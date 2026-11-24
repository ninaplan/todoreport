import CoreGraphics
import Foundation

/// 타임라인의 분 ↔ 좌표 변환과 스냅 규칙. 화면·뷰모델이 같은 값을 쓰도록 한곳에 모은다.
enum TimeBlockLayout {
    static let minutesPerDay = 1440
    /// 1시간 = 66pt
    static let pointsPerMinute: CGFloat = 1.1
    static let labelColumnWidth: CGFloat = 52
    /// 시각 표시와 블록 사이 세로 줄(레일)의 x 위치
    static let railX: CGFloat = 64
    /// 블록 카드가 시작하는 x 위치
    static let blockLeading: CGFloat = 78
    static let blockTrailingPadding: CGFloat = 16
    static let verticalPadding: CGFloat = 14
    static let defaultDurationMinutes = 60
    static let snapOptions: [Int] = [15, 30, 60]
    static let defaultSnapMinutes = 30
    static let snapMinutesKey = "timeBlockSnapMinutes"
    static let showsCategoryColorKey = "timeBlockShowsCategoryColor"
    static let startAlarmEnabledKey = "timeBlockStartAlarmEnabled"
    static let endAlarmEnabledKey = "timeBlockEndAlarmEnabled"
    /// 화면을 처음 열 때 보여줄 시각 (오늘이 아니면 이 시각부터)
    static let defaultScrollHour = 8

    static var contentHeight: CGFloat {
        CGFloat(minutesPerDay) * pointsPerMinute + verticalPadding * 2
    }

    static func y(for minute: Int) -> CGFloat {
        verticalPadding + CGFloat(minute) * pointsPerMinute
    }

    static func minute(for y: CGFloat) -> Int {
        clamp(Int(((y - verticalPadding) / pointsPerMinute).rounded(.down)))
    }

    static func snapDown(_ minute: Int, unit: Int) -> Int {
        guard unit > 0 else { return clamp(minute) }
        return clamp((minute / unit) * unit)
    }

    static func snapNearest(_ minute: Int, unit: Int) -> Int {
        guard unit > 0 else { return clamp(minute) }
        return clamp(Int((Double(minute) / Double(unit)).rounded()) * unit)
    }

    static func clamp(_ minute: Int) -> Int {
        min(max(minute, 0), minutesPerDay)
    }

    /// 그날 0시 + 분 → Date
    static func date(day: Date, minute: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: minute, to: day) ?? day
    }

    /// Date → 그날 0시부터 지난 분
    static func minute(of date: Date, day: Date) -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let total = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        if Calendar.current.isDate(date, inSameDayAs: day) {
            return clamp(total)
        }
        return date > day ? minutesPerDay : 0
    }
}
