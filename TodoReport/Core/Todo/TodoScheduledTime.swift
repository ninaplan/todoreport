import Foundation

/// 할일 `date`와 `scheduledTime`의 날짜 부분을 맞춘다.
/// `scheduledTime`은 시:분만이 아니라 절대 시각이라, 날짜만 바꾸면 노션·알림이 옛날을 가리킨다.
enum TodoScheduledTime {
    /// `scheduledTime`의 시·분·초를 유지한 채 연·월·일을 `day`로 옮긴다. nil이면 nil.
    static func aligning(
        _ scheduledTime: Date?,
        toDay day: Date,
        calendar: Calendar = .current
    ) -> Date? {
        guard let scheduledTime else { return nil }
        let dayStart = calendar.startOfDay(for: day)
        let time = calendar.dateComponents([.hour, .minute, .second], from: scheduledTime)
        return calendar.date(
            bySettingHour: time.hour ?? 0,
            minute: time.minute ?? 0,
            second: time.second ?? 0,
            of: dayStart
        )
    }

    /// `todo.date`를 새 날짜(startOfDay)로 바꾸고, 있으면 `scheduledTime`도 같은 날로 맞춘다.
    static func applyingDateChange(
        to todo: inout Todo,
        newDate: Date,
        calendar: Calendar = .current
    ) {
        let day = calendar.startOfDay(for: newDate)
        todo.date = day
        todo.scheduledTime = aligning(todo.scheduledTime, toDay: day, calendar: calendar)
    }
}
