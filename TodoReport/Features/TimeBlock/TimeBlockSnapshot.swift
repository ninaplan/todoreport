import Foundation

/// 지우기 전 블록 모습 (실행 취소로 그대로 되살린다)
struct TimeBlockSnapshot {
    let id: String
    let plannerId: String?
    let todoId: String
    let day: Date
    let startMinute: Int
    let endMinute: Int
    let alarmEnabled: Bool
    let endAlarmEnabled: Bool
    let isCompleted: Bool
    let plannedEndMinute: Int?
    let createdAt: Date

    init(item: TimeBlockItem) {
        id = item.id
        plannerId = item.plannerId
        todoId = item.todoId
        day = item.day
        startMinute = item.startMinute
        endMinute = item.endMinute
        alarmEnabled = item.alarmEnabled
        endAlarmEnabled = item.endAlarmEnabled
        isCompleted = item.isCompleted
        plannedEndMinute = item.plannedEndMinute
        createdAt = item.createdAt
    }
}
