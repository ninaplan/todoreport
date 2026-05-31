import Foundation

@MainActor
enum RepositoryFactory {
    static func make() -> any DataRepository {
        PlannerService.shared.selectedPlanner?.isNotionConnected == true
            ? NotionRepository()
            : LocalRepository()
    }
}
