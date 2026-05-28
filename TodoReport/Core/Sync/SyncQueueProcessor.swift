import Foundation
import SwiftData

@MainActor
final class SyncQueueProcessor {
    static let shared = SyncQueueProcessor()
    private init() {}

    private var isProcessing = false
    private var context: ModelContext { PersistenceController.shared.context }

    func process() async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        do {
            let descriptor = FetchDescriptor<SyncQueueItem>(
                predicate: #Predicate<SyncQueueItem> { $0.status == "pending" },
                sortBy: [SortDescriptor(\.createdAt)]
            )
            let items = try context.fetch(descriptor)

            for item in items {
                item.status = "processing"
                try? context.save()

                do {
                    try await NotionAPIClient.shared.sync(
                        action: item.action,
                        entityType: item.entityType,
                        entityId: item.entityId,
                        payload: item.payload
                    )
                    context.delete(item)
                    try? context.save()
                } catch {
                    item.retryCount += 1
                    item.status = item.retryCount > 3 ? "failed" : "pending"
                    try? context.save()
                }
            }
        } catch {
            // fetch 실패 — 다음 실행 시 재시도
        }
    }
}
