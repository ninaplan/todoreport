import Foundation

/// 블록에 넣을 할 일 고르기 창의 한 줄.
struct TimeBlockTodoOption: Identifiable, Equatable {
    let id: String
    let title: String
    let isCompleted: Bool
    /// 이미 들어간 블록들의 시작 분 (오름차순). 비어 있으면 아직 안 넣은 할 일.
    let placedStartMinutes: [Int]

    var isPlaced: Bool { !placedStartMinutes.isEmpty }
}
