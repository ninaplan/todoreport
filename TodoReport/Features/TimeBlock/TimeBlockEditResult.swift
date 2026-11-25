import Foundation

/// 블록 편집 팝업에서 ✓를 눌렀을 때 넘기는 값.
/// 시각·알림은 블록에, 이름·카테고리는 할 일에 저장한다 (할 일은 투두 탭·노션과 공유).
struct TimeBlockEditResult {
    let start: Date
    let end: Date
    let startAlarm: Bool
    let endAlarm: Bool
    let title: String
    let categoryId: String?
}
