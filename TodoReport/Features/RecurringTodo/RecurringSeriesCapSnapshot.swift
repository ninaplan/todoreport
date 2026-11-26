import Foundation

/// 「이후 반복 모두 삭제」 전 모습 (실행 취소용) — 반복 규칙의 끝 날짜·활성 상태 + 지워질 할 일들
struct RecurringSeriesCapSnapshot {
    let seriesId: String
    let endDate: Date?
    let isActive: Bool
    let todos: [Todo]
}
