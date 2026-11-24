import Foundation

/// 블록 상태. 색은 카테고리, 상태는 글자(연함·줄긋기)로만 표현한다.
enum TimeBlockStatus: Equatable {
    /// 아직 끝나지 않았고 미완료
    case planned
    /// 지금 시각이 블록 안에 있고 미완료 → 카드 색칠 + 「진행 중」
    case current
    /// 할 일 완료 → 연한 글자 + 줄긋기
    case completed
    /// 끝난 시각이 지났는데 미완료 → 연한 글자
    case missed
}
