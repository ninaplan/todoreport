import Foundation

/// 날짜·기간이 바뀔 때 본문 슬라이드 애니메이션을 다시 돌리는 신호. (투두·타임라인·리포트 공통)
/// direction: 1 = 다음(오른쪽에서 들어옴), -1 = 이전(왼쪽에서 들어옴)
struct DaySlide: Equatable {
    let token: Int
    let direction: Int
    /// 막 생긴 줄(새 날짜의 할 일)도 같은 슬라이드를 타도록, 신호가 언제 났는지 기록
    let startedAt: Date

    static let initial = DaySlide(token: 0, direction: 0, startedAt: .distantPast)

    func next(forward: Bool) -> DaySlide {
        DaySlide(token: token + 1, direction: forward ? 1 : -1, startedAt: .now)
    }

    /// 방금(0.3초 안) 난 신호인지
    var isRecent: Bool {
        token > 0 && Date.now.timeIntervalSince(startedAt) < 0.3
    }
}
