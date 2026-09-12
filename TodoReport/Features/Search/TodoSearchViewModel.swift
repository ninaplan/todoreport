import Foundation

@Observable
final class TodoSearchViewModel {
    var query: String = "" {
        didSet { scheduleSearch() }
    }
    private(set) var results: [Todo] = []

    private let service = TodoSearchService.shared
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func openResult(_ todo: Todo) {
        if let plannerId = todo.plannerId,
           plannerId != PlannerService.shared.selectedPlannerId,
           let planner = PlannerService.shared.store.first(where: { $0.id == plannerId }) {
            PlannerService.shared.selectPlanner(planner)
        }

        if let date = todo.date {
            MainTabCoordinator.shared.openTodo(on: date, highlightTodoId: todo.id)
        } else {
            MainTabCoordinator.shared.openInbox(highlightTodoId: todo.id)
        }
    }

    func plannerName(for todo: Todo) -> String {
        guard let plannerId = todo.plannerId,
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
