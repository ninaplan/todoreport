import SwiftData
import Foundation

@Model
final class SyncQueueItem {
    @Attribute(.unique) var id: String
    var action: String      // "create" / "update" / "delete"
    var entityType: String  // "todo" / "dailyReport"
    var entityId: String
    var payload: Data
    var retryCount: Int
    @Attribute var requeueCount: Int = 0   // create 미완료로 인한 update 재배치 횟수
    var status: String      // "pending" / "processing" / "failed"
    var createdAt: Date
    var plannerId: String?

    init(
        id: String = UUID().uuidString,
        action: String,
        entityType: String,
        entityId: String,
        payload: Data,
        retryCount: Int = 0,
        requeueCount: Int = 0,
        status: String = "pending",
        createdAt: Date = .now,
        plannerId: String? = nil
    ) {
        self.id = id
        self.action = action
        self.entityType = entityType
        self.entityId = entityId
        self.payload = payload
        self.retryCount = retryCount
        self.requeueCount = requeueCount
        self.status = status
        self.createdAt = createdAt
        self.plannerId = plannerId
    }
}
