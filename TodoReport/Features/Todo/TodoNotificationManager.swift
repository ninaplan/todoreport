import UserNotifications
import Foundation

final class TodoNotificationManager {
    static let shared = TodoNotificationManager()
    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("[Notification] ⚠️ 권한 요청 실패 - \(error.localizedDescription)")
            } else {
                print("[Notification] ✅ 권한 요청 완료 - granted: \(granted)")
            }
        }
    }

    func schedule(for todo: Todo) {
        // 완료된 투두 → 알림 명시적 취소
        if todo.isCompleted {
            cancel(for: todo.id)
            print("[Notification] ✅ 완료로 인한 알림 취소 - id:\(todo.id)")
            return
        }
        guard let scheduledTime = todo.scheduledTime,
              let alarmOffset = todo.alarmOffset else {
            // scheduledTime/alarmOffset 미설정 — 기존 알림 유지 (의도치 않은 nil 업데이트 방지)
            print("[Notification] ⏭️ 스킵 - id:\(todo.id) scheduledTime:\(String(describing: todo.scheduledTime)) alarmOffset:\(String(describing: todo.alarmOffset))")
            return
        }

        print("[Notification] 📅 등록 시도 - id:\(todo.id) time:\(scheduledTime) offset:\(alarmOffset)")

        let fireDate = scheduledTime.addingTimeInterval(TimeInterval(-alarmOffset * 60))
        guard fireDate > .now else {
            cancel(for: todo.id)
            print("[Notification] ⏭️ 스킵 - 과거 시간 fireDate:\(fireDate)")
            return
        }

        cancel(for: todo.id)  // 재등록 직전에만 취소

        let content = UNMutableNotificationContent()
        content.title = todo.title
        if let memo = todo.memo, !memo.isEmpty { content.body = memo }
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let identifier = todo.id
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[Notification] ❌ 등록 실패 - \(error)")
            } else {
                print("[Notification] ✅ 등록 완료 - identifier:\(identifier) fireDate:\(fireDate)")
            }
        }
    }

    func cancel(for todoId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [todoId])
    }
}
