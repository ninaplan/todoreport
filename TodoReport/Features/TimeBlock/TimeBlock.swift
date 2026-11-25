import Foundation

/// 화면·로직용 블록 값. 저장은 `TimeBlockItem`.
struct TimeBlock: Identifiable, Equatable {
    let id: String
    var plannerId: String?
    var todoId: String
    var day: Date
    var startMinute: Int
    var endMinute: Int
    var alarmEnabled: Bool
    var endAlarmEnabled: Bool = true
    /// 블록 자체 완료 체크 (할 일 완료와 별개로 저장)
    var isCompleted: Bool = false
    /// 일찍 끝내 줄이기 전 원래 종료 분 (`TimeBlockItem.plannedEndMinute`)
    var plannedEndMinute: Int? = nil

    var durationMinutes: Int { endMinute - startMinute }

    /// 다른 블록과 시간이 겹치는지 (끝과 시작이 맞닿는 것은 겹침 아님)
    func overlaps(start: Int, end: Int) -> Bool {
        start < endMinute && end > startMinute
    }
}

extension TimeBlock {
    init(item: TimeBlockItem) {
        self.init(
            id: item.id,
            plannerId: item.plannerId,
            todoId: item.todoId,
            day: item.day,
            startMinute: item.startMinute,
            endMinute: item.endMinute,
            alarmEnabled: item.alarmEnabled,
            endAlarmEnabled: item.endAlarmEnabled,
            isCompleted: item.isCompleted,
            plannedEndMinute: item.plannedEndMinute
        )
    }
}
