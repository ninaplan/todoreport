import Foundation
import SwiftData

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
    private var context: ModelContext { PersistenceController.shared.context }

    func fetchReport(for date: Date) async -> DailyReport? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else { return nil }
        do {
            let descriptor = FetchDescriptor<DailyReportItem>(
                predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay }
            )
            return try context.fetch(descriptor).first?.toReport()
        } catch {
            return nil
        }
    }

    func saveReport(_ report: DailyReport) async throws {
        let startOfDay = Calendar.current.startOfDay(for: report.date)
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else { return }
        let descriptor = FetchDescriptor<DailyReportItem>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: report)
        } else {
            context.insert(DailyReportItem.from(report))
        }
        try context.save()
        // TODO: SyncManager.shared.enqueue(.saveDailyReport(report))
    }
}
