import Foundation

struct CategoryPaletteSet: Identifiable, Hashable {
    let id: String
    let displayName: String
    let colors: [String]

    static let defaultId = "basic"

    static let all: [CategoryPaletteSet] = [
        CategoryPaletteSet(
            id: "basic",
            displayName: "기본",
            colors: [
                "#FF3B30", "#FF9500", "#FFCC00", "#34C759",
                "#00C7BE", "#007AFF", "#5856D6", "#AF52DE",
                "#FF2D55", "#A2845E", "#8E8E93", "#FD6845"
            ]
        ),
        CategoryPaletteSet(
            id: "warm",
            displayName: "웜",
            colors: [
                "#E4572E", "#F07A3D", "#F49D37", "#EFB93B",
                "#D98C45", "#C76B4A", "#BF5540", "#D9694C",
                "#E08F6A", "#C98A5E", "#A96D42", "#8E5A3C"
            ]
        ),
        CategoryPaletteSet(
            id: "cool",
            displayName: "쿨",
            colors: [
                "#2E8B8B", "#37A0A8", "#3B9BC7", "#3D7FC4",
                "#4C63C7", "#5E8BD9", "#3FA98C", "#4FB59E",
                "#6AB5C9", "#5A7FD9", "#7A8CD1", "#468C6E"
            ]
        ),
        CategoryPaletteSet(
            id: "pastel",
            displayName: "파스텔",
            colors: [
                "#F5A3A3", "#F7B9A0", "#F7D6A0", "#F3E3A3",
                "#CFE3A3", "#A9DDB4", "#A3DAD2", "#A9CCE8",
                "#B3BEEA", "#C9B6E4", "#E3B4DD", "#EBB0C6"
            ]
        ),
        CategoryPaletteSet(
            id: "vivid",
            displayName: "비비드",
            colors: [
                "#FF2D55", "#FF3B30", "#FF6B00", "#FF9F0A",
                "#FFCC00", "#34C759", "#00C7BE", "#30B0FF",
                "#0A84FF", "#5E5CE6", "#BF5AF2", "#FF375F"
            ]
        ),
        CategoryPaletteSet(
            id: "muted",
            displayName: "뮤트",
            colors: [
                "#C98B84", "#CDA188", "#CBB58C", "#C3C395",
                "#A9BE9E", "#93B7AE", "#9BB4C9", "#A6A6C9",
                "#B79BC0", "#C79BB0", "#B0A08C", "#9C9C9C"
            ]
        ),
        CategoryPaletteSet(
            id: "neutral",
            displayName: "뉴트럴",
            colors: [
                "#3A3A3C", "#545456", "#6E6E70", "#8A8A8C",
                "#A6A6A8", "#C2C2C4", "#5C534A", "#766B5E",
                "#918473", "#AB9E8C", "#C4B9A8", "#6B5D50"
            ]
        ),
        CategoryPaletteSet(
            id: "candy",
            displayName: "캔디",
            colors: [
                "#FF6B8A", "#FF8FA3", "#FFA45B", "#FFCB47",
                "#FFE156", "#9EE37D", "#5FD9B0", "#4EC5E0",
                "#6C8CFF", "#A981F0", "#D67CE8", "#FF9EC4"
            ]
        ),
        CategoryPaletteSet(
            id: "vintage",
            displayName: "빈티지",
            colors: [
                "#B5553F", "#C9884E", "#C9A24B", "#A6A44E",
                "#7C9070", "#5E8577", "#6E8CA0", "#8C7BA6",
                "#B06E8C", "#A65A5A", "#9C7B54", "#7A6A57"
            ]
        ),
    ]

    static func set(id: String) -> CategoryPaletteSet {
        all.first(where: { $0.id == id }) ?? all[0]
    }

    /// 미사용 색 우선. 12색이 모두 쓰이면 세트 내에서 랜덤.
    func pickColor(used: Set<String>) -> String {
        let usedNormalized = Set(used.map { $0.uppercased() })
        let unused = colors.filter { !usedNormalized.contains($0.uppercased()) }
        if let pick = unused.randomElement() {
            return pick
        }
        return colors.randomElement() ?? colors[0]
    }
}
