import SwiftData
import Foundation

/// 타임라인 블록. 로컬 전용 — 노션에 올리지 않는다.
/// 할 일과는 `todoId`로만 연결한다 (할 일 모델·동기화 코드는 건드리지 않음).
@Model
final class TimeBlockItem {
    @Attribute(.unique) var id: String
    var plannerId: String?
    var todoId: String
    /// 블록이 속한 날의 0시 (`Calendar.startOfDay`).
    var day: Date
    /// 그날 0시부터 지난 분 (0...1440).
    var startMinute: Int
    var endMinute: Int
    /// 블록 시작 시각 알림 (기본 켜짐). 메뉴의 전체 끄기가 우선한다.
    var alarmEnabled: Bool = true
    /// 블록 끝 시각 알림. 블록별 기본은 켜짐이지만, 메뉴의 「블록 종료 알림」(기본 꺼짐)을 켜야 실제로 울린다.
    var endAlarmEnabled: Bool = true
    /// 이 블록만 완료 (한 할 일을 여러 블록에 넣었을 때 블록마다 체크). 그날 블록을 모두 체크하면 할 일도 완료
    var isCompleted: Bool = false
    /// 진행 중에 일찍 끝내 종료를 지금으로 줄였을 때 원래 계획한 종료 분. 줄인 적 없으면 nil
    /// (완료를 풀면 이 값으로 되돌림, 나중 「계획 vs 실제」용)
    var plannedEndMinute: Int? = nil
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        plannerId: String? = nil,
        todoId: String,
        day: Date,
        startMinute: Int,
        endMinute: Int,
        alarmEnabled: Bool = true,
        endAlarmEnabled: Bool = true
    ) {
        self.id = id
        self.plannerId = plannerId
        self.todoId = todoId
        self.day = day
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.alarmEnabled = alarmEnabled
        self.endAlarmEnabled = endAlarmEnabled
        self.createdAt = .now
    }
}
