import Foundation
import Observation

/// 「커스텀」 색 세트: 「＋ 추가」로 모은 색을 모아 둔다 (앱 전체, 기기에만 저장).
/// 최근 색이 앞, 최대 11개(12칸 중 맨 끝은 「＋ 추가」), 같은 색은 한 번만. 넘치면 가장 오래된 색이 빠진다.
@Observable
final class CategoryCustomColorStore {
    static let shared = CategoryCustomColorStore()
    static let maxCount = 11
    private static let key = "categoryCustomColors"

    private(set) var colors: [String]

    private init() {
        colors = UserDefaults.standard.stringArray(forKey: Self.key) ?? []
    }

    func add(_ hex: String) {
        let upper = hex.uppercased()
        var next = colors.filter { $0.uppercased() != upper }
        next.insert(hex, at: 0)
        colors = Array(next.prefix(Self.maxCount))
        save()
    }

    func remove(_ hex: String) {
        colors.removeAll { $0.uppercased() == hex.uppercased() }
        save()
    }

    private func save() {
        UserDefaults.standard.set(colors, forKey: Self.key)
    }
}
