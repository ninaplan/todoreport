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

    /// ⋯ 메뉴 「블록 종료 알림」 (기본 꺼짐)
    var isEndGloballyEnabled: Bool {
        UserDefaults.standard.bool(forKey: TimeBlockLayout.endAlarmEnabledKey)
    }

    func setGloballyEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: TimeBlockLayout.startAlarmEnabledKey)
    }

    func setEndGloballyEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: TimeBlockLayout.endAlarmEnabledKey)
    }

    /// 조건이 맞으면 등록, 아니면 취소. 블록·할 일이 바뀔 때마다 호출한다. (시작·종료 알림 각각)
    func sync(block: TimeBlock, todo: Todo?) {
        let startId = Self.identifier(for: block.id)
        let endId = Self.endIdentifier(for: block.id)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [startId, endId])

        // 할 일 전체 완료 또는 이 블록만 완료면 알림 없음 (같은 할 일의 다른 블록 알림은 그대로)
        guard let todo, !todo.isCompleted, !block.isCompleted else { return }
        let startDate = TimeBlockLayout.date(day: block.day, minute: block.startMinute)
        let endDate = TimeBlockLayout.date(day: block.day, minute: block.endMinute)
        let startText = startDate.formatted(date: .omitted, time: .shortened)
        let endText = endDate.formatted(date: .omitted, time: .shortened)

        if isGloballyEnabled, block.alarmEnabled, startDate > .now, !isDuplicateOfTodoAlarm(todo: todo, fireDate: startDate) {
            add(
                identifier: startId,
                title: todo.title,
                body: String(localized: "\(startText) – \(endText) 블록을 시작할 시간입니다."),
                fireDate: startDate
            )
        }
        if isEndGloballyEnabled, block.endAlarmEnabled, endDate > .now {
            add(
                identifier: endId,
                title: todo.title,
                body: String(localized: "\(startText) – \(endText) 블록이 끝날 시간입니다."),
                fireDate: endDate
            )
        }
    }

    func cancel(blockIds: [String]) {
        guard !blockIds.isEmpty else { return }
        let ids = blockIds.flatMap { [Self.identifier(for: $0), Self.endIdentifier(for: $0)] }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// 할 일 자체 알림이 같은 시각에 울리면 블록 시작 알림은 생략 (두 번 울리지 않게)
    private func isDuplicateOfTodoAlarm(todo: Todo, fireDate: Date) -> Bool {
        guard let scheduled = todo.scheduledTime, todo.alarmOffset == 0 else { return false }
        return abs(scheduled.timeIntervalSince(fireDate)) < 60
    }

    private func add(identifier: String, title: String, body: String, fireDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    private static func endIdentifier(for blockId: String) -> String {
        identifierPrefix + "end-" + blockId
    }

    private static func identifier(for blockId: String) -> String {
        identifierPrefix + blockId
    }
}
