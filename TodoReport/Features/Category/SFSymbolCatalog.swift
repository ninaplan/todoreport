import Foundation

/// 아이콘 「더 찾기」용 SF Symbols 목록 (`SFSymbolCatalog.json`, 이름 + 영어 검색어).
/// 맥의 SF Symbols 목록에서 만든 것: 언어별 변형·애플 제품 아이콘은 빼고, 채움 변형은 라인 이름 하나로 합침
/// (채움·라인은 카테고리마다 고름). 처음 검색할 때 한 번만 읽는다.
enum SFSymbolCatalog {
    private struct Entry {
        let name: String
        /// 이름 + 검색어 (소문자, 띄어쓰기로 이음)
        let searchText: String
    }

    private static let entries: [Entry] = {
        guard let url = Bundle.main.url(forResource: "SFSymbolCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let rows = try? JSONDecoder().decode([[String]].self, from: data) else { return [] }
        return rows.compactMap { row in
            guard let name = row.first else { return nil }
            let keywords = row.count > 1 ? row[1] : ""
            let text = (name.replacingOccurrences(of: ".", with: " ") + " " + keywords).lowercased()
            return Entry(name: name, searchText: text)
        }
    }()

    /// 검색어에 맞는 아이콘 이름. 한국어는 이름 추정 낱말 사전에 있는 말만 (예: 고양이 → cat)
    static func search(_ query: String, limit: Int = 60) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return [] }
        var result: [String] = []
        var seen = Set<String>()
        func add(_ name: String) {
            guard result.count < limit, seen.insert(name).inserted else { return }
            result.append(name)
        }
        // 1) 한국어 낱말 사전에 맞는 아이콘을 맨 앞에
        if let guessed = CategoryIconGuesser.icon(for: trimmed) {
            add(guessed)
        }
        // 2) 이름이 검색어로 시작하는 것 → 3) 이름·검색어 어디든 들어 있는 것
        let terms = trimmed.split(separator: " ").map(String.init)
        for entry in entries where entry.name.hasPrefix(trimmed) {
            add(entry.name)
        }
        for entry in entries where terms.allSatisfy({ entry.searchText.contains($0) }) {
            add(entry.name)
        }
        return result
    }
}
