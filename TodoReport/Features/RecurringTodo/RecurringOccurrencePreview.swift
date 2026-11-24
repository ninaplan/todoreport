import Foundation

/// 미래 날짜에 보여주는 반복 할 일 미리보기 한 줄. 화면에만 그리고 저장·노션 동기화는 하지 않는다.
/// 진짜 할 일은 그날이 되면 만들어진다.
struct RecurringOccurrencePreview: Identifiable, Equatable {
    /// 시리즈 id
    let id: String
    let title: String
    let categoryId: String?
    let scheduledTime: Date?
}
