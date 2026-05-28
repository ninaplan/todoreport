import SwiftData
import Foundation

// SyncQueue 모델 — 다음 단계에서 SyncManager와 연동
@Model
final class SyncQueueItem {
    @Attribute(.unique) var id: String
    var type: String       // "createTodo" | "updateTodo" | "deleteTodo" | "saveDailyReport"
    var payload: Data      // JSON 인코딩된 엔티티
    var createdAt: Date
    var retryCount: Int

    init(
        id: String = UUID().uuidString,
        type: String,
        payload: Data,
        createdAt: Date = .now,
        retryCount: Int = 0
    ) {
        self.id = id
        self.type = type
        self.payload = payload
        self.createdAt = createdAt
        self.retryCount = retryCount
    }
}
