import SwiftUI

@Observable
final class AppTheme {
    static let shared = AppTheme()

    static let accentHexKey = "appAccentColorHex"
    static let defaultAccentHex = "#FD6845"

    /// 설정 > 포인트 컬러 팔레트. 흰 글자가 잘 보이는 색만 (노랑처럼 밝은 색 제외).
    static let accentPalette: [AccentOption] = [
        AccentOption(hex: "#FD6845", name: String(localized: "노크 오렌지")),
        AccentOption(hex: "#FF3B30", name: String(localized: "빨강")),
        AccentOption(hex: "#FF9500", name: String(localized: "주황")),
        AccentOption(hex: "#34C759", name: String(localized: "초록")),
        AccentOption(hex: "#00C7BE", name: String(localized: "민트")),
        AccentOption(hex: "#30B0C7", name: String(localized: "청록")),
        AccentOption(hex: "#007AFF", name: String(localized: "파랑")),
        AccentOption(hex: "#5856D6", name: String(localized: "남색")),
        AccentOption(hex: "#AF52DE", name: String(localized: "보라")),
        AccentOption(hex: "#FF2D55", name: String(localized: "분홍")),
        AccentOption(hex: "#A2845E", name: String(localized: "갈색")),
        AccentOption(hex: "#636366", name: String(localized: "그래파이트"))
    ]

    /// 저장된 포인트 컬러 (#RRGGBB). 기본은 노크 오렌지.
    private(set) var accentHex: String

    /// 앱 전체 포인트 컬러. 설정에서 바꾸면 이 값을 읽는 화면이 바로 바뀐다.
    var accent: Color { Color(hex: accentHex) }

    /// 팔레트에 없는 색(직접 고르기)인지
    var isCustomAccent: Bool {
        !Self.accentPalette.contains { $0.hex == accentHex }
    }

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.accentHexKey)
        accentHex = stored.flatMap { Self.isValidHex($0) ? $0 : nil } ?? Self.defaultAccentHex
    }

    /// 팔레트 색 또는 직접 고른 색 (#RRGGBB)
    func setAccentHex(_ hex: String) {
        let normalized = hex.uppercased()
        guard Self.isValidHex(normalized) else { return }
        accentHex = normalized
        UserDefaults.standard.set(normalized, forKey: Self.accentHexKey)
    }

    private static func isValidHex(_ hex: String) -> Bool {
        hex.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil
    }
}
