import SwiftData
import OSLog

private let logger = Logger(subsystem: "kr.nock.TodoReport", category: "Persistence")

final class PersistenceController {
    static let shared = PersistenceController()

    let container: ModelContainer
    // nil이면 정상, non-nil이면 영구 저장소 초기화 실패 → 앱이 에러 UI를 표시해야 함
    private(set) var initializationError: Error? = nil

    private init() {
        let schema = Schema([
            PlannerItem.self,
            TodoItem.self,
            DailyReportItem.self,
            CategoryItem.self,
            SyncQueueItem.self
        ])

        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            #if DEBUG
            fatalError("""
            [Persistence] ❌ SwiftData 영구 저장소 초기화 실패
            원인: \(error)
            → 스키마 변경 후 경량 마이그레이션 불가 시 발생.
              시뮬레이터: 앱 삭제 후 재설치로 해결.
              실기기: SyncQueueItem.requeueCount 등 @Attribute 기본값 누락 여부 확인.
            """)
            #else
            // 프로덕션: 앱 충돌을 막기 위한 최소 셸만 유지.
            // initializationError가 세팅되면 앱이 에러 UI를 표시하고 정상 플로우는 차단됨.
            logger.fault("[Persistence] ❌ ModelContainer 초기화 실패: \(error, privacy: .public)")
            initializationError = error

            let shellConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            guard let shell = try? ModelContainer(for: schema, configurations: shellConfig) else {
                // 스키마 자체가 깨진 경우 — 앱 기동 자체 불가, crash가 불가피
                fatalError("[Persistence] ❌ 인메모리 셸 생성도 실패 — 스키마 오류: \(error)")
            }
            container = shell
            #endif
        }
    }

    var context: ModelContext {
        container.mainContext
    }
}
