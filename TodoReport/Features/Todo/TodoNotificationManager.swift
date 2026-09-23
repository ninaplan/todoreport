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
        guard let scheduledTime = todo.scheduledTime else {
            // scheduledTime 미설정 — 기존 알림 유지 (의도치 않은 nil 업데이트 방지)
            print("[Notification] ⏭️ 스킵 - id:\(todo.id) scheduledTime:nil alarmOffset:\(String(describing: todo.alarmOffset))")
            return
        }
        guard let alarmOffset = todo.alarmOffset else {
            cancel(for: todo.id)
            print("[Notification] ✅ 알림 없음으로 취소 - id:\(todo.id)")
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
        content.body = scheduleTimeText(scheduledTime: scheduledTime, fireDate: fireDate)
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

    /// 알림이 울리는 날과 할 일 예정일의 날짜 차이로 상대 날짜를 붙인다. `Date.now`와는 비교하지 않는다.
    private func scheduleTimeText(scheduledTime: Date, fireDate: Date) -> String {
        let calendar = Calendar.current
        let fireDay = calendar.startOfDay(for: fireDate)
        let dueDay = calendar.startOfDay(for: scheduledTime)
        let dayDiff = calendar.dateComponents([.day], from: fireDay, to: dueDay).day ?? 0
        let timeText = scheduledTime.formatted(.dateTime.hour().minute())

        switch dayDiff {
        case 0:
            return String(localized: "오늘 \(timeText)")
        case 1:
            return String(localized: "내일 \(timeText)")
        case 2:
            return String(localized: "모레 \(timeText)")
        default:
            let dateText = scheduledTime.formatted(.dateTime.month().day())
            let weekdayText = scheduledTime.formatted(.dateTime.weekday(.abbreviated))
            return "\(dateText) (\(weekdayText)) \(timeText)"
        }
    }

    func cancel(for todoId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [todoId])
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
