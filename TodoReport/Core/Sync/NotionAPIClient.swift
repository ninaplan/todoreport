import Foundation

@MainActor
final class NotionAPIClient {
    static let shared = NotionAPIClient()
    private init() {}

    func sync(action: String, entityType: String, entityId: String, payload: Data, planner: Planner) async throws -> SyncResult {
        do {
            switch (entityType, action) {
            case ("todo", "create"):
                return try await syncTodoCreate(payload: payload, planner: planner)
            case ("todo", "update"):
                return try await syncTodoUpdate(entityId: entityId, payload: payload, planner: planner)
            case ("todo", "delete"):
                try await syncTodoDelete(entityId: entityId, planner: planner)
                return SyncResult(pageId: nil, lastEditedTime: nil)
            case ("dailyReport", "create"), ("dailyReport", "update"):
                try await syncDailyReport(payload: payload, planner: planner)
                return SyncResult(pageId: nil, lastEditedTime: nil)
            default:
                return SyncResult(pageId: nil, lastEditedTime: nil)
            }
        } catch {
            print("[Sync] ❌ 실패 상세 - \(error)")
            print("[Sync] ❌ 실패 localizedDescription - \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Todo

    private func syncTodoCreate(payload: Data, planner: Planner) async throws -> SyncResult {
        let body = decodePayload(payload)
        let path = "/api/notion/todo"
        let token = planner.resolvedNotionToken
        print("[Sync] 📤 요청 - path:\(path) body:\(jsonLog(body))")
        print("[Sync] 📤 payload: \(body)")
        let response: CreateResponse = try await APIClient.shared.post(path, body: AnyEncodable(body), token: token)
        return SyncResult(pageId: response.id, lastEditedTime: parseLastEditedTime(response.lastEditedTime))
    }

    private func syncTodoUpdate(entityId: String, payload: Data, planner: Planner) async throws -> SyncResult {
        let body = decodePayload(payload)
        let path = "/api/notion/todo/\(entityId)"
        let token = planner.resolvedNotionToken
        print("[Sync] 📤 요청 - path:\(path) body:\(jsonLog(body))")
        print("[Sync] 📤 payload: \(body)")
        let response: UpdateResponse = try await APIClient.shared.patch(path, body: AnyEncodable(body), token: token)
        return SyncResult(pageId: nil, lastEditedTime: parseLastEditedTime(response.lastEditedTime))
    }

    private func syncTodoDelete(entityId: String, planner: Planner) async throws {
        let path = "/api/notion/todo/\(entityId)"
        let token = planner.resolvedNotionToken
        print("[Sync] 📤 요청 - path:\(path) body:nil")
        try await APIClient.shared.delete(path, token: token)
    }

    // MARK: - DailyReport

    private func syncDailyReport(payload: Data, planner: Planner) async throws {
        guard let dbId = planner.notionReportDBId else { return }
        var body = decodePayload(payload)
        body["dbId"] = dbId
        let m = planner.decodedReportPropsMapping
        if let v = m.date   { body["dateProp"] = v }
        if let v = m.review { body["reviewProp"] = v }
        if let v = m.rating { body["ratingProp"] = v }
        if let v = m.ratingPropType { body["ratingPropType"] = v }
        let path = "/api/notion/daily-report"
        let token = planner.resolvedNotionToken
        print("[Sync] 📤 요청 - path:\(path) body:\(jsonLog(body))")
        let _: EmptyResponse = try await APIClient.shared.post(path, body: AnyEncodable(body), token: token)
    }

    // MARK: - Helpers

    private func decodePayload(_ data: Data) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func jsonLog(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: .sortedKeys),
              let str = String(data: data, encoding: .utf8) else { return "nil" }
        return str
    }

    private func parseLastEditedTime(_ string: String?) -> Date? {
        guard let string else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: string) { return d }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: string)
    }
}

// MARK: - Supporting Types

struct SyncResult {
    let pageId: String?
    let lastEditedTime: Date?
}

private struct EmptyResponse: Decodable {}
private struct CreateResponse: Decodable {
    let id: String
    let lastEditedTime: String?
}

private struct UpdateResponse: Decodable {
    let success: Bool?
    let lastEditedTime: String?
}

private struct AnyEncodable: Encodable {
    private let value: [String: Any]

    init(_ value: [String: Any]) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AnyCodingKey.self)
        for (key, val) in value {
            let codingKey = AnyCodingKey(key)
            switch val {
            case let v as String:  try container.encode(v, forKey: codingKey)
            case let v as Bool:    try container.encode(v, forKey: codingKey)
            case let v as Int:     try container.encode(v, forKey: codingKey)
            case let v as Double:  try container.encode(v, forKey: codingKey)
            default: break
            }
        }
    }
}

private struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }

    init(_ string: String) { self.stringValue = string }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}
