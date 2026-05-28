import Foundation

// Notion API 호출 단일 창구 (실제 호출은 Next.js 백엔드 경유)
final class NotionAPIClient {
    static let shared = NotionAPIClient()
    private init() {}

    /// 투두/리포트 변경사항을 Notion에 반영. 현재는 placeholder.
    func sync(action: String, entityType: String, entityId: String, payload: Data) async throws {
        // TODO: APIClient.shared.post("/api/sync", body: ...) 형태로 구현
    }
}
