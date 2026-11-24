import Foundation

/// 반복 규칙 백업 한 건. iCloud 키-값 저장소에 JSON 배열로 저장한다.
/// 기기마다 바뀌는 id(플래너·카테고리) 대신 재설치 후에도 같은 값으로 다시 찾는다.
struct RecurringSeriesBackup: Codable, Equatable {
    /// 시리즈 id (재설치 후에도 같은 id로 되살림 → 할 일의 recurrenceId와 다시 맞물림)
    let id: String
    /// 노션 투두 DB id — 재설치하면 플래너 id가 바뀌므로 이것으로 같은 플래너를 찾는다
    let plannerKey: String
    let title: String
    let memo: String?
    /// 카테고리도 재설치 후 id가 바뀌므로 노션 옵션 id → 이름 순으로 다시 찾는다
    let categoryNotionOptionId: String?
    let categoryName: String?
    let scheduledTime: Date?
    let alarmOffset: Int?
    let ruleData: Data
    let originDate: Date
    let endDate: Date?
    let occurrenceLimit: Int?
    let isActive: Bool
    /// 되살린 뒤 지난 날짜의 할 일을 다시 만들지 않도록 함께 저장
    let lastMaterializedThrough: Date?
}
