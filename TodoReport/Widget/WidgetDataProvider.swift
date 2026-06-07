import Foundation
import WidgetKit

// MARK: - 위젯 공유 모델 (App + Widget Extension 양쪽에서 사용)

struct WidgetEntry: Codable {
    let date: Date
    let plannerName: String
    let completionRate: Double
    let completedCount: Int
    let totalCount: Int
    let todos: [WidgetTodo]
}

struct WidgetTodo: Codable, Identifiable {
    let id: String
    let title: String
    let isCompleted: Bool
    let isPinned: Bool
}

// MARK: - Provider (앱에서만 사용 — 위젯은 read() 만 사용)

final class WidgetDataProvider {
    static let shared = WidgetDataProvider()
    private init() {}

    static let appGroupId = "group.kr.nock.TodoReport"
    private static let entryKey = "widgetEntry"
    private static let isProKey = "widgetIsPro"

    func update(todos: [Todo], plannerName: String) {
        let widgetTodos = todos.prefix(10).map {
            WidgetTodo(id: $0.id, title: $0.title, isCompleted: $0.isCompleted, isPinned: $0.isPinned)
        }
        let completed = widgetTodos.filter(\.isCompleted).count
        let total     = widgetTodos.count
        let entry = WidgetEntry(
            date: .now,
            plannerName: plannerName,
            completionRate: total == 0 ? 0 : Double(completed) / Double(total),
            completedCount: completed,
            totalCount: total,
            todos: Array(widgetTodos)
        )
        guard let data = try? JSONEncoder().encode(entry),
              let defaults = UserDefaults(suiteName: Self.appGroupId) else { return }
        defaults.set(data, forKey: Self.entryKey)
        defaults.set(SubscriptionManager.shared.isPro, forKey: Self.isProKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func read() -> WidgetEntry? {
        guard let data = UserDefaults(suiteName: appGroupId)?.data(forKey: entryKey) else { return nil }
        return try? JSONDecoder().decode(WidgetEntry.self, from: data)
    }

    static func readIsPro() -> Bool {
        UserDefaults(suiteName: appGroupId)?.bool(forKey: isProKey) ?? false
    }

    func clear() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupId) else { return }
        defaults.removeObject(forKey: Self.entryKey)
        defaults.removeObject(forKey: Self.isProKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
