import Foundation

enum StreakCriteria: String, CaseIterable {
    case allPinnedCompleted
    case allCompleted
    case anyCompleted

    static let storageKey = "streakCriteria"

    static var current: StreakCriteria {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? ""
        return StreakCriteria(rawValue: raw) ?? .allCompleted
    }

    var displayName: String {
        switch self {
        case .allPinnedCompleted: return "중요 할 일 모두 완료"
        case .allCompleted: return "전체 할 일 완료"
        case .anyCompleted: return "할 일 1개 이상 완료"
        }
    }

    func isDaySatisfied(todos: [TodoItem]) -> Bool {
        switch self {
        case .allPinnedCompleted:
            let pinned = todos.filter(\.isPinned)
            guard !pinned.isEmpty else { return true }
            return pinned.allSatisfy(\.isCompleted)
        case .allCompleted:
            guard !todos.isEmpty else { return false }
            return todos.allSatisfy(\.isCompleted)
        case .anyCompleted:
            return todos.contains(where: \.isCompleted)
        }
    }
}
