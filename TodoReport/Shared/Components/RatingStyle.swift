import Foundation

/// 별점 아이콘·색 (플래너별). 아이콘이 nil이면 예전 그대로 ⭐ 이모지.
/// 화면 전용 — 노션 「별점」 값(⭐ 개수)은 그대로
struct RatingStyle: Equatable {
    /// SF Symbol 이름. nil = 기본 ⭐
    var icon: String?
    /// 사용자가 고른 색. nil = 아이콘별 기본색
    var colorHex: String?

    /// 지금 선택된 플래너의 별점 모양
    static var current: RatingStyle {
        let planner = PlannerService.shared.selectedPlanner
        return RatingStyle(icon: planner?.ratingIcon, colorHex: planner?.ratingColorHex)
    }

    /// 칠할 색 (고른 색 → 아이콘 기본색)
    var resolvedColorHex: String {
        colorHex ?? Self.defaultColorHex(for: icon)
    }

    /// 아이콘마다 어울리는 기본색. 색 고르기 탭이 바로 열리도록 「클래식」 세트 색을 쓴다.
    /// 정해지지 않은 아이콘은 포인트 컬러 (오렌지만 많아지지 않게 자주 쓰는 모양은 따로 정함)
    static func defaultColorHex(for icon: String?) -> String {
        guard let icon else { return AppTheme.shared.accentHex }
        let base = CategoryIconName.baseName(icon)
        for (keyword, hex) in keywordColors where base.contains(keyword) {
            return hex
        }
        return AppTheme.shared.accentHex
    }

    /// 앞에 있는 낱말이 먼저 맞는다 (예: `cloud.sun` → 해)
    private static let keywordColors: [(String, String)] = [
        ("heart", "#FF2D55"),
        ("bolt", "#FFCC00"),
        ("star", "#FFCC00"),
        ("sparkle", "#FFCC00"),
        ("face.smiling", "#FFCC00"),
        ("sun", "#FFCC00"),
        ("leaf", "#34C759"),
        ("tree", "#34C759"),
        ("camera.macro", "#34C759"),
        ("drop", "#007AFF"),
        ("snowflake", "#007AFF"),
        ("cloud", "#007AFF"),
        ("moon", "#5856D6"),
        ("bed", "#5856D6"),
        ("music", "#AF52DE"),
        ("flame", "#FF3B30"),
        ("cup", "#A2845E"),
        ("mug", "#A2845E"),
    ]
}
