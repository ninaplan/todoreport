import Foundation

enum TodoEmptyStateKind {
    /// 필터된 목록에 항목이 있음
    case notEmpty
    /// 빈 목록 — 새로고침 안내 없음 (로컬·필터·성공한 0개·quiet 진행 중 등)
    case plain
    /// Notion pull 실패 후 — "목록이 안 보이나요?" 안내
    case notionPullHint
}
