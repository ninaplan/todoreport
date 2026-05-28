import SwiftData

final class PersistenceController {
    static let shared = PersistenceController()

    let container: ModelContainer

    private init() {
        let schema = Schema([
            TodoItem.self,
            DailyReportItem.self,
            CategoryItem.self,
            SyncQueueItem.self
        ])

        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        if let c = try? ModelContainer(for: schema, configurations: config) {
            container = c
        } else {
            // 영구 저장 실패 시 인메모리로 폴백 (예: 디스크 쓰기 권한 없음)
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                container = try ModelContainer(for: schema, configurations: fallback)
            } catch {
                // 스키마 자체가 잘못된 경우 — 개발 중 발생, 출시 빌드에서는 절대 도달하지 않음
                preconditionFailure("SwiftData 스키마 초기화 실패: \(error)")
            }
        }
    }

    var context: ModelContext {
        container.mainContext
    }
}
