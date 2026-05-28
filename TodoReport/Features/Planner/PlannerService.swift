import Foundation
import SwiftData
import Observation

// MARK: - Planner 모델

struct Planner: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var colorHex: String
    var isNotionConnected: Bool
    var notionTodoDBId: String?
    var notionReportDBId: String?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        colorHex: String = "#FD6845",
        isNotionConnected: Bool = false,
        notionTodoDBId: String? = nil,
        notionReportDBId: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.isNotionConnected = isNotionConnected
        self.notionTodoDBId = notionTodoDBId
        self.notionReportDBId = notionReportDBId
        self.createdAt = createdAt
    }
}

// MARK: - PlannerService

@Observable
final class PlannerService {
    static let shared = PlannerService()

    private init() {
        setup()
    }

    private(set) var store: [Planner] = []
    private(set) var selectedPlannerId: String = ""

    var selectedPlanner: Planner? {
        store.first(where: { $0.id == selectedPlannerId }) ?? store.first
    }

    private var context: ModelContext { PersistenceController.shared.context }

    // MARK: - Setup (앱 최초 실행 시 기본 플래너 생성 + 기존 데이터 backfill)

    private func setup() {
        refreshStore()

        if store.isEmpty {
            let item = PlannerItem.from(Planner(name: "내 플래너"))
            context.insert(item)
            try? context.save()
            refreshStore()
        }

        selectedPlannerId = store.first?.id ?? ""
        backfillPlannerId(selectedPlannerId)
    }

    private func refreshStore() {
        let descriptor = FetchDescriptor<PlannerItem>(sortBy: [SortDescriptor(\.createdAt)])
        store = (try? context.fetch(descriptor))?.map { $0.toPlanner() } ?? []
    }

    // 기존 데이터(plannerId가 nil 또는 빈 문자열)를 기본 플래너 ID로 설정
    private func backfillPlannerId(_ defaultId: String) {
        guard !defaultId.isEmpty else { return }
        var changed = false

        if let items = try? context.fetch(FetchDescriptor<TodoItem>()) {
            for item in items where item.plannerId == nil || item.plannerId == "" {
                item.plannerId = defaultId
                changed = true
            }
        }
        if let items = try? context.fetch(FetchDescriptor<DailyReportItem>()) {
            for item in items where item.plannerId == nil || item.plannerId == "" {
                item.plannerId = defaultId
                changed = true
            }
        }
        if let items = try? context.fetch(FetchDescriptor<CategoryItem>()) {
            for item in items where item.plannerId == nil || item.plannerId == "" {
                item.plannerId = defaultId
                changed = true
            }
        }

        if changed { try? context.save() }
    }

    // MARK: - CRUD

    func selectPlanner(_ planner: Planner) {
        selectedPlannerId = planner.id
    }

    func savePlanner(_ planner: Planner) async throws {
        let id = planner.id
        let descriptor = FetchDescriptor<PlannerItem>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: planner)
        } else {
            context.insert(PlannerItem.from(planner))
        }
        try context.save()
        refreshStore()
    }

    func deletePlanner(_ planner: Planner) async throws {
        guard store.count > 1 else { return }
        let id = planner.id
        let descriptor = FetchDescriptor<PlannerItem>(predicate: #Predicate { $0.id == id })
        guard let item = try context.fetch(descriptor).first else { return }
        context.delete(item)
        try context.save()
        refreshStore()
        if selectedPlannerId == planner.id {
            selectedPlannerId = store.first?.id ?? ""
        }
    }
}
