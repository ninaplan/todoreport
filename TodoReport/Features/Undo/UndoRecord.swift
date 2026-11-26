import Foundation

/// 되돌릴 수 있는 직전 작업 1개.
/// 되돌리는 방법(`undo`)은 각 기능이 자기 서비스 함수로 만들어 넘긴다 → 노션·알림·위젯 경로가 평소와 같다.
struct UndoRecord {
    let id: UUID
    /// 작업한 플래너. 다른 플래너로 바뀐 뒤에는 되돌리지 않는다
    let plannerId: String?
    /// 흔들었을 때 확인 창 제목 한 줄 (예: 「'앱 홍보' 삭제를 되돌릴까요?」)
    let confirmTitle: String
    let undo: @MainActor () async -> Void
}
