import Foundation

struct MoodOption: Identifiable, Equatable {
    let id: String
    var plannerId: String
    var name: String
    var colorHex: String
    var sortOrder: Int
    var notionOptionId: String?
    var notionOptionName: String?
    /// 기본 선택지 키. 사용자가 이름을 바꾸면 nil.
    var defaultKey: String?

    /// storedName은 저장값. names는 기존 기록에서 키를 되찾을 때 쓰는 한국어·영어 이름.
    static let defaultChoices: [(key: String, colorHex: String, storedName: String, names: Set<String>)] = [
        ("great", "#FFCC00", "😆 최고", ["😆 최고", "😆 Great"]),
        ("good", "#34C759", "🙂 좋음", ["🙂 좋음", "🙂 Good"]),
        ("okay", "#8E8E93", "😐 보통", ["😐 보통", "😐 Okay"]),
        ("bad", "#FF9500", "😞 별로", ["😞 별로", "😞 Bad"]),
        ("rough", "#FF3B30", "😫 힘듦", ["😫 힘듦", "😫 Rough"])
    ]

    static func localizedName(for key: String) -> String? {
        switch key {
        case "great": return String(localized: "😆 최고")
        case "good": return String(localized: "🙂 좋음")
        case "okay": return String(localized: "😐 보통")
        case "bad": return String(localized: "😞 별로")
        case "rough": return String(localized: "😫 힘듦")
        default: return nil
        }
    }

    static func defaultKey(matching name: String) -> String? {
        let trimmed = normalized(name)
        guard !trimmed.isEmpty else { return nil }
        return defaultChoices.first { choice in
            choice.names.contains { normalized($0) == trimmed }
        }?.key
    }

    /// 칩·메뉴·편집·과거 기록(스냅샷)이 같이 쓰는 표시 이름.
    /// 노션 모드가 아니고, 기본 키가 있거나 저장 이름이 아직 기본 이름이면 현재 언어.
    /// 이름을 바꾸면 키가 지워지고 저장 이름도 기본 목록에서 빠지므로 저장 이름을 그대로 쓴다.
    static func displayName(storedName: String, defaultKey: String?, mode: MoodStorageMode?) -> String {
        let trimmed = storedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let visible = trimmed.isEmpty ? storedName : trimmed
        guard mode != .notion else { return visible }
        let matchedKey = Self.defaultKey(matching: visible)
        if defaultKey != nil, matchedKey == nil {
            return visible
        }
        let key = defaultKey ?? matchedKey
        guard let key, let localized = localizedName(for: key) else { return visible }
        return localized
    }

    func displayName(mode: MoodStorageMode?) -> String {
        Self.displayName(storedName: name, defaultKey: defaultKey, mode: mode)
    }

    private static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
    }

    /// 카테고리 기본 12색과 같은 값. 기분 모듈이 카테고리 타입에 의존하지 않도록 따로 둔다.
    static let palette: [String] = [
        "#FF3B30", "#FFCC00", "#34C759", "#00C7BE",
        "#007AFF", "#5856D6", "#AF52DE", "#FF2D55",
        "#A2845E", "#8E8E93", "#FD6845", "#000000"
    ]

    static func pickColor(used: Set<String>) -> String {
        let usedNormalized = Set(used.map { $0.uppercased() })
        let unused = palette.filter { !usedNormalized.contains($0.uppercased()) }
        if let pick = unused.randomElement() {
            return pick
        }
        return palette.randomElement() ?? palette[0]
    }
}
