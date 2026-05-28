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
    var plannerId: String?

    init(
        id: String = UUID().uuidString,
        date: Date = .now,
        review: String = "",
        completionRate: Double = 0,
        dayRating: DayRating? = nil,
        photoURLs: [String] = [],
        notionPageId: String = "",
        plannerId: String? = nil
    ) {
        self.id = id
        self.date = date
        self.review = review
        self.completionRate = completionRate
        self.dayRating = dayRating
        self.photoURLs = photoURLs
        self.notionPageId = notionPageId
        self.plannerId = plannerId
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
        let plannerId = PlannerService.shared.selectedPlanner?.id
        do {
            let descriptor = FetchDescriptor<DailyReportItem>(
                predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay }
            )
            let reports = try context.fetch(descriptor).map { $0.toReport() }
            if let pid = plannerId {
                return reports.first(where: { $0.plannerId == pid }) ?? reports.first
            }
            return reports.first
        } catch {
            return nil
        }
    }

    func saveReport(_ report: DailyReport) async throws {
        var r = report
        if r.plannerId == nil {
            r.plannerId = PlannerService.shared.selectedPlanner?.id
        }
        let startOfDay = Calendar.current.startOfDay(for: r.date)
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else { return }
        let pid = r.plannerId
        let descriptor = FetchDescriptor<DailyReportItem>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay }
        )
        let existing = try context.fetch(descriptor)
        if let item = existing.first(where: { $0.plannerId == pid }) {
            item.update(from: r)
        } else {
            context.insert(DailyReportItem.from(r))
        }
        try context.save()
    }
}
