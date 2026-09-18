import Foundation

@Observable
final class TodoSearchViewModel {
    var query: String = "" {
        didSet { scheduleSearch() }
    }
    private(set) var results: [SearchResultItem] = []

    private let service = TodoSearchService.shared
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func openResult(_ item: SearchResultItem) {
        selectPlannerIfNeeded(item.plannerId)

        switch item {
        case .todo(let todo):
            if let date = todo.date {
                MainTabCoordinator.shared.openTodo(on: date, highlightTodoId: todo.id)
            } else {
                MainTabCoordinator.shared.openInbox(highlightTodoId: todo.id)
            }
        case .review(_, let date, _, _):
            MainTabCoordinator.shared.openTodo(on: date, expandDailyReport: true)
        }
    }

    func plannerName(for item: SearchResultItem) -> String {
        plannerName(forPlannerId: item.plannerId)
    }

    private func selectPlannerIfNeeded(_ plannerId: String?) {
        guard let plannerId,
              plannerId != PlannerService.shared.selectedPlannerId,
              let planner = PlannerService.shared.store.first(where: { $0.id == plannerId }) else {
            return
        }
        PlannerService.shared.selectPlanner(planner)
    }

    private func plannerName(forPlannerId plannerId: String?) -> String {
        guard let plannerId,
              let name = PlannerService.shared.store.first(where: { $0.id == plannerId })?.name else {
            return String(localized: "내 플래너")
        }
        return name
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let needle = trimmedQuery
        guard !needle.isEmpty else {
            results = []
            return
        }
        searchTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            results = await service.search(query: needle)
        }
    }
}
