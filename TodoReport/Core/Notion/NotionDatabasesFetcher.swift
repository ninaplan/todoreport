import Foundation

/// 노션 DB 목록 조회 — 온보딩·플래너 추가·마이그레이션·설정 공통.
enum NotionDatabasesFetcher {
    private static let backendBase = "https://todoreport-backend.vercel.app"
    private static let emptyRetryNanoseconds: [UInt64] = [
        2_000_000_000,
        3_000_000_000,
        5_000_000_000,
    ]

    enum FetchOutcome {
        case success([NotionDatabase])
        case failure(String)
    }

    static func fetch(
        token: String,
        mergeWith existing: [NotionDatabase] = [],
        retryIfEmpty: Bool = true
    ) async -> FetchOutcome {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure("노션 인증 정보가 없어요. 다시 로그인해주세요.")
        }

        var latest = await fetchOnce(token: trimmed)
        if case .success(let list) = latest, list.isEmpty, retryIfEmpty {
            for delay in emptyRetryNanoseconds {
                try? await Task.sleep(nanoseconds: delay)
                if Task.isCancelled { return latest }
                latest = await fetchOnce(token: trimmed)
                if case .success(let list) = latest, !list.isEmpty { break }
            }
        }

        switch latest {
        case .success(let fetched):
            return .success(merged(existing: existing, fetched: fetched))
        case .failure(let message):
            return .failure(message)
        }
    }

    private static func fetchOnce(token: String) async -> FetchOutcome {
        guard let url = URL(string: "\(backendBase)/api/notion/databases") else {
            return .failure("DB 목록을 불러오지 못했어요")
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure("DB 목록을 불러오지 못했어요")
            }
            guard (200...299).contains(http.statusCode) else {
                return .failure(parseErrorMessage(from: data) ?? "DB 목록을 불러오지 못했어요")
            }
            let decoded = try JSONDecoder().decode(DatabasesResponse.self, from: data)
            let databases = decoded.databases.map {
                NotionDatabase(id: $0.id, title: $0.title, icon: $0.icon?.emoji)
            }
            return .success(databases)
        } catch {
            return .failure("DB 목록을 불러오지 못했어요")
        }
    }

    private static func merged(existing: [NotionDatabase], fetched: [NotionDatabase]) -> [NotionDatabase] {
        var byId = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for db in fetched {
            byId[db.id] = db
        }
        return byId.values.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private static func parseErrorMessage(from data: Data) -> String? {
        struct ErrorBody: Decodable { let error: String? }
        guard let body = try? JSONDecoder().decode(ErrorBody.self, from: data),
              let raw = body.error else { return nil }
        if let inner = raw.data(using: .utf8),
           let notion = try? JSONDecoder().decode(NotionAPIError.self, from: inner) {
            return notion.message
        }
        return raw
    }

    private struct DatabasesResponse: Decodable {
        let databases: [DBItem]
        struct DBItem: Decodable {
            let id: String
            let title: String
            let icon: IconItem?
            struct IconItem: Decodable {
                let type: String
                let emoji: String?
            }
        }
    }

    private struct NotionAPIError: Decodable {
        let message: String
    }
}
