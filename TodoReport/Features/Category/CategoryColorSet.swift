import Foundation

/// 카테고리 색 세트 (노션 · 클래식 · 모던 · 파스텔 · 커스텀). 세트마다 12색. 커스텀만 맨 끝 칸이 「＋ 추가」.
/// 플래너마다 고른 세트를 `PlannerItem.categoryPaletteSetId`에 저장한다 (예전 팔레트 세트 칸을 다시 씀 → 저장 구조 그대로).
/// 커스텀은 사용자가 「＋ 추가」로 모은 색 (`CategoryCustomColorStore`, 앱 전체).
struct CategoryColorSet: Identifiable {
    let id: String
    let title: LocalizedStringResource
    /// 커스텀은 비워 두고 `colors(for:)`에서 저장된 색을 쓴다
    let presetColors: [String]

    static let basicId = "basic"
    static let notionId = "notion"
    static let customId = "custom"
    /// 앱 기본 세트 (새 플래너, 모르는 id)
    static let defaultId = notionId
    /// 한 세트의 칩 수 (6칸 × 2줄)
    static let colorCount = 12

    /// 탭 순서: 기본값인 노션이 맨 앞
    static let all: [CategoryColorSet] = [
        // 노션 글자색 9개 + 청록·남색·코랄 (노션 화면과 어울리는 차분한 톤)
        CategoryColorSet(id: notionId, title: "노션", presetColors: [
            "#C4554D", "#CC782F", "#C29343", "#548164", "#3E8E87", "#487CA5",
            "#4A5D8C", "#8A67AB", "#B35488", "#976D57", "#787774", "#D9735B",
        ]),
        CategoryColorSet(id: basicId, title: "클래식", presetColors: [
            "#FF3B30", "#FFCC00", "#34C759", "#00C7BE", "#007AFF", "#5856D6",
            "#AF52DE", "#FF2D55", "#A2845E", "#8E8E93", "#FD6845", "#000000",
        ]),
        CategoryColorSet(id: "modern", title: "모던", presetColors: [
            "#E5736B", "#EE9B5A", "#E6BF55", "#7DB88A", "#5BB5AC", "#5E9BD6",
            "#7C83DB", "#B07CD8", "#E07FA6", "#A8896C", "#8E9AAF", "#FD6845",
        ]),
        CategoryColorSet(id: "pastel", title: "파스텔", presetColors: [
            "#F28B82", "#F6AE6B", "#F2CC5B", "#9BCB8A", "#7FC8C0", "#8AB4F8",
            "#A79BE8", "#C9A0DC", "#E4A0C8", "#C9A98B", "#B0B3B8", "#FFB4A2",
        ]),
        CategoryColorSet(id: customId, title: "커스텀", presetColors: []),
    ]

    /// 세트의 색 (커스텀은 저장된 색). 모르는 id(예전 팔레트 세트 등)는 앱 기본(노션)
    static func colors(for id: String) -> [String] {
        if id == customId { return CategoryCustomColorStore.shared.colors }
        return (all.first { $0.id == id } ?? all[0]).presetColors
    }

    /// 알려진 세트 id인지 (예전 버전의 다른 세트 id는 앱 기본으로 본다)
    static func normalizedId(_ id: String?) -> String {
        guard let id, all.contains(where: { $0.id == id }) else { return defaultId }
        return id
    }

    /// 이 색이 들어 있는 세트 (노션 → 기본 → 모던 → 파스텔 → 커스텀 순). 없으면 nil
    static func setId(containing hex: String) -> String? {
        all.first { set in
            colors(for: set.id).contains { $0.uppercased() == hex.uppercased() }
        }?.id
    }
}
