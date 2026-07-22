import Foundation

enum AppCalendar {
    /// 설정 > 시작 요일(`startWeekday`: "일"/"월")을 반영한 캘린더
    static var localized: Calendar {
        var cal = Calendar.current
        let startWeekday = UserDefaults.standard.string(forKey: "startWeekday") ?? "월"
        cal.firstWeekday = startWeekday == "일" ? 1 : 2
        return cal
    }
}
