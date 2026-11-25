import Foundation

/// 블록에 넣을 할 일 고르기 창의 한 줄.
struct TimeBlockTodoOption: Identifiable, Equatable {
    let id: String
    let title: String
    let isCompleted: Bool
    /// 이미 들어간 블록들의 시작 분 (오름차순). 비어 있으면 아직 안 넣은 할 일.
    let placedStartMinutes: [Int]
    /// 이 할 일이 그날 들어간 블록 길이 합 (분). 고르기 창 오른쪽에 「1h30m」로 보여 준다
    var placedTotalMinutes: Int = 0

    var isPlaced: Bool { !placedStartMinutes.isEmpty }

    /// 1h30m / 분이 0이면 1h / 1시간 미만이면 45m (리포트 집중 시간과 같은 규칙)
    var placedTotalText: String {
        let hours = placedTotalMinutes / 60
        let rest = placedTotalMinutes % 60
        if hours == 0 { return "\(rest)m" }
        return rest == 0 ? "\(hours)h" : "\(hours)h\(rest)m"
    }
}
