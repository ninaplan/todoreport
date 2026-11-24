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
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        plannerId: String? = nil,
        todoId: String,
        day: Date,
        startMinute: Int,
        endMinute: Int
    ) {
        self.id = id
        self.plannerId = plannerId
        self.todoId = todoId
        self.day = day
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.createdAt = .now
    }
}
