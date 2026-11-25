import CoreGraphics
import Foundation

/// 타임라인의 분 ↔ 좌표 변환과 스냅 규칙. 화면·뷰모델이 같은 값을 쓰도록 한곳에 모은다.
enum TimeBlockLayout {
    static let minutesPerDay = 1440
    /// 기본 높이: 1시간 = 66pt. 타임블록 화면은 핀치로 바꾼 값(`TimeBlockViewModel.pointsPerMinute`)을 쓴다
    static let pointsPerMinute: CGFloat = 1.1
    /// 확대·축소 한계: 1시간 24pt ~ 132pt
    static let minPointsPerMinute: CGFloat = 0.4
    static let maxPointsPerMinute: CGFloat = 2.2
    static let pointsPerMinuteKey = "timeBlockPointsPerMinute"

    static func clampPointsPerMinute(_ value: CGFloat) -> CGFloat {
        min(max(value, minPointsPerMinute), maxPointsPerMinute)
    }
    static let labelColumnWidth: CGFloat = 52
    /// 시각 표시와 블록 사이 세로 줄(레일)의 x 위치
    static let railX: CGFloat = 64
    /// 블록 카드가 시작하는 x 위치
    static let blockLeading: CGFloat = 78
    static let blockTrailingPadding: CGFloat = 16
    /// 이어지는 블록 사이 틈 (블록 위아래 절반씩)
    static let blockGap: CGFloat = 1
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

    // MARK: - 일과 시간 범위 기준 (화면 맨 위 = 범위 시작)

    static func contentHeight(for range: TimeBlockDayRange, pointsPerMinute scale: CGFloat = pointsPerMinute) -> CGFloat {
        CGFloat(range.durationMinutes) * scale + verticalPadding * 2
    }

    static func y(for minute: Int, in range: TimeBlockDayRange, pointsPerMinute scale: CGFloat = pointsPerMinute) -> CGFloat {
        verticalPadding + CGFloat(minute - range.startMinute) * scale
    }

    static func minute(for y: CGFloat, in range: TimeBlockDayRange, pointsPerMinute scale: CGFloat = pointsPerMinute) -> Int {
        range.clamp(range.startMinute + Int(((y - verticalPadding) / scale).rounded(.down)))
    }

    /// 그날 0시부터 지난 분. 다음 날이면 1440을 넘는다 (자르지 않음)
    static func minutesSince(day: Date, until date: Date) -> Int {
        Calendar.current.dateComponents([.minute], from: day, to: date).minute ?? 0
    }

    /// Date의 시각만 (0시부터 분, 0..<1440)
    static func minuteOfDay(_ date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }

    static func minute(for y: CGFloat) -> Int {
        clamp(Int(((y - verticalPadding) / pointsPerMinute).rounded(.down)))
    }

    /// 스냅만 한다. 범위 자르기는 부르는 쪽에서 `TimeBlockDayRange.clamp`로 (다음 날 새벽 = 1440 초과 허용)
    static func snapDown(_ minute: Int, unit: Int) -> Int {
        guard unit > 0 else { return max(minute, 0) }
        return max((minute / unit) * unit, 0)
    }

    static func snapNearest(_ minute: Int, unit: Int) -> Int {
        guard unit > 0 else { return max(minute, 0) }
        return max(Int((Double(minute) / Double(unit)).rounded()) * unit, 0)
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
