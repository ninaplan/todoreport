import Foundation
import SwiftData

final class TodoSearchService {
    static let shared = TodoSearchService()
    private init() {}

    private var context: ModelContext { PersistenceController.shared.context }

    func search(query: String) async -> [Todo] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }

        do {
            let titleDescriptor = FetchDescriptor<TodoItem>(
                predicate: #Predicate { $0.title.localizedStandardContains(needle) }
            )
            let memoPresentDescriptor = FetchDescriptor<TodoItem>(
                predicate: #Predicate { $0.memo != nil }
            )
            let titleMatches = try context.fetch(titleDescriptor)
            let memoMatches = try context.fetch(memoPresentDescriptor).filter { item in
                guard let memo = item.memo else { return false }
                return memo.localizedStandardContains(needle)
            }

            var seen = Set<String>()
            var merged: [TodoItem] = []
            for item in titleMatches + memoMatches {
                if seen.insert(item.id).inserted {
                    merged.append(item)
                }
            }

            return merged
                .sorted { lhs, rhs in
                    let left = lhs.date ?? lhs.createdAt
                    let right = rhs.date ?? rhs.createdAt
                    if left != right { return left > right }
                    return lhs.createdAt > rhs.createdAt
                }
                .map { $0.toTodo() }
        } catch {
            AppLogger.shared.error("Search", "할일 검색 실패: \(error.localizedDescription)")
            return []
        }
    }
}
