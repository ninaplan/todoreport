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
    /// 할 일의 카테고리 id (편집 팝업에서 바꿀 때). 미분류면 nil
    var categoryId: String? = nil
    /// 할 일 메모 (투두 탭·노션과 같은 메모). 블록 안에 보여 준다
    var memo: String? = nil
    /// 반복 할 일이면 시리즈 id (삭제할 때 「이후 모두」를 물을지)
    var recurrenceId: String? = nil

    var id: String { block.id }

    func status(now: Date) -> TimeBlockStatus {
        if isCompleted { return .completed }
        let start = TimeBlockLayout.date(day: block.day, minute: block.startMinute)
        let end = TimeBlockLayout.date(day: block.day, minute: block.endMinute)
        if end <= now { return .missed }
        return start <= now ? .current : .planned
    }
}
