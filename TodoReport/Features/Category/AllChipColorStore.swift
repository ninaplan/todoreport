import Foundation

/// 투두 탭 「전체」 필터 칩 색 — 플래너별 UserDefaults 저장 (기본 노크 오렌지).
enum AllChipColorStore {
    static let defaultHex = "#FD6845"

    private static func key(for plannerId: String) -> String {
        "allChipColorHex_\(plannerId)"
    }

    static func hex(for plannerId: String?) -> String {
        guard let plannerId else { return defaultHex }
        return UserDefaults.standard.string(forKey: key(for: plannerId)) ?? defaultHex
    }

    static func set(_ hex: String, for plannerId: String?) {
        guard let plannerId else { return }
        UserDefaults.standard.set(hex, forKey: key(for: plannerId))
    }
}
