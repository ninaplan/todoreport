import Foundation

struct MoodOption: Identifiable, Equatable {
    let id: String
    var plannerId: String
    var name: String
    var colorHex: String
    var sortOrder: Int
    var notionOptionId: String?
    var notionOptionName: String?

    /// 이름에 이모지를 포함한다. 색은 앱에만 저장한다.
    static let defaultChoices: [(name: String, colorHex: String)] = [
        ("😆 최고", "#FFCC00"),
        ("🙂 좋음", "#34C759"),
        ("😐 보통", "#8E8E93"),
        ("😞 별로", "#FF9500"),
        ("😫 힘듦", "#FF3B30")
    ]
}
