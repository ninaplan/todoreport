import Foundation
import UserNotifications

final class ReportNotificationManager {
    static let shared = ReportNotificationManager()

    private let weeklyIdentifier = "report-save-reminder-weekly"
    private let monthlyFirstDayIdentifier = "report-save-reminder-monthly-first"

    private init() {}

    // MARK: - Public

    func rescheduleAll() {
        cancelAll()
        guard SubscriptionManager.shared.isPro else { return }
        guard PlannerService.shared.selectedPlanner?.isNotionConnected == true else { return }

        if ReportNotificationSettings.weeklyEnabled {
            scheduleWeekly()
        }
        if ReportNotificationSettings.monthlyEnabled {
            switch ReportNotificationSettings.monthlyTiming {
            case .firstDay:
                scheduleMonthlyFirstDay()
            case .lastDay:
                scheduleMonthlyLastDays()
            }
        }
    }

    func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [weeklyIdentifier, monthlyFirstDayIdentifier])
        let lastDayIds = Self.monthlyLastDayIdentifierCandidates(monthsAhead: 14)
        center.removePendingNotificationRequests(withIdentifiers: lastDayIds)
    }

    func ensureAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Scheduling

    private func scheduleWeekly() {
        var components = DateComponents()
        components.weekday = ReportNotificationSettings.weeklyWeekday
        components.hour = ReportNotificationSettings.hour
        components.minute = ReportNotificationSettings.minute

        let content = weeklyContent()
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: weeklyIdentifier, content: content, trigger: trigger)
        addRequest(request, label: "주간")
    }

    private func scheduleMonthlyFirstDay() {
        var components = DateComponents()
        components.day = 1
        components.hour = ReportNotificationSettings.hour
        components.minute = ReportNotificationSettings.minute

        let content = monthlyContent()
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: monthlyFirstDayIdentifier, content: content, trigger: trigger)
        addRequest(request, label: "월간(1일)")
    }

    private func scheduleMonthlyLastDays() {
        let calendar = Calendar.current
        let hour = ReportNotificationSettings.hour
        let minute = ReportNotificationSettings.minute
        var scheduled = 0

        for monthOffset in 0..<14 where scheduled < 4 {
            guard let monthStart = calendar.date(byAdding: .month, value: monthOffset, to: calendar.startOfDay(for: .now)),
                  let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else { continue }

            var components = calendar.dateComponents([.year, .month], from: monthStart)
            components.day = dayRange.count
            components.hour = hour
            components.minute = minute

            guard let fireDate = calendar.date(from: components), fireDate > .now else { continue }
            guard let year = components.year, let month = components.month else { continue }

            let identifier = Self.monthlyLastDayIdentifier(year: year, month: month)
            let content = monthlyContent()
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            addRequest(request, label: "월간(말일)")
            scheduled += 1
        }
    }

    private func weeklyContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "주간 리포트 저장 시간"
        content.body = "지난 주를 정리하고 노션에 저장해보세요."
        content.sound = .default
        return content
    }

    private func monthlyContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "월간 리포트 저장 시간"
        content.body = ReportNotificationSettings.monthlyTiming == .lastDay
            ? "이번 달을 정리하고 노션에 저장해보세요."
            : "지난 달을 정리하고 노션에 저장해보세요."
        content.sound = .default
        return content
    }

    private func addRequest(_ request: UNNotificationRequest, label: String) {
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                AppLogger.shared.error("ReportNotification", "\(label) 알림 등록 실패: \(error.localizedDescription)")
            }
        }
    }

    private static func monthlyLastDayIdentifier(year: Int, month: Int) -> String {
        "report-save-reminder-monthly-last-\(year)-\(month)"
    }

    private static func monthlyLastDayIdentifierCandidates(monthsAhead: Int) -> [String] {
        let calendar = Calendar.current
        return (0..<monthsAhead).compactMap { offset -> String? in
            guard let date = calendar.date(byAdding: .month, value: offset, to: .now) else { return nil }
            let comps = calendar.dateComponents([.year, .month], from: date)
            guard let year = comps.year, let month = comps.month else { return nil }
            return monthlyLastDayIdentifier(year: year, month: month)
        }
    }
}
