import Foundation

@MainActor
enum TodoListDiff {
    /// Notion/백엔드 캐시 지연 동안 로컬 변경 항목을 서버 응답에서 누락돼도 유지
    static let localChangeGraceInterval: TimeInterval = 30

    static func contentEqual(_ lhs: Todo, _ rhs: Todo) -> Bool {
        lhs.title == rhs.title
            && lhs.memo == rhs.memo
            && lhs.isCompleted == rhs.isCompleted
            && lhs.isPinned == rhs.isPinned
            && Calendar.current.isDate(lhs.date, inSameDayAs: rhs.date)
            && lhs.categoryId == rhs.categoryId
            && lhs.notionPageId == rhs.notionPageId
            && lhs.scheduledTime == rhs.scheduledTime
            && lhs.alarmOffset == rhs.alarmOffset
    }

    static func hasChanges(current: [Todo], incoming: [Todo]) -> Bool {
        !sequenceEqual(merged(current: current, incoming: incoming), current)
    }

    /// 기존 순서를 유지하면서 변경·추가·삭제만 반영한다.
    /// 서버(incoming) 응답에 없더라도 로컬 전용·최근 변경 항목은 제거하지 않는다.
    static func merged(current: [Todo], incoming: [Todo]) -> [Todo] {
        var incomingById = Dictionary(uniqueKeysWithValues: incoming.map { ($0.id, $0) })
        var result: [Todo] = []

        for todo in current {
            if var updated = incomingById.removeValue(forKey: todo.id) {
                if let touch = todo.localModifiedAt {
                    updated.localModifiedAt = touch
                }
                result.append(updated)
            } else if shouldPreserveDespiteMissingFromIncoming(todo) {
                result.append(todo)
            }
        }

        let newItems = incoming.filter { item in
            !current.contains(where: { $0.id == item.id })
        }
        result.append(contentsOf: newItems)
        return result
    }

    /// incoming에 없는 current 항목을 화면에 유지할지 판단
    private static func shouldPreserveDespiteMissingFromIncoming(
        _ todo: Todo,
        now: Date = .now
    ) -> Bool {
        if todo.notionPageId.isEmpty { return true }

        let lastTouch = todo.localModifiedAt ?? todo.createdAt
        if now.timeIntervalSince(lastTouch) < localChangeGraceInterval { return true }

        let syncQueue = SyncQueueManager.shared
        if syncQueue.hasPendingCreate(for: todo.id) { return true }
        if syncQueue.hasPendingUpdate(for: todo.id) { return true }
        if !todo.notionPageId.isEmpty, syncQueue.hasPendingOperation(for: todo.notionPageId) {
            return true
        }

        return false
    }

    private static func sequenceEqual(_ lhs: [Todo], _ rhs: [Todo]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for (left, right) in zip(lhs, rhs) {
            if left.id != right.id || !contentEqual(left, right) { return false }
        }
        return true
    }
}
