import Foundation

/// 타임라인에 그릴 블록 한 칸 (블록 + 연결된 할 일 정보).
struct TimeBlockEntry: Identifiable, Equatable {
    let block: TimeBlock
    let title: String
    let isCompleted: Bool
    /// 카테고리가 없으면 nil → 흰 블록
    let categoryColorHex: String?

    var id: String { block.id }

    func status(now: Date) -> TimeBlockStatus {
        if isCompleted { return .completed }
        let end = TimeBlockLayout.date(day: block.day, minute: block.endMinute)
        return end <= now ? .missed : .planned
    }
}
