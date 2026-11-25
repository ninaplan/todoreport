import UIKit

/// 카테고리 아이콘 이름 다루기. 채움·라인은 카테고리마다 저장된 이름 자체로 정한다
/// (`book.fill` = 채움, `book` = 라인). 저장 구조는 그대로라 데이터 이전이 없다.
/// 새 카테고리 기본은 채움. 채움 모양이 없는 아이콘(`checklist` 등)은 라인으로만 저장된다.
enum CategoryIconName {
    /// `house.fill` → `house` (같은 아이콘인지 비교할 때)
    nonisolated static func baseName(_ name: String) -> String {
        name.hasSuffix(".fill") ? String(name.dropLast(5)) : name
    }

    static func isFilled(_ name: String) -> Bool {
        name.hasSuffix(".fill")
    }

    /// 기본 이름 + 모양 → 저장할 이름 (채움 모양이 없으면 라인 이름)
    static func make(base: String, filled: Bool) -> String {
        let plain = baseName(base)
        guard filled else { return exists(plain) ? plain : base }
        let filledName = plain + ".fill"
        return exists(filledName) ? filledName : plain
    }

    /// 화면에 그릴 이름. 저장된 이름이 이 기기에 없으면 다른 모양, 그래도 없으면 태그
    static func resolved(_ stored: String) -> String {
        if exists(stored) { return stored }
        let plain = baseName(stored)
        if exists(plain) { return plain }
        if exists(plain + ".fill") { return plain + ".fill" }
        return "tag.fill"
    }

    // MARK: - 있는 이름인지 (한 번 확인한 건 기억)

    private static var existsCache: [String: Bool] = [:]

    private static func exists(_ name: String) -> Bool {
        if let cached = existsCache[name] { return cached }
        let result = UIImage(systemName: name) != nil
        existsCache[name] = result
        return result
    }
}
