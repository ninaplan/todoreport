import Foundation

// Notion API는 이 클래스를 통해서만 간접 호출 — iOS에서 직접 호출 금지
@MainActor
final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let baseURL: String

    private init() {
        session = URLSession.shared
        baseURL = "https://todoreport-backend.vercel.app"
    }

    func get<T: Decodable>(_ path: String, params: [String: String] = [:], token: String? = nil) async throws -> T {
        let request = try buildRequest(path: path, method: "GET", params: params, token: token)
        return try await perform(request)
    }

    func post<T: Decodable>(_ path: String, body: Encodable, token: String? = nil) async throws -> T {
        let request = try buildRequest(path: path, method: "POST", body: body, token: token)
        return try await perform(request)
    }

    func patch<T: Decodable>(_ path: String, body: Encodable, token: String? = nil) async throws -> T {
        let request = try buildRequest(path: path, method: "PATCH", body: body, token: token)
        return try await perform(request)
    }

    func delete(_ path: String, token: String? = nil) async throws {
        let request = try buildRequest(path: path, method: "DELETE", token: token)
        let (_, response) = try await session.data(for: request)
        try validate(response)
    }

    func revokeNotionToken(_ token: String) async throws {
        struct RevokeResponse: Decodable {
            let ok: Bool?
        }
        let _: RevokeResponse = try await post("/api/auth/notion/revoke", body: EmptyRequestBody(), token: token)
    }
}

private struct EmptyRequestBody: Encodable {}

// MARK: - Private

private extension APIClient {
    func buildRequest(
        path: String,
        method: String,
        params: [String: String] = [:],
        body: Encodable? = nil,
        token: String? = nil
    ) throws -> URLRequest {
        guard var components = URLComponents(string: baseURL + path) else {
            throw APIError.invalidURL
        }
        if !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        let resolvedToken = token
            ?? PlannerService.shared.selectedPlanner?.resolvedNotionToken
            ?? NotionAuthManager.shared.accessToken
            ?? ""
        request.setValue("Bearer \(resolvedToken)", forHTTPHeaderField: "Authorization")

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        try validate(response)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            AppLogger.shared.error("APIClient", "디코딩 실패 - \(error.localizedDescription)")
            throw APIError.decodingFailed(error)
        }
    }

    func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            AppLogger.shared.error("APIClient", "HTTP 오류 - statusCode:\(http.statusCode) url:\(http.url?.path ?? "")")
            throw APIError.httpError(statusCode: http.statusCode)
        }
    }
}

// MARK: - Error

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:              return "잘못된 URL입니다."
        case .invalidResponse:         return "응답을 처리할 수 없습니다."
        case .httpError(let code):     return "서버 오류 (\(code))"
        case .decodingFailed(let err): return "데이터 파싱 실패: \(err.localizedDescription)"
        }
    }
}
