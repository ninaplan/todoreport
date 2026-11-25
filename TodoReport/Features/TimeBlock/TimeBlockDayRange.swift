import Foundation

/// 타임블록에 보여 줄 하루 시간 범위 (일과 시간).
/// 분은 그날 0시 기준. 끝은 다음 날 새벽까지 갈 수 있다 (예: 10:00~다음 날 02:00 = 600...1560).
/// 길이는 최대 24시간이라 이웃한 두 날의 범위가 겹치지 않는다.
struct TimeBlockDayRange: Equatable {
    let startMinute: Int
    let endMinute: Int

    static let fullDay = TimeBlockDayRange(startMinute: 0, endMinute: TimeBlockLayout.minutesPerDay)
    /// 처음 쓰는 플래너의 기본값: 06:00~24:00
    static let defaultRange = TimeBlockDayRange(startMinute: 6 * 60, endMinute: TimeBlockLayout.minutesPerDay)
    /// 끝 시각이 가장 늦을 수 있는 값 (다음 날 24:00)
    static let latestEndMinute = TimeBlockLayout.minutesPerDay * 2

    init(startMinute: Int, endMinute: Int) {
        self.startMinute = startMinute
        self.endMinute = endMinute
    }

    /// 1시간 단위·최소 1시간·최대 24시간인지
    var isValid: Bool {
        startMinute >= 0
            && startMinute < TimeBlockLayout.minutesPerDay
            && startMinute % 60 == 0
            && endMinute % 60 == 0
            && endMinute > startMinute
            && endMinute - startMinute <= TimeBlockLayout.minutesPerDay
    }

    /// 끝이 자정을 넘는지
    var spansMidnight: Bool { endMinute > TimeBlockLayout.minutesPerDay }

    var durationMinutes: Int { endMinute - startMinute }

    func clamp(_ minute: Int) -> Int {
        min(max(minute, startMinute), endMinute)
    }

    func contains(start: Int, end: Int) -> Bool {
        start >= startMinute && end <= endMinute
    }

    /// 블록이 범위와 조금이라도 겹치는지 (안 겹치면 화면에 안 그림)
    func intersects(start: Int, end: Int) -> Bool {
        start < endMinute && end > startMinute
    }

    /// 시각(0시부터 분, 0..<1440) → 이 범위 화면의 분.
    /// 시작보다 이른 시각은 다음 날로 본다 — 단, 다음 날로 봐도 범위(또는 24:00) 안일 때만.
    /// 예: 범위 10:00~02:00에서 01:00 → 1500 / 범위 06:00~24:00에서 종료 00:00 → 1440
    func pageMinute(fromTimeOfDay minute: Int) -> Int {
        guard minute < startMinute else { return minute }
        let nextDay = minute + TimeBlockLayout.minutesPerDay
        return nextDay <= max(endMinute, TimeBlockLayout.minutesPerDay) ? nextDay : minute
    }

    /// 시각 고르기(DatePicker)로 받은 Date → 이 범위 화면의 분 (날짜 부분은 무시)
    func pageMinute(of date: Date) -> Int {
        pageMinute(fromTimeOfDay: TimeBlockLayout.minuteOfDay(date))
    }

    /// 종료 시각 → 분. 시작보다 같거나 이르면 다음 날로 본다 (예: 종료 00:00 = 24:00).
    /// 다음 날로 봐도 범위(또는 24:00) 안일 때만
    func pageEndMinute(of date: Date, start: Int) -> Int {
        let minute = pageMinute(of: date)
        guard minute <= start else { return minute }
        let nextDay = TimeBlockLayout.minuteOfDay(date) + TimeBlockLayout.minutesPerDay
        return nextDay <= max(endMinute, TimeBlockLayout.minutesPerDay) ? nextDay : minute
    }

    /// 지금 시각이 속한 「타임블록의 오늘」.
    /// 범위가 자정을 넘고 지금이 전날 범위의 새벽 꼬리라면 전날이 오늘이다 (투두 탭과는 무관).
    func logicalDay(for date: Date) -> Date {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard spansMidnight else { return dayStart }
        let minute = TimeBlockLayout.minutesSince(day: dayStart, until: date)
        guard minute < endMinute - TimeBlockLayout.minutesPerDay,
              let previous = calendar.date(byAdding: .day, value: -1, to: dayStart) else { return dayStart }
        return previous
    }
}

/// 일과 시간 저장 (플래너별, 기기에만).
enum TimeBlockDayRangeStore {
    private static let keyPrefix = "timeBlockDayRange."

    static func load(plannerId: String?) -> TimeBlockDayRange {
        guard let values = UserDefaults.standard.array(forKey: key(for: plannerId)) as? [Int],
              values.count == 2 else { return .defaultRange }
        let range = TimeBlockDayRange(startMinute: values[0], endMinute: values[1])
        return range.isValid ? range : .defaultRange
    }

    static func save(_ range: TimeBlockDayRange, plannerId: String?) {
        guard range.isValid else { return }
        UserDefaults.standard.set([range.startMinute, range.endMinute], forKey: key(for: plannerId))
    }

    private static func key(for plannerId: String?) -> String {
        keyPrefix + (plannerId ?? "default")
    }
}
