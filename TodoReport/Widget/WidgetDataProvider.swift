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

@MainActor
final class WidgetDataProvider {
    static let shared = WidgetDataProvider()
    private init() {}

    static let appGroupId = "group.kr.nock.TodoReport"
    private static let entryKey = "widgetEntry"
    private static let isProKey = "widgetIsPro"

    /// 투두 탭 진입 없이도 오늘 데이터를 위젯에 반영 (앱 실행·포그라운드 복귀 시 호출)
    func refreshTodayFromStore() async {
        let todos = await TodoService.shared.fetchTodos(for: .now)
        let hideCompleted = UserDefaults.standard.bool(forKey: "todoHideCompleted")
        let listTodos = Self.widgetListTodos(from: todos, hideCompleted: hideCompleted)
        let plannerName = PlannerService.shared.selectedPlanner?.name ?? "내 플래너"
        update(allTodos: todos, listTodos: listTodos, plannerName: plannerName)
    }

    private static func widgetListTodos(from todos: [Todo], hideCompleted: Bool) -> [Todo] {
        func sortDate(_ todo: Todo) -> Date { todo.notionCreatedAt ?? todo.createdAt }
        let pinned = todos
            .filter { $0.isPinned && !$0.isCompleted }
            .sorted { sortDate($0) < sortDate($1) }
        let normal = todos
            .filter { !$0.isPinned && !$0.isCompleted }
            .sorted { sortDate($0) < sortDate($1) }
        let completed: [Todo] = hideCompleted ? [] :
            todos.filter(\.isCompleted)
                .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
        return pinned + normal + completed
    }

    func update(allTodos: [Todo], listTodos: [Todo], plannerName: String) {
        let widgetTodos = listTodos.prefix(10).map {
            WidgetTodo(id: $0.id, title: $0.title, isCompleted: $0.isCompleted, isPinned: $0.isPinned)
        }
        let completed = allTodos.filter(\.isCompleted).count
        let total = allTodos.count
        let entry = WidgetEntry(
            date: .now,
            plannerName: plannerName,
            completionRate: total == 0 ? 0 : Double(completed) / Double(total),
            completedCount: completed,
            totalCount: total,
            todos: Array(widgetTodos)
        )
        guard let defaults = UserDefaults(suiteName: Self.appGroupId) else {
            AppLogger.shared.error("WidgetDataProvider", "App Group 접근 실패 — entitlements의 group.kr.nock.TodoReport 확인")
            return
        }
        guard let data = try? JSONEncoder().encode(entry) else {
            AppLogger.shared.error("WidgetDataProvider", "위젯 데이터 인코딩 실패")
            return
        }
        defaults.set(data, forKey: Self.entryKey)
        let isPro = SubscriptionManager.shared.isPro
        defaults.set(isPro, forKey: Self.isProKey)
        WidgetCenter.shared.reloadAllTimelines()
        AppLogger.shared.info(
            "WidgetDataProvider",
            "위젯 갱신 - \(completed)/\(total) (\(Int(entry.completionRate * 100))%) isPro=\(isPro) planner=\(plannerName)"
        )
    }

    static func read() -> WidgetEntry? {
        guard let data = UserDefaults(suiteName: appGroupId)?.data(forKey: entryKey) else { return nil }
        return try? JSONDecoder().decode(WidgetEntry.self, from: data)
    }

    static func readIsPro() -> Bool {
        UserDefaults(suiteName: appGroupId)?.bool(forKey: isProKey) ?? false
    }

    func syncProStatus() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupId) else {
            AppLogger.shared.error("WidgetDataProvider", "App Group 접근 실패 — Pro 상태 동기화 불가")
            return
        }
        defaults.set(SubscriptionManager.shared.isPro, forKey: Self.isProKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func clear() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupId) else { return }
        defaults.removeObject(forKey: Self.entryKey)
        defaults.removeObject(forKey: Self.isProKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
