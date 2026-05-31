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
            let items = try context.fetch(descriptor)
            print("[DailyReport] 📚 fetch 전체 결과 - \(items.count)개")
            items.forEach { item in
                print("[DailyReport]   - id:\(item.id) plannerId:\(item.plannerId ?? "nil") notionPageId:\(item.notionPageId) review:\(item.review)")
            }

            // 같은 date + plannerId 항목이 여러 개면 notionPageId 없는 항목 삭제
            let pid = plannerId
            let candidates = items.filter { $0.plannerId == pid }
            if candidates.count > 1 {
                let withPageId = candidates.filter { !$0.notionPageId.isEmpty }
                if !withPageId.isEmpty {
                    let toDelete = candidates.filter { $0.notionPageId.isEmpty }
                    toDelete.forEach { context.delete($0) }
                    try? context.save()
                    print("[DailyReport] 🗑️ 중복 항목 \(toDelete.count)개 삭제")
                }
            }

            let filtered = items.filter { $0.plannerId == pid }
            // notionPageId 있는 항목 우선
            let preferred = filtered.first(where: { !$0.notionPageId.isEmpty }) ?? filtered.first
            if let pid {
                print("[DailyReport] 📌 plannerId 필터 - pid:\(pid) result:\(preferred?.review ?? "nil")")
            } else {
                let fallback = items.first(where: { !$0.notionPageId.isEmpty }) ?? items.first
                print("[DailyReport] 📌 plannerId 없음 - result:\(fallback?.review ?? "nil")")
                return fallback?.toReport()
            }
            return preferred?.toReport()
        } catch {
            print("[DailyReport] ❌ fetch 실패 - \(error)")
            return nil
        }
    }

    func syncReportFromNotion(for date: Date) async {
        let planner = PlannerService.shared.selectedPlanner
        guard planner?.isNotionConnected == true,
              let dbId = planner?.notionReportDBId else { return }
        let pid = planner?.id
        let mapping = planner?.decodedReportPropsMapping ?? ReportPropsMapping()
        let token = planner?.resolvedNotionToken

        let dateStr = seoulDateString(from: date)
        var params: [String: String] = ["date": dateStr, "dbId": dbId]
        if let v = mapping.date   { params["dateProp"] = v }
        if let v = mapping.review { params["reviewProp"] = v }
        if let v = mapping.rating { params["ratingProp"] = v }

        do {
            let response: NotionReportResponse? = try await APIClient.shared.get(
                "/api/notion/daily-report", params: params, token: token
            )
            print("[DailyReport] 🔄 Notion fetch - \(dateStr)")
            print("[DailyReport] 🔄 fetch 응답 - notionPageId:\(response?.notionPageId ?? "nil") review:\(response?.review ?? "nil")")
            guard let r = response else { return }
            upsertFromNotion(r, for: date, plannerId: pid)
        } catch {
            print("[DailyReport] ⚠️ Notion sync 실패 - \(error.localizedDescription)")
        }
    }

    private func upsertFromNotion(_ r: NotionReportResponse, for date: Date, plannerId: String?) {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let pageId = r.notionPageId

        print("[DailyReport] 🔄 upsert - notionPageId:\(pageId) review:\(r.review ?? "nil")")

        // 1순위: notionPageId로 매칭
        let byPageId = FetchDescriptor<DailyReportItem>(
            predicate: #Predicate { $0.notionPageId == pageId }
        )
        if let existing = try? context.fetch(byPageId).first {
            existing.review = r.review ?? ""
            existing.dayRatingRaw = r.rating
            existing.notionPageId = r.notionPageId
            print("[DailyReport] 🔄 upsert - notionPageId 일치 항목 업데이트")
        } else {
            // 2순위: 같은 date + plannerId 이면서 notionPageId가 빈 항목
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)
            let allByDate = FetchDescriptor<DailyReportItem>(
                predicate: #Predicate { $0.notionPageId == "" }
            )
            let pending = (try? context.fetch(allByDate))?.filter { item in
                guard let end = endOfDay else { return false }
                return item.date >= startOfDay && item.date < end && item.plannerId == plannerId
            }
            if let pendingItem = pending?.first {
                pendingItem.review = r.review ?? ""
                pendingItem.dayRatingRaw = r.rating
                pendingItem.notionPageId = r.notionPageId
                print("[DailyReport] 🔄 upsert - 빈 notionPageId 항목에 연결")
            } else {
                let report = DailyReport(
                    date: startOfDay,
                    review: r.review ?? "",
                    completionRate: r.completionRate,
                    notionPageId: r.notionPageId,
                    plannerId: plannerId
                )
                context.insert(DailyReportItem.from(report))
                print("[DailyReport] 🔄 upsert - 신규 insert")
            }
        }
        do {
            try context.save()
            let savedItem = try? context.fetch(FetchDescriptor<DailyReportItem>(
                predicate: #Predicate { $0.notionPageId == pageId }
            )).first
            print("[DailyReport] 💾 저장 확인 - review:\(savedItem?.review ?? "nil")")
        } catch {
            print("[DailyReport] ❌ context.save() 실패 - \(error)")
        }
    }

    private func seoulDateString(from date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "Asia/Seoul")
        return fmt.string(from: date)
    }

    func saveReport(_ report: DailyReport) async throws {
        print("[DailyReport] 💾 saveReport 호출")
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

        let captured = r
        Task { await syncSaveToNotion(captured) }
    }

    private func syncSaveToNotion(_ report: DailyReport) async {
        print("[DailyReport] 📤 Notion sync 시작")
        let planner = PlannerService.shared.store.first(where: { $0.id == report.plannerId })
            ?? PlannerService.shared.selectedPlanner
        guard planner?.isNotionConnected == true,
              let dbId = planner?.notionReportDBId else {
            print("[DailyReport] ⚠️ reportDBId 없음 - 스킵")
            return
        }
        let mapping = planner?.decodedReportPropsMapping ?? ReportPropsMapping()
        let token = planner?.resolvedNotionToken

        var body: [String: Any] = [
            "dbId": dbId,
            "date": seoulDateString(from: report.date),
        ]
        body["review"] = report.review
        if let v = mapping.date   { body["dateProp"] = v }
        if let v = mapping.review { body["reviewProp"] = v }
        if let v = mapping.rating { body["ratingProp"] = v }
        if let rating = report.dayRating { body["rating"] = rating.rawValue }

        print("[DailyReport] 📤 body: \(body)")
        do {
            let response: NotionSaveResponse = try await APIClient.shared.post(
                "/api/notion/daily-report", body: AnyEncodableDict(body), token: token
            )
            guard !report.notionPageId.isEmpty else { return }
            let pageId = report.notionPageId
            let descriptor = FetchDescriptor<DailyReportItem>(
                predicate: #Predicate { $0.notionPageId == pageId }
            )
            print("[DailyReport] ✅ Notion 저장 성공")
            if let item = try? context.fetch(descriptor).first {
                item.notionPageId = response.id
                try? context.save()
            }
        } catch {
            print("[DailyReport] ❌ Notion 저장 실패 - \(error)")
        }
    }
}

// MARK: - Notion Response

private struct NotionReportResponse: Decodable {
    let id: String
    let date: String
    let review: String?
    let rating: String?
    let completionRate: Double
    let notionPageId: String
}

private struct NotionSaveResponse: Decodable {
    let id: String
}

private struct AnyEncodableDict: Encodable {
    private let value: [String: Any]
    init(_ value: [String: Any]) { self.value = value }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: RawKey.self)
        for (key, val) in value {
            let k = RawKey(key)
            switch val {
            case let v as String:  try container.encode(v, forKey: k)
            case let v as Bool:    try container.encode(v, forKey: k)
            case let v as Int:     try container.encode(v, forKey: k)
            case let v as Double:  try container.encode(v, forKey: k)
            default: break
            }
        }
    }

    private struct RawKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(_ s: String) { stringValue = s }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }
}
