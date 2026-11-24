import Foundation
import UserNotifications

/// 블록 시작 알림. 할 일 알림(`TodoNotificationManager`, identifier = todo.id)과 따로 관리한다.
final class TimeBlockNotificationManager {
    static let shared = TimeBlockNotificationManager()
    private init() {}

    private static let identifierPrefix = "timeblock-"

    /// ⋯ 메뉴 「블록 시작 알림」 (기본 켜짐)
    var isGloballyEnabled: Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: TimeBlockLayout.startAlarmEnabledKey) != nil else { return true }
        return defaults.bool(forKey: TimeBlockLayout.startAlarmEnabledKey)
    }

    func setGloballyEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: TimeBlockLayout.startAlarmEnabledKey)
    }

    /// 조건이 맞으면 등록, 아니면 취소. 블록·할 일이 바뀔 때마다 호출한다.
    func sync(block: TimeBlock, todo: Todo?) {
        let identifier = Self.identifier(for: block.id)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard isGloballyEnabled, block.alarmEnabled, let todo, !todo.isCompleted else { return }
        let fireDate = TimeBlockLayout.date(day: block.day, minute: block.startMinute)
        guard fireDate > .now else { return }

        // 할 일 자체 알림이 같은 시각에 울리면 블록 알림은 생략 (두 번 울리지 않게)
        if let scheduled = todo.scheduledTime, todo.alarmOffset == 0,
           abs(scheduled.timeIntervalSince(fireDate)) < 60 {
            return
        }

        let start = fireDate.formatted(date: .omitted, time: .shortened)
        let end = TimeBlockLayout.date(day: block.day, minute: block.endMinute)
            .formatted(date: .omitted, time: .shortened)
        let content = UNMutableNotificationContent()
        content.title = todo.title
        content.body = String(localized: "\(start) – \(end) 블록을 시작할 시간입니다.")
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    func cancel(blockIds: [String]) {
        guard !blockIds.isEmpty else { return }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: blockIds.map(Self.identifier(for:)))
    }

    private static func identifier(for blockId: String) -> String {
        identifierPrefix + blockId
    }
}
