import Foundation

enum MonthlyReportNotificationTiming: String, CaseIterable {
    case firstDay
    case lastDay

    var displayName: String {
        switch self {
        case .firstDay: return "1일"
        case .lastDay: return "말일"
        }
    }
}

enum ReportNotificationSettings {
    static let weeklyEnabledKey = "reportSaveNotificationWeeklyEnabled"
    static let monthlyEnabledKey = "reportSaveNotificationMonthlyEnabled"
    static let hourKey = "reportSaveNotificationHour"
    static let minuteKey = "reportSaveNotificationMinute"
    static let weeklyWeekdayKey = "reportSaveNotificationWeeklyWeekday"
    static let monthlyTimingKey = "reportSaveNotificationMonthlyTiming"

    static var weeklyEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: weeklyEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: weeklyEnabledKey) }
    }

    static var monthlyEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: monthlyEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: monthlyEnabledKey) }
    }

    static var hour: Int {
        get {
            let stored = UserDefaults.standard.object(forKey: hourKey) as? Int
            return stored ?? 20
        }
        set { UserDefaults.standard.set(newValue, forKey: hourKey) }
    }

    static var minute: Int {
        get { UserDefaults.standard.object(forKey: minuteKey) as? Int ?? 0 }
        set { UserDefaults.standard.set(newValue, forKey: minuteKey) }
    }

    /// Calendar weekday (1=일 … 7=토)
    static var weeklyWeekday: Int {
        get {
            if UserDefaults.standard.object(forKey: weeklyWeekdayKey) != nil {
                return UserDefaults.standard.integer(forKey: weeklyWeekdayKey)
            }
            let startWeekday = UserDefaults.standard.string(forKey: "startWeekday") ?? "월"
            return startWeekday == "일" ? 1 : 2
        }
        set { UserDefaults.standard.set(newValue, forKey: weeklyWeekdayKey) }
    }

    static var monthlyTiming: MonthlyReportNotificationTiming {
        get {
            let raw = UserDefaults.standard.string(forKey: monthlyTimingKey) ?? ""
            return MonthlyReportNotificationTiming(rawValue: raw) ?? .firstDay
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: monthlyTimingKey) }
    }

    static func isEnabled(for period: ReportPeriod) -> Bool {
        switch period {
        case .weekly: return weeklyEnabled
        case .monthly: return monthlyEnabled
        }
    }

    static func setEnabled(_ enabled: Bool, for period: ReportPeriod) {
        switch period {
        case .weekly: weeklyEnabled = enabled
        case .monthly: monthlyEnabled = enabled
        }
    }

    static let weekdayLabels: [(value: Int, label: String)] = [
        (1, "일요일"), (2, "월요일"), (3, "화요일"), (4, "수요일"),
        (5, "목요일"), (6, "금요일"), (7, "토요일"),
    ]

    static let weekdayShortLabels: [(value: Int, label: String)] = [
        (1, "일"), (2, "월"), (3, "화"), (4, "수"),
        (5, "목"), (6, "금"), (7, "토"),
    ]

    static func weekdayLabel(for value: Int, short: Bool = false) -> String {
        let options = short ? weekdayShortLabels : weekdayLabels
        return options.first(where: { $0.value == value })?.label ?? "월"
    }
}
