import Foundation

/// 타임라인에 그릴 블록 한 칸 (블록 + 연결된 할 일 정보).
struct TimeBlockEntry: Identifiable, Equatable {
    let block: TimeBlock
    let title: String
    let isCompleted: Bool
    /// 카테고리가 없으면 nil → 흰 블록
    let categoryColorHex: String?
    /// 카테고리 아이콘 (SF Symbol). 미분류면 nil
    let categoryIcon: String?

    var id: String { block.id }

    func status(now: Date) -> TimeBlockStatus {
        if isCompleted { return .completed }
        let start = TimeBlockLayout.date(day: block.day, minute: block.startMinute)
        let end = TimeBlockLayout.date(day: block.day, minute: block.endMinute)
        if end <= now { return .missed }
        return start <= now ? .current : .planned
    }
}
