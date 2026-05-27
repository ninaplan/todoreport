import Foundation

// MARK: - Model

struct DailyReport: Identifiable, Codable {
    let id: String
    let date: Date
    var review: String
    var completionRate: Double
    var dayRating: DayRating?
    var photoURLs: [String]
    var notionPageId: String

    init(
        id: String = UUID().uuidString,
        date: Date = .now,
        review: String = "",
        completionRate: Double = 0,
        dayRating: DayRating? = nil,
        photoURLs: [String] = [],
        notionPageId: String = ""
    ) {
        self.id = id
        self.date = date
        self.review = review
        self.completionRate = completionRate
        self.dayRating = dayRating
        self.photoURLs = photoURLs
        self.notionPageId = notionPageId
    }
}

enum DayRating: String, CaseIterable, Codable {
    case one   = "⭐"
    case two   = "⭐⭐"
    case three = "⭐⭐⭐"
    case four  = "⭐⭐⭐⭐"
    case five  = "⭐⭐⭐⭐⭐"
}

// MARK: - Service

final class DailyReportService {
    // 인메모리 저장소 — Notion 연동 전 더미 구현
    private var store: [String: DailyReport] = [:]

    func fetchReport(for date: Date) async -> DailyReport? {
        // TODO: SwiftData 캐싱 → APIClient → 백엔드 순으로 교체
        return store[key(for: date)]
    }

    func saveReport(_ report: DailyReport) async throws {
        // Offline-First:
        // 1. SwiftData 즉시 저장 (TODO)
        // 2. SyncManager.shared.enqueue(.updateDailyReport(report))
        store[key(for: report.date)] = report
    }

    private func key(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
