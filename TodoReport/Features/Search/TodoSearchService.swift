import Foundation
import SwiftData

final class TodoSearchService {
    static let shared = TodoSearchService()
    private init() {}

    private var context: ModelContext { PersistenceController.shared.context }

    func search(query: String) async -> [SearchResultItem] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }

        let todos = searchTodos(needle: needle)
        let reviews = searchReviews(needle: needle)

        let merged: [SearchResultItem] =
            todos.map { .todo($0) }
            + reviews.map { .review(id: $0.id, date: $0.date, text: $0.review, plannerId: $0.plannerId) }

        return merged.sorted(by: Self.isOrderedBefore)
    }

    private func searchTodos(needle: String) -> [Todo] {
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

            return merged.map { $0.toTodo() }
        } catch {
            AppLogger.shared.error("Search", "할일 검색 실패: \(error.localizedDescription)")
            return []
        }
    }

    private func searchReviews(needle: String) -> [DailyReportItem] {
        do {
            let descriptor = FetchDescriptor<DailyReportItem>(
                predicate: #Predicate { $0.review.localizedStandardContains(needle) }
            )
            // 기간 리포트(endDate != nil)는 검색에서 제외 — 하루 리뷰만
            return try context.fetch(descriptor).filter { $0.endDate == nil }
        } catch {
            AppLogger.shared.error("Search", "하루 리뷰 검색 실패: \(error.localizedDescription)")
            return []
        }
    }

    private static func isOrderedBefore(_ lhs: SearchResultItem, _ rhs: SearchResultItem) -> Bool {
        if lhs.sortDate != rhs.sortDate { return lhs.sortDate > rhs.sortDate }
        switch (lhs, rhs) {
        case (.review, .todo):
            return true
        case (.todo, .review):
            return false
        case (.todo(let left), .todo(let right)):
            return left.createdAt > right.createdAt
        case (.review(let leftId, _, _, _), .review(let rightId, _, _, _)):
            return leftId > rightId
        }
    }
}
